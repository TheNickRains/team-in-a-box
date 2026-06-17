#!/usr/bin/env bash
# setup.sh — team-in-a-box scaffolder
#
# Turns a freshly-cloned framework into a configured project, in place.
# POSIX-compatible bash (BSD macOS + GNU Linux).
#
# Usage:
#   ./setup.sh                   # interactive
#   ./setup.sh --yes             # non-interactive (use env overrides or defaults)
#   ./setup.sh --defaults        # alias for --yes
#   ./setup.sh --force           # re-init an already-complete project
#
# Per-token env overrides (non-interactive):
#   TIAB_PROJECT_NAME, TIAB_HUMAN_NAME, TIAB_PROJECT_DESCRIPTION,
#   TIAB_STACK_DESCRIPTION, TIAB_PROTECTED_CODE_PATHS, TIAB_DEPLOY_INSTRUCTIONS,
#   TIAB_DEPLOY_DOMAIN, TIAB_SEATS

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
INIT_STATE_FILE=".claude/.init-state"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ALL_SEATS="architect scientist strategist senior-engineer ux fullstack designer naieve-copywriter technical-copywriter"
SYSTEM_SEATS="general recorder scrum-master"   # always kept

# ── Flags ────────────────────────────────────────────────────────────────────
NON_INTERACTIVE=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --yes|--defaults) NON_INTERACTIVE=1 ;;
    --force)          FORCE=1 ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────

