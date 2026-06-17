#!/bin/bash
# kb.sh — file-based GitKB shim
#
# Implements the git-kb verb contract against a plain-file store rooted at .kb/.
# No jq required. No MCP server required.
#
# Store layout:
#   .kb/scratch/          — session scratch files + marker files
#   .kb/tasks/            — one file per task (TASK_ID.md with front-matter lines)
#   .kb/claims/           — one file per claimed task (atomic claim records)
#   .kb/docs/             — KB docs addressed by slug (e.g. context/immutable/foo.md)
#   .kb/events.log        — append-only event log
#   .kb/workspaces/main/  — journal workspace (journal.sh writes here)
#
# Usage: git kb <verb> [args...]
#   or:  kb.sh <verb> [args...]

set -euo pipefail

# ── Root resolution ───────────────────────────────────────────────────────────
# Honor KB_ROOT env if set; otherwise derive from git repo root or cwd.
if [ -n "${KB_ROOT:-}" ]; then
  KB_ROOT="$KB_ROOT"
elif git rev-parse --show-toplevel >/dev/null 2>&1; then
  KB_ROOT="$(git rev-parse --show-toplevel)"
else
  KB_ROOT="$(pwd)"
fi

KB_TASKS="$KB_ROOT/.kb/tasks"
KB_CLAIMS="$KB_ROOT/.kb/claims"
KB_DOCS="$KB_ROOT/.kb/docs"
KB_SCRATCH="$KB_ROOT/.kb/scratch"
KB_EVENTS="$KB_ROOT/.kb/events.log"
KB_WORKSPACE="$KB_ROOT/.kb/workspaces/main"

# ── Helpers ───────────────────────────────────────────────────────────────────

_ensure_dirs() {
  mkdir -p "$KB_TASKS" "$KB_CLAIMS" "$KB_DOCS" "$KB_SCRATCH" "$KB_WORKSPACE"
  touch "$KB_EVENTS"
}

# Read a named field from a task file.
# Field format: "field: value" on its own line (case-insensitive key).
_task_field() {
  local file="$1" field="$2"
  grep -i "^${field}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//'
}

# Set a named field in a task file; adds the line if absent.
_task_set_field() {
  local file="$1" field="$2" value="$3"
  if grep -qi "^${field}:" "$file" 2>/dev/null; then
    # Portable in-place replacement (no sed -i on macOS without backup arg dance)
    local tmp
    tmp="$(mktemp)"
    # Replace the matching line; grep -i means we use awk for case-insensitive
    awk -v field="${field}" -v val="${value}" '
      BEGIN { fl = tolower(field) }
      tolower($0) ~ ("^" fl ":") { print field ": " val; next }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
  else
    printf '%s: %s\n' "$field" "$value" >> "$file"
  fi
}

# Generate a short unique task ID (timestamp-based, no external deps).
_new_task_id() {
  printf 'task-%s' "$(date '+%Y%m%d%H%M%S')"
}

# ── Verb: resolve ─────────────────────────────────────────────────────────────
cmd_resolve() {
  local quiet=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --auto|--quiet) quiet=1 ;; esac
    shift
  done

  # Priority 1: KB_TASK env
  if [ -n "${KB_TASK:-}" ]; then
    printf '%s\n' "$KB_TASK"
    return 0
  fi

  # Priority 2: scratch marker for this session
  if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
    local marker="$KB_SCRATCH/.active-task-${CLAUDE_CODE_SESSION_ID}"
    if [ -f "$marker" ]; then
      local t
      t=$(tr -d '[:space:]' < "$marker")
      [ -n "$t" ] && printf '%s\n' "$t" && return 0
    fi
  fi

  # Priority 3: current git branch (strip common prefixes)
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  if [ -n "$branch" ] && [ "$branch" != "HEAD" ] && [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    # Return branch as task id only if a matching task file exists
    if ls "$KB_TASKS/${branch}".md >/dev/null 2>&1; then
      printf '%s\n' "$branch"
      return 0
    fi
  fi

  # Nothing found — empty output, exit 0 (--quiet means never error)
  return 0
}

