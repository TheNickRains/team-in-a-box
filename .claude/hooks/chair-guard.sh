#!/bin/bash
# chair-guard: PreToolUse guard that blocks the chair seat from writing product code.
#
# The chair routes and orchestrates; it does not write product code.
#
# Seat detection (same identity resolution as auto-checkpoint.sh):
#   - subagent_type in payload non-empty → doer seat → allow
#   - persona marker file exists → relay-persona seat → allow
#   - both absent → chair seat → apply path guard
#
# Configurable env vars:
#   CHAIR_PROTECTED_PATHS   — colon-separated list of repo-relative path prefixes to block
#                             (default: app:lib:components)
#   CHAIR_PERSONA_MARKER_DIR — directory where .active-persona-<session> files live
#                              (default: .kb/scratch)
#                              Set to empty string to skip the marker check entirely.
#
# Wired via .claude/settings.json (PreToolUse, matcher: Edit|Write).
#
# jq is OPTIONAL. If absent:
#   - persona extraction falls back to marker file only (subagent_type unavailable)
#   - file_path extraction falls back to empty → no path guarding possible → exit 0 (fail safe)
#   The guard NEVER blocks when it cannot parse — fail open, not fail closed.

set -e

payload=$(cat)

# jq-guarded extraction: returns value or empty; never errors
_jq_extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r "${1} // empty" 2>/dev/null || true
  fi
}

# Resolve persona — same priority order as auto-checkpoint.sh
persona=$(_jq_extract '.subagent_type')

marker_dir="${CHAIR_PERSONA_MARKER_DIR:-.kb/scratch}"
if [ -n "$marker_dir" ] && [ -n "$CLAUDE_CODE_SESSION_ID" ]; then
  marker="${marker_dir}/.active-persona-${CLAUDE_CODE_SESSION_ID}"
  if [ -z "$persona" ] && [ -f "$marker" ]; then
    persona=$(tr -d '[:space:]' < "$marker")
  fi
fi

# Doer or relay-persona seat: allow unconditionally
if [ -n "$persona" ]; then
  exit 0
fi

# Chair seat — apply path guard
file_path=$(_jq_extract '.tool_input.file_path')

# No file path in payload — nothing to guard
if [ -z "$file_path" ]; then
  exit 0
fi

# Normalize: if absolute, strip repo root prefix to get repo-relative path
repo_root="$(pwd)"
case "$file_path" in
  /*)
    # Absolute path: check if it's inside the repo, then make relative
    case "$file_path" in
      "${repo_root}"/*)
        rel_path="${file_path#${repo_root}/}"
        ;;
      *)
        # Outside repo root entirely — not this hook's concern
        exit 0
        ;;
    esac
    ;;
  ./*)
    # Strip leading ./
    rel_path="${file_path#./}"
    ;;
  *)
    rel_path="$file_path"
    ;;
esac

# Check if rel_path falls under a protected product code root
BLOCKED=0
IFS=':' read -ra PROTECTED <<< "${CHAIR_PROTECTED_PATHS:-app:lib:components}"
for dir in "${PROTECTED[@]}"; do
  case "$rel_path" in
    ${dir}/*|${dir}) BLOCKED=1; break ;;
  esac
done

if [ "$BLOCKED" -eq 1 ]; then
  echo "chair-guard: blocked Edit/Write to product path '${rel_path}'. The chair routes; it does not write product code. Dispatch the appropriate doer agent for product code paths." >&2
  exit 2
fi

exit 0