_print() { printf '%s\n' "$*"; }
_info()  { printf '  %s\n' "$*"; }
_ok()    { printf '  [ok] %s\n' "$*"; }
_warn()  { printf '  [warn] %s\n' "$*" >&2; }
_fail()  { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

_step() {
  local step="$1"; shift
  printf '\n==> Step %s: %s\n' "$step" "$*"
  _state_set "step" "$step"
}

# ── .init-state read/write ────────────────────────────────────────────────────

_state_read() {
  local field="$1" _val=""
  if [ -f "$INIT_STATE_FILE" ]; then
    _val="$(grep "^${field}=" "$INIT_STATE_FILE" 2>/dev/null | head -1 | sed 's/^[^=]*=//' || true)"
  fi
  printf '%s' "$_val"
}

_state_set() {
  local field="$1" value="$2"
  mkdir -p "$(dirname "$INIT_STATE_FILE")"
  if [ -f "$INIT_STATE_FILE" ] && grep -q "^${field}=" "$INIT_STATE_FILE" 2>/dev/null; then
    local tmp esc_val
    tmp="$(mktemp)"
    esc_val="$(_sed_escape_rhs "$value")"
    sed "s|^${field}=.*|${field}=${esc_val}|" "$INIT_STATE_FILE" > "$tmp" && mv "$tmp" "$INIT_STATE_FILE"
  else
    printf '%s=%s\n' "$field" "$value" >> "$INIT_STATE_FILE"
  fi
}

# ── Portable in-place sed ─────────────────────────────────────────────────────
# BSD (macOS) sed requires -i '' ; GNU sed accepts -i '' or -i
# We use a tmp-file pattern to avoid both.

_sed_inplace() {
  local pattern="$1" file="$2"
  local tmp
  tmp="$(mktemp)"
  sed "$pattern" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Escape a replacement string for sed RHS (& and \ and / are special).
_sed_escape_rhs() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/&/\\&/g; s|/|\\/|g'
}

# ── Token substitution in a single file ──────────────────────────────────────

_substitute_file() {
  local file="$1"
  [ -f "$file" ] || return 0

  # Build sed script: one s command per token.
  # We process the file once with a single sed invocation.
  local sed_script=""
  for token_var in \
    "PROJECT_NAME:$V_PROJECT_NAME" \
    "HUMAN_NAME:$V_HUMAN_NAME" \
    "PROJECT_DESCRIPTION:$V_PROJECT_DESCRIPTION" \
    "STACK_DESCRIPTION:$V_STACK_DESCRIPTION" \
    "DEPLOY_INSTRUCTIONS:$V_DEPLOY_INSTRUCTIONS" \
    "DEPLOY_DOMAIN:$V_DEPLOY_DOMAIN" \
    "PROTECTED_CODE_PATHS:$V_PROTECTED_CODE_PATHS" \
    "KB_PRODUCT_THESIS_SLUG:$V_KB_PRODUCT_THESIS_SLUG" \
    "KB_SCHEMA_SLUG:$V_KB_SCHEMA_SLUG" \
    "KB_STAGES_SLUG:$V_KB_STAGES_SLUG" \
    "KB_SPRINT_OVERVIEW_SLUG:$V_KB_SPRINT_OVERVIEW_SLUG" \
    "KB_HUMAN_TODO_SLUG:$V_KB_HUMAN_TODO_SLUG" \
    "KB_CHARTER_EVAL_SLUG:$V_KB_CHARTER_EVAL_SLUG" \
    "DOMAIN_DESCRIPTION:$V_DOMAIN_DESCRIPTION" \
    "ALGORITHM_CODE_PATHS:$V_ALGORITHM_CODE_PATHS" \
    "INFRA_EPIC_NAME:$V_INFRA_EPIC_NAME" \
    "LANDING_EPIC_NAME:$V_LANDING_EPIC_NAME" \
    "PRIMARY_EPIC_PAIR:$V_PRIMARY_EPIC_PAIR" \
    "THEME_TOKEN_NAMESPACE:$V_THEME_TOKEN_NAMESPACE" \
    "DESIGN_REFERENCE_PATH:$V_DESIGN_REFERENCE_PATH" \
    "FRAMEWORK_DOCS_PATH:$V_FRAMEWORK_DOCS_PATH" \
    "ENV_VAR_LIST:$V_ENV_VAR_LIST" \
  ; do
    local tok="${token_var%%:*}"
    local val="${token_var#*:}"
    local esc_val
    esc_val="$(_sed_escape_rhs "$val")"
    sed_script="${sed_script}s/{{${tok}}}/${esc_val}/g;"
  done

  local tmp
  tmp="$(mktemp)"
  sed "$sed_script" "$file" > "$tmp" && mv "$tmp" "$file"
}

# ── Prompt helper ─────────────────────────────────────────────────────────────

_prompt() {
  local label="$1" default="$2" env_override="$3" required="${4:-0}"
  local result=""

  # Env override wins
  if [ -n "${!env_override:-}" ]; then
    printf '%s' "${!env_override}"
    return 0
  fi

  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    if [ "$required" -eq 1 ] && [ -z "$default" ]; then
      printf '%s' "<!-- TODO: ${label} -->"
      return 0
    fi
    printf '%s' "$default"
    return 0
  fi

  while true; do
    if [ -n "$default" ]; then
      printf '  %s [%s]: ' "$label" "$default" >&2
    else
      printf '  %s (required): ' "$label" >&2
    fi
    IFS= read -r result
    result="${result:-$default}"
    if [ "$required" -eq 1 ] && [ -z "$result" ]; then
      printf '  (this field is required — please enter a value)\n' >&2
      continue
    fi
    break
  done
  printf '%s' "$result"
}

# ── STEP 1: Preflight ─────────────────────────────────────────────────────────

_step 1 "Preflight"

# Git init if needed
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  _info "Not a git repo — running git init"
  git init -q
fi

# Detect jq (optional — just note)
if command -v jq >/dev/null 2>&1; then
  _ok "jq found (used by chair-guard for payload parsing)"
else
  _warn "jq not found — chair-guard will fall back to marker-file detection (fine for most uses)"
fi

# Ensure .kb dirs
mkdir -p .kb/scratch .kb/tasks .kb/claims .kb/docs
touch .kb/events.log
_ok ".kb layout ensured"

# ── STEP 2: Re-init guard ─────────────────────────────────────────────────────

_step 2 "Re-init guard"

EXISTING_STATUS="$(_state_read status)"

if [ "$EXISTING_STATUS" = "complete" ]; then
  if [ "$FORCE" -eq 0 ]; then
    _print ""
    _print "This project is already initialized (status=complete)."
    _print "Run with --force to overwrite."
    exit 0
  else
    _print ""
    _print "Re-initializing with --force. The following will be overwritten:"
    _info "CLAUDE.md, AGENTS.md, COORDINATION.md, CHARTER.md, README.md"
    _info ".claude/agents/*.md (tokens re-substituted)"
    _info ".claude/commands/*.md (tokens re-substituted)"
    _info ".kb/docs stub files for resolved slugs"
    _print ""
  fi
elif [ "$EXISTING_STATUS" = "partial" ]; then
  RESUME_STEP="$(_state_read step)"
  _print "Partial initialization detected (last completed step: ${RESUME_STEP:-unknown})."
  _print "Resuming..."
fi

_state_set "status" "partial"

# ── STEP 3: Interview ─────────────────────────────────────────────────────────

_step 3 "Interview"

# Derive defaults
_DEFAULT_PROJECT_NAME="$(basename "$SCRIPT_DIR")"
_DEFAULT_HUMAN_NAME="$(git config user.name 2>/dev/null || echo "Human")"

_print "Answer the prompts below. Press Enter to accept the default shown in [brackets]."
_print ""

V_PROJECT_NAME="$(_prompt "Project name" "$_DEFAULT_PROJECT_NAME" "TIAB_PROJECT_NAME")"
V_HUMAN_NAME="$(_prompt "Your name (the chair)" "$_DEFAULT_HUMAN_NAME" "TIAB_HUMAN_NAME")"
V_PROJECT_DESCRIPTION="$(_prompt "One-sentence product description" "" "TIAB_PROJECT_DESCRIPTION" 1)"
V_STACK_DESCRIPTION="$(_prompt "Stack / language+framework" "Node / TypeScript" "TIAB_STACK_DESCRIPTION")"
V_PROTECTED_CODE_PATHS="$(_prompt "Chair-guard protected paths (colon-separated)" "app:lib:components" "TIAB_PROTECTED_CODE_PATHS")"
V_DEPLOY_INSTRUCTIONS="$(_prompt "Deploy instructions / command" "<!-- TODO: describe your deploy -->" "TIAB_DEPLOY_INSTRUCTIONS")"
V_DEPLOY_DOMAIN="$(_prompt "Self-hosting domain" "example.com" "TIAB_DEPLOY_DOMAIN")"

# Seats
_DEFAULT_SEATS="all"
if [ "$NON_INTERACTIVE" -eq 1 ]; then
  _SEATS_RAW="${TIAB_SEATS:-all}"
else
  printf '  Which seats to activate? [all]  (comma list or "all"): ' >&2
  IFS= read -r _SEATS_RAW
  _SEATS_RAW="${_SEATS_RAW:-all}"
fi

# Resolve seat list
if [ "$_SEATS_RAW" = "all" ] || [ -z "$_SEATS_RAW" ]; then
  ACTIVE_SEATS="$ALL_SEATS"
else
  # Normalize: trim spaces, split on commas
  ACTIVE_SEATS="$(printf '%s' "$_SEATS_RAW" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr '\n' ' ')"
fi

_print ""
_ok "Project name:     $V_PROJECT_NAME"
_ok "Human/chair name: $V_HUMAN_NAME"
_ok "Stack:            $V_STACK_DESCRIPTION"
_ok "Seats:            $ACTIVE_SEATS"
_print ""

# Silent defaults for lower-signal tokens
V_KB_PRODUCT_THESIS_SLUG="context/immutable/product-thesis"
V_KB_SCHEMA_SLUG="context/immutable/schema"
V_KB_STAGES_SLUG="context/extensible/product-stages"
V_KB_SPRINT_OVERVIEW_SLUG="context/extensible/sprint-overview"
V_KB_HUMAN_TODO_SLUG="context/extensible/human-todo"
V_KB_CHARTER_EVAL_SLUG="context/extensible/charter-eval"
V_DOMAIN_DESCRIPTION="algorithm, signal extraction, cohort matching, evaluation"
V_ALGORITHM_CODE_PATHS="lib/compute,scripts/enrich.py"
V_INFRA_EPIC_NAME="epic-infra"
V_LANDING_EPIC_NAME="epic-landing"
V_PRIMARY_EPIC_PAIR="epic-algorithm"
V_THEME_TOKEN_NAMESPACE="--app-*"
V_DESIGN_REFERENCE_PATH="Reference/design-brief/"
V_FRAMEWORK_DOCS_PATH="node_modules/next/dist/docs/"
V_ENV_VAR_LIST="*(see .env.example — fill after cloning)*"

# PROJECT_DESCRIPTION also feeds into README
# (used in templates/README.project.md via the file itself not a token, so we keep it for info)

# ── STEP 4: Non-interactive mode — already handled above via _prompt/env ──────

_step 4 "Non-interactive support verified"
_ok "All prompts support --yes and TIAB_* env overrides"

# ── STEP 5: Substitute tokens ─────────────────────────────────────────────────

_step 5 "Substituting tokens"

# Files to substitute.
# README.md is NOT included here — it is the framework landing README and will be
# overwritten entirely from templates/README.project.md in step 6.
# docs/ is NOT included — those files contain intentional {{...}} user-instruction
# placeholders (e.g. gitkb-adapter.md) that setup.sh must not touch.
SUBSTITUTE_FILES=(
  "CLAUDE.md"
  "AGENTS.md"
  "COORDINATION.md"
)

# Agent charters
for f in .claude/agents/*.md; do
  [ -f "$f" ] && SUBSTITUTE_FILES+=("$f")
done

# Commands
for f in .claude/commands/*.md; do
  [ -f "$f" ] && SUBSTITUTE_FILES+=("$f")
done

# Template source file (substituted in-place before being copied to its final location)
[ -f "CHARTER.template.md" ]           && SUBSTITUTE_FILES+=("CHARTER.template.md")
[ -f "templates/README.project.md" ]   && SUBSTITUTE_FILES+=("templates/README.project.md")

for f in "${SUBSTITUTE_FILES[@]}"; do
  if [ -f "$f" ]; then
    _substitute_file "$f"
    _info "substituted: $f"
  fi
done

# ── STEP 6: Render + place generated files ────────────────────────────────────

_step 6 "Rendering generated files"

# 6a. README.md from template
# Note: templates/README.project.md was already token-substituted in step 5, so
# {{PROJECT_NAME}} is now $V_PROJECT_NAME in the file. We replace the placeholder
# description line using the resolved project name.
if [ -f "templates/README.project.md" ]; then
  cp "templates/README.project.md" "README.md"
  # The template's description line is now "<ProjectName> — add a one-line description..."
  # Replace it with the user's actual product description.
  _esc_name="$(_sed_escape_rhs "$V_PROJECT_NAME")"
  _esc_desc="$(_sed_escape_rhs "$V_PROJECT_DESCRIPTION")"
  _sed_inplace "s|${_esc_name} — add a one-line description of what your project builds\.|${_esc_desc}|" "README.md"
  _ok "README.md rendered from templates/README.project.md"
else
  _warn "templates/README.project.md not found — README.md unchanged"
fi

# 6b. CHARTER.md from template
if [ -f "CHARTER.template.md" ]; then
  _sed_inplace "s/<DATE>/$(date '+%Y-%m-%d')/" "CHARTER.template.md"
  cp "CHARTER.template.md" "CHARTER.md"
  _ok "CHARTER.md rendered from CHARTER.template.md"
  _print "  NOTE: run /charter to seed your operating charter."
else
  _warn "CHARTER.template.md not found — CHARTER.md not created"
fi

# 6c. Prune unselected seats
_print ""
_info "Pruning unselected seats..."

for seat in $ALL_SEATS; do
  # Is this seat in the active list?
  _seat_active=0
  for active in $ACTIVE_SEATS; do
    if [ "$active" = "$seat" ]; then
      _seat_active=1
      break
    fi
  done

  if [ "$_seat_active" -eq 0 ]; then
    # Remove agent charter
    if [ -f ".claude/agents/${seat}.md" ]; then
      rm ".claude/agents/${seat}.md"
      _info "removed agent: .claude/agents/${seat}.md"
    fi
    # Remove roster line from AGENTS.md (line containing "**${seat}**")
    if [ -f "AGENTS.md" ]; then
      local_tmp="$(mktemp)"
      grep -v "^\*\*${seat}\*\*" "AGENTS.md" > "$local_tmp" && mv "$local_tmp" "AGENTS.md"
    fi
    # Remove journal stub from .kb/docs
    local_journal=".kb/docs/context/extensible/journals/${seat}.md"
    if [ -f "$local_journal" ]; then
      rm "$local_journal"
      _info "removed journal stub: $local_journal"
    fi
  fi
done

_ok "Seat pruning complete. Active: $ACTIVE_SEATS + system ($SYSTEM_SEATS)"

# 6d. Wire CHAIR_PROTECTED_PATHS into settings.json
_print ""
_info "Wiring chair-guard protected paths..."

if [ -f ".claude/settings.json" ]; then
  # Write a companion env file that chair-guard.sh can source.
  # chair-guard.sh already reads CHAIR_PROTECTED_PATHS env — this file persists
  # the configured value across sessions without editing the hook script itself.
  {
    printf '# Generated by setup.sh — chair-guard protected path configuration.\n'
    printf '# Sourced by chair-guard.sh at hook invocation time.\n'
    printf '# Edit this file to change protected paths without touching the hook script.\n'
    printf 'CHAIR_PROTECTED_PATHS="%s"\n' "$V_PROTECTED_CODE_PATHS"
  } > ".claude/tools/chair-guard.env"

  # Patch chair-guard.sh to source the env file at startup (idempotent).
  if ! grep -q 'chair-guard.env' ".claude/hooks/chair-guard.sh" 2>/dev/null; then
    # Insert source block immediately after the 'set -e' line using a tmp-file sed.
    # We write the insertion text to a tmp file to avoid quoting/expansion issues.
    _insert_tmp="$(mktemp)"
    printf '%s\n' \
      '' \
      '# Load configured protected paths (written by setup.sh)' \
      '_GUARD_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' \
      '_GUARD_ENV="${_GUARD_ENV_DIR}/../tools/chair-guard.env"' \
      '[ -f "$_GUARD_ENV" ] && . "$_GUARD_ENV"' \
      '' > "$_insert_tmp"

    _hook_tmp="$(mktemp)"
    # Read the hook line by line; after the 'set -e' line inject the source block
    _injected=0
    while IFS= read -r _line || [ -n "$_line" ]; do
      printf '%s\n' "$_line"
      if [ "$_injected" -eq 0 ] && [ "$_line" = "set -e" ]; then
        cat "$_insert_tmp"
        _injected=1
      fi
    done < ".claude/hooks/chair-guard.sh" > "$_hook_tmp"
    mv "$_hook_tmp" ".claude/hooks/chair-guard.sh"
    rm -f "$_insert_tmp"
    chmod +x ".claude/hooks/chair-guard.sh"
    _ok "chair-guard.sh patched to source chair-guard.env"
  fi
  _ok "CHAIR_PROTECTED_PATHS=${V_PROTECTED_CODE_PATHS} written to .claude/tools/chair-guard.env"
else
  _warn ".claude/settings.json not found — skipping chair-guard wiring"
fi

# 6e. Assert zero raw tokens remain in all final project files
_print ""
_info "Asserting no raw {{...}} tokens remain in project files..."
RAW_REMAINING=0
# Check all .md files except docs/ (intentional user-instruction placeholders) and
# templates/ + CHARTER.template.md + TOKENS.md (scaffolding, about to be deleted)
while IFS= read -r -d '' f; do
  # Skip scaffolding and docs
  case "$f" in
    ./docs/*|./templates/*|./TOKENS.md|./CHARTER.template.md) continue ;;
  esac
  if grep -q '{{' "$f" 2>/dev/null; then
    _warn "UNRESOLVED tokens in: $f"
    grep -n '{{' "$f" | head -5 >&2 || true
    RAW_REMAINING=1
  fi
done < <(find . -name '*.md' -not -path './.git/*' -not -path './.kb/*' -print0 2>/dev/null)
if [ "$RAW_REMAINING" -eq 1 ]; then
  _fail "Raw {{ tokens remain after substitution. Aborting."
fi
_ok "Zero raw tokens remaining"

# ── STEP 7: PATH / git-kb symlink ─────────────────────────────────────────────

_step 7 "Ensuring git kb resolves"

KB_SHIM="$SCRIPT_DIR/.claude/tools/git-kb"
LINK_DIR="$HOME/.local/bin"

if [ -f "$KB_SHIM" ]; then
  chmod +x "$KB_SHIM"
  chmod +x "$SCRIPT_DIR/.claude/tools/kb.sh"

  # Check if git-kb is already on PATH via any mechanism
  if command -v git-kb >/dev/null 2>&1; then
    _ok "git-kb already on PATH"
  else
    # Try to symlink into ~/.local/bin
    if [ -d "$LINK_DIR" ] && printf '%s' "$PATH" | grep -q "$LINK_DIR"; then
      if ln -sf "$KB_SHIM" "$LINK_DIR/git-kb" 2>/dev/null; then
        _ok "Symlinked git-kb -> $LINK_DIR/git-kb"
      else
        _warn "Could not symlink — add this to your shell rc:"
        _print "    export PATH=\"$SCRIPT_DIR/.claude/tools:\$PATH\""
      fi
    else
      _print ""
      _print "  Add git kb to PATH by running (or adding to your shell rc):"
      _print "    export PATH=\"$SCRIPT_DIR/.claude/tools:\$PATH\""
    fi
  fi
else
  _warn ".claude/tools/git-kb not found — KB shim missing"
fi

# ── STEP 8: Seed missing KB doc stubs ─────────────────────────────────────────

_step 8 "Seeding KB doc stubs"

# The KB slug defaults need a .kb/docs/<slug>.md file so `git kb show` is never empty.
# Written without associative arrays for bash 3.2 compatibility (macOS default shell).

_seed_kb_stub() {
  local slug="$1" title="$2"
  local doc_path=".kb/docs/${slug}.md"
  if [ ! -f "$doc_path" ]; then
    mkdir -p "$(dirname "$doc_path")"
    printf '# %s\n\n_TODO: fill this in. This stub was created by setup.sh._\n\n_Slug: %s_\n' \
      "$title" "$slug" > "$doc_path"
    _ok "created stub: $doc_path"
  else
    _info "exists (not clobbered): $doc_path"
  fi
}

_seed_kb_stub "$V_KB_PRODUCT_THESIS_SLUG"    "Product Thesis"
_seed_kb_stub "$V_KB_SCHEMA_SLUG"             "Data Model / Schema"
_seed_kb_stub "$V_KB_STAGES_SLUG"             "Product Stages"
_seed_kb_stub "$V_KB_SPRINT_OVERVIEW_SLUG"    "Sprint Overview"
_seed_kb_stub "$V_KB_HUMAN_TODO_SLUG"         "Chair To-Do"
_seed_kb_stub "$V_KB_CHARTER_EVAL_SLUG"       "Charter Eval — Barnum Procedure"

# ── STEP 9: Seed example task ─────────────────────────────────────────────────

_step 9 "Seeding example task"

export PATH="$SCRIPT_DIR/.claude/tools:$PATH"

# Create one example ready task if board is empty
if [ -z "$(ls .kb/tasks/*.md 2>/dev/null)" ]; then
  EXAMPLE_TASK_ID="$("$SCRIPT_DIR/.claude/tools/kb.sh" create task \
    --title "First task: run /charter to seed your operating charter" \
    --status "ready" \
    --assignee "" \
    --tags "onboarding" 2>/dev/null || true)"
  if [ -n "$EXAMPLE_TASK_ID" ]; then
    _ok "Seeded example task: $EXAMPLE_TASK_ID"
  fi
fi

# ── STEP 10: Cleanup scaffolding-only files ────────────────────────────────────

_step 10 "Cleanup scaffolding files"

[ -f "TOKENS.md" ]              && rm "TOKENS.md"              && _ok "removed TOKENS.md"
[ -f "CHARTER.template.md" ]    && rm "CHARTER.template.md"    && _ok "removed CHARTER.template.md"
if [ -d "templates" ]; then
  rm -rf "templates"
  _ok "removed templates/"
fi
# Keep docs/ (gitkb-adapter.md lives there)

# Mark complete
_state_set "status" "complete"
_state_set "step" "complete"
_ok ".claude/.init-state status=complete"

# ── STEP 11: "It worked" moment ───────────────────────────────────────────────

printf '\n'
printf '=======================================================\n'
printf '  %s is ready.\n' "$V_PROJECT_NAME"
printf '=======================================================\n'
printf '\n'
printf 'Board:\n'
"$SCRIPT_DIR/.claude/tools/kb.sh" board || true

printf '\n'
printf 'What next:\n'
printf '  1. run /charter         — seed your operating charter with %s\n' "$V_HUMAN_NAME"
printf '  2. open a persona       — claude --agent architect (or any seat)\n'
printf '  3. git add -A && git commit -m "init: team-in-a-box setup"\n'
printf '\n'