# ── Verb: ready ───────────────────────────────────────────────────────────────
cmd_ready() {
  local quiet=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --quiet) quiet=1 ;; esac
    shift
  done

  _ensure_dirs
  for f in "$KB_TASKS"/*.md; do
    [ -f "$f" ] || continue
    local status
    status=$(_task_field "$f" "status")
    case "$status" in ready|draft)
      local id
      id=$(basename "$f" .md)
      printf '%s\n' "$id"
      return 0
    esac
  done
  return 0
}

# ── Verb: context ─────────────────────────────────────────────────────────────
cmd_context() {
  local task_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task) shift; task_id="${1:-}" ;;
      *) ;;
    esac
    shift
  done

  _ensure_dirs

  if [ -n "$task_id" ]; then
    local tf="$KB_TASKS/${task_id}.md"
    if [ -f "$tf" ]; then
      printf '=== Task: %s ===\n' "$task_id"
      cat "$tf"
      printf '\n'
    else
      printf '=== Task: %s (no task file found) ===\n' "$task_id"
    fi
  fi

  # Recent journal entries — last 50 lines of each journal file in workspaces
  local journal_dir="$KB_WORKSPACE/context/extensible/journals"
  if [ -d "$journal_dir" ]; then
    for jf in "$journal_dir"/*.md; do
      [ -f "$jf" ] || continue
      local jname
      jname=$(basename "$jf" .md)
      printf '=== Journal: %s (recent) ===\n' "$jname"
      tail -50 "$jf"
      printf '\n'
    done
  fi

  # Referenced docs (look for lines matching "slug: context/...")
  if [ -n "$task_id" ] && [ -f "$KB_TASKS/${task_id}.md" ]; then
    local refs
    refs=$(grep -oE 'context/[a-z/._-]+' "$KB_TASKS/${task_id}.md" 2>/dev/null || true)
    if [ -n "$refs" ]; then
      printf '=== Referenced Docs ===\n'
      while IFS= read -r slug; do
        local df="$KB_DOCS/${slug}.md"
        [ -f "$df" ] && cat "$df" && printf '\n'
      done <<< "$refs"
    fi
  fi

  return 0
}

# ── Verb: assign ─────────────────────────────────────────────────────────────
cmd_assign() {
  local task_id="${1:-}"
  local who="${2:-}"

  if [ -z "$task_id" ] || [ -z "$who" ]; then
    printf 'usage: kb assign <task-id> <who>\n' >&2
    return 1
  fi

  _ensure_dirs

  local claim_file="$KB_CLAIMS/${task_id}"

  # ATOMIC claim via set -o noclobber (fails if file already exists).
  # Redirect stderr in the subshell to suppress bash's "cannot overwrite" message;
  # our own collision message to stderr replaces it.
  if (
    set -o noclobber
    printf '%s\n' "$who" > "$claim_file" 2>/dev/null
  ) 2>/dev/null; then
    # Success — also write active-task marker for session
    if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
      printf '%s' "$task_id" > "$KB_SCRATCH/.active-task-${CLAUDE_CODE_SESSION_ID}"
    fi
    printf 'kb: claimed %s for %s\n' "$task_id" "$who"
    return 0
  else
    local current_owner
    current_owner=$(cat "$claim_file" 2>/dev/null || echo "unknown")
    printf 'kb: collision — task %s already claimed by %s\n' "$task_id" "$current_owner" >&2
    return 1
  fi
}

# ── Verb: unassign ────────────────────────────────────────────────────────────
cmd_unassign() {
  local task_id="${1:-}"
  if [ -z "$task_id" ]; then
    printf 'usage: kb unassign <task-id>\n' >&2
    return 1
  fi
  rm -f "$KB_CLAIMS/${task_id}"
  return 0
}

# ── Verb: commit ─────────────────────────────────────────────────────────────
cmd_commit() {
  local msg="" target="" add_all=0
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m) shift; msg="${1:-}" ;;
      --all) add_all=1 ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  target="${args[0]:-}"

  _ensure_dirs

  local ts
  ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
  printf '[%s] %s — %s\n' "$ts" "${target:-all}" "${msg:-no message}" >> "$KB_EVENTS"

  # Best-effort git commit
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if [ "$add_all" -eq 1 ]; then
      git add -A >/dev/null 2>&1 || true
    elif [ -n "$target" ]; then
      local full_target
      # If target is a KB slug (no leading /), resolve against workspace or docs
      case "$target" in
        /*)  full_target="$target" ;;
        .kb/*) full_target="$KB_ROOT/$target" ;;
        *)
          # Try workspace first, then docs path
          if [ -f "$KB_WORKSPACE/${target}.md" ]; then
            full_target="$KB_WORKSPACE/${target}.md"
          elif [ -f "$KB_DOCS/${target}.md" ]; then
            full_target="$KB_DOCS/${target}.md"
          elif [ -f "$target" ]; then
            full_target="$target"
          else
            full_target="$target"
          fi
        ;;
      esac
      git add "$full_target" >/dev/null 2>&1 || true
    fi

    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -m "${msg:-kb: auto-commit}" >/dev/null 2>&1 || true
    fi
  fi

  return 0
}

# ── Verb: show ────────────────────────────────────────────────────────────────
cmd_show() {
  local slug="${1:-}"
  if [ -z "$slug" ]; then
    return 0
  fi

  _ensure_dirs
  local f="$KB_DOCS/${slug}.md"
  if [ -f "$f" ]; then
    cat "$f"
  fi
  # exit 0 even if missing (spec: empty + exit 0 if missing)
  return 0
}

# ── Verb: list ────────────────────────────────────────────────────────────────
cmd_list() {
  local type_filter="" status_filter="" tags_filter="" path_filter="" no_pager=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)    shift; type_filter="${1:-}" ;;
      --status)  shift; status_filter="${1:-}" ;;
      --tags)    shift; tags_filter="${1:-}" ;;
      --path)    shift; path_filter="${1:-}" ;;
      --no-pager) no_pager=1 ;;
      *) ;;
    esac
    shift
  done

  _ensure_dirs

  # If --path given, list docs under that path prefix
  if [ -n "$path_filter" ]; then
    local dir="$KB_DOCS/${path_filter}"
    printf '%-12s  %-40s  %s\n' "type" "slug" "title"
    printf '%-12s  %-40s  %s\n' "----" "----" "-----"
    if [ -d "$dir" ]; then
      find "$dir" -name "*.md" | while read -r f; do
        local slug="${f#${KB_DOCS}/}"
        slug="${slug%.md}"
        local title
        title=$(grep -m1 "^#" "$f" 2>/dev/null | sed 's/^#* *//' || echo "")
        printf '%-12s  %-40s  %s\n' "doc" "$slug" "$title"
      done
    fi
    # Also look in workspaces
    local wdir="$KB_WORKSPACE/${path_filter}"
    if [ -d "$wdir" ]; then
      find "$wdir" -name "*.md" | while read -r f; do
        local slug="${f#${KB_WORKSPACE}/}"
        slug="${slug%.md}"
        local title
        title=$(grep -m1 "^#" "$f" 2>/dev/null | sed 's/^#* *//' || echo "")
        printf '%-12s  %-40s  %s\n' "doc" "$slug" "$title"
      done
    fi
    return 0
  fi

  # Otherwise list tasks
  printf '%-12s  %-20s  %-12s  %-12s  %s\n' "id" "assignee" "status" "parent" "title"
  printf '%-12s  %-20s  %-12s  %-12s  %s\n' "--" "--------" "------" "------" "-----"
  for f in "$KB_TASKS"/*.md; do
    [ -f "$f" ] || continue
    local id status assignee parent title tags
    id=$(basename "$f" .md)
    status=$(_task_field "$f" "status")
    assignee=$(_task_field "$f" "assignee")
    parent=$(_task_field "$f" "parent")
    title=$(_task_field "$f" "title")
    tags=$(_task_field "$f" "tags")

    # Apply filters
    [ -n "$type_filter" ] && [ "$type_filter" = "task" ] || true
    if [ -n "$status_filter" ]; then
      [ "$status" = "$status_filter" ] || continue
    fi
    if [ -n "$tags_filter" ]; then
      case "$tags" in *"$tags_filter"*) ;; *) continue ;; esac
    fi

    printf '%-12s  %-20s  %-12s  %-12s  %s\n' "$id" "${assignee:--}" "${status:--}" "${parent:--}" "${title:-(no title)}"
  done
  return 0
}

# ── Verb: board ───────────────────────────────────────────────────────────────
cmd_board() {
  local group_by="" tags_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group-by) shift; group_by="${1:-}" ;;
      --tags)     shift; tags_filter="${1:-}" ;;
      *) ;;
    esac
    shift
  done

  _ensure_dirs

  if [ "$group_by" = "assignee" ]; then
    # Collect unique assignees
    local assignees=()
    for f in "$KB_TASKS"/*.md; do
      [ -f "$f" ] || continue
      local a
      a=$(_task_field "$f" "assignee")
      [ -n "$a" ] && assignees+=("$a")
    done

    # Dedupe
    local seen=""
    for a in "${assignees[@]+"${assignees[@]}"}"; do
      case "$seen" in *"|${a}|"*) continue ;; esac
      seen="${seen}|${a}|"
      printf '\n== %s ==\n' "$a"
      for f in "$KB_TASKS"/*.md; do
        [ -f "$f" ] || continue
        local fa
        fa=$(_task_field "$f" "assignee")
        [ "$fa" = "$a" ] || continue
        local id title status
        id=$(basename "$f" .md)
        title=$(_task_field "$f" "title")
        status=$(_task_field "$f" "status")
        printf '  [%s] %s — %s\n' "${status:--}" "$id" "${title:-(no title)}"
      done
    done
  else
    # Group by status
    for bucket in draft ready active blocked done; do
      local printed_header=0
      for f in "$KB_TASKS"/*.md; do
        [ -f "$f" ] || continue
        local status
        status=$(_task_field "$f" "status")
        [ "$status" = "$bucket" ] || continue
        if [ -n "$tags_filter" ]; then
          local tags
          tags=$(_task_field "$f" "tags")
          case "$tags" in *"$tags_filter"*) ;; *) continue ;; esac
        fi
        [ "$printed_header" -eq 0 ] && printf '\n== %s ==\n' "$bucket" && printed_header=1
        local id title assignee
        id=$(basename "$f" .md)
        title=$(_task_field "$f" "title")
        assignee=$(_task_field "$f" "assignee")
        printf '  %s — %s  [%s]\n' "$id" "${title:-(no title)}" "${assignee:--}"
      done
    done
  fi
  return 0
}

# ── Verb: set ─────────────────────────────────────────────────────────────────
cmd_set() {
  local slug="${1:-}"
  shift || true

  if [ -z "$slug" ]; then
    printf 'usage: kb set <slug> --<field> <value>\n' >&2
    return 1
  fi

  local file
  # Check tasks first, then docs
  if [ -f "$KB_TASKS/${slug}.md" ]; then
    file="$KB_TASKS/${slug}.md"
  elif [ -f "$KB_DOCS/${slug}.md" ]; then
    file="$KB_DOCS/${slug}.md"
  else
    printf 'kb set: slug %s not found\n' "$slug" >&2
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --*)
        local field="${1#--}"
        shift
        local value="${1:-}"
        _task_set_field "$file" "$field" "$value"
        ;;
      *) ;;
    esac
    shift || true
  done
  return 0
}

# ── Verb: create ─────────────────────────────────────────────────────────────
cmd_create() {
  local subtype="${1:-}"
  shift || true

  _ensure_dirs

  if [ "$subtype" = "task" ]; then
    local title="" parent="" assignee="" tags="" status="draft"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --title)    shift; title="${1:-}" ;;
        --parent)   shift; parent="${1:-}" ;;
        --assignee) shift; assignee="${1:-}" ;;
        --tags)     shift; tags="${1:-}" ;;
        --status)   shift; status="${1:-}" ;;
        *) ;;
      esac
      shift || true
    done

    local id
    id=$(_new_task_id)
    local f="$KB_TASKS/${id}.md"
    {
      printf 'title: %s\n' "$title"
      printf 'status: %s\n' "$status"
      printf 'assignee: %s\n' "$assignee"
      printf 'parent: %s\n' "$parent"
      printf 'tags: %s\n' "$tags"
      printf '\n## %s\n\n' "$title"
      printf '_Created: %s_\n' "$(date '+%Y-%m-%d')"
    } > "$f"
    printf '%s\n' "$id"

  else
    # create <doc-slug> — write a new doc file
    local slug="$subtype"
    local f="$KB_DOCS/${slug}.md"
    mkdir -p "$(dirname "$f")"
    if [ ! -f "$f" ]; then
      {
        printf '# %s\n\n' "$slug"
        printf '_Created: %s_\n' "$(date '+%Y-%m-%d')"
      } > "$f"
    fi
    printf '%s\n' "$slug"
  fi
  return 0
}

# ── Verb: ai semantic ─────────────────────────────────────────────────────────
cmd_ai() {
  local subcmd="${1:-}"
  shift || true

  if [ "$subcmd" = "semantic" ]; then
    local query="${*:-}"
    grep -rl "$query" "$KB_ROOT/.kb/" 2>/dev/null || true
  fi
  return 0
}

# ── Verb: checkout ────────────────────────────────────────────────────────────
cmd_checkout() {
  local path="${1:-}"
  # shift -q flag if present
  while [[ $# -gt 0 ]]; do
    case "$1" in -q) ;; *) [ -z "$path" ] && path="$1" ;; esac
    shift || true
  done

  if [ -z "$path" ]; then
    return 0
  fi

  _ensure_dirs

  # The "workspace" file for this doc path
  local ws_file="$KB_WORKSPACE/${path}.md"
  local doc_file="$KB_DOCS/${path}.md"

  if [ ! -f "$ws_file" ]; then
    mkdir -p "$(dirname "$ws_file")"
    if [ -f "$doc_file" ]; then
      # Materialize from docs into workspace
      cp "$doc_file" "$ws_file"
    else
      # Create empty placeholder
      printf '# %s\n\n' "$path" > "$ws_file"
    fi
  fi
  return 0
}

# ── Verb: events ─────────────────────────────────────────────────────────────
cmd_events() {
  _ensure_dirs
  cat "$KB_EVENTS" 2>/dev/null || true
  return 0
}

# ── Verb: board (fallthrough) / unknown ──────────────────────────────────────
# Any unrecognized verb exits 0 — no hook or charter must ever hard-fail on
# an unrecognized verb.

# ── Dispatch ─────────────────────────────────────────────────────────────────
VERB="${1:-}"
shift || true

case "$VERB" in
  resolve)       cmd_resolve "$@" ;;
  ready)         cmd_ready "$@" ;;
  context)       cmd_context "$@" ;;
  assign)        cmd_assign "$@" ;;
  unassign)      cmd_unassign "$@" ;;
  commit)        cmd_commit "$@" ;;
  show)          cmd_show "$@" ;;
  list)          cmd_list "$@" ;;
  board)         cmd_board "$@" ;;
  set)           cmd_set "$@" ;;
  create)        cmd_create "$@" ;;
  ai)            cmd_ai "$@" ;;
  checkout)      cmd_checkout "$@" ;;
  events)        cmd_events "$@" ;;
  *)
    # Unknown verb — exit 0, never error (mcp, verify, etc.)
    exit 0
    ;;
esac
