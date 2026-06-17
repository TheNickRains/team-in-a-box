#!/bin/bash
# Auto-save: appends a one-line beat to the active persona's scratch file
# whenever Edit or Write is invoked. Silent no-op if no persona context.
#
# Wired via .claude/settings.json (PostToolUse, matcher: Edit|Write).
#
# Persona identity resolved in priority order:
#   1. subagent_type field in hook payload (real Agent subagent)
#   2. .kb/scratch/.active-persona-${CLAUDE_CODE_SESSION_ID} (written by /init)
#
# Task context resolved from:
#   .kb/scratch/.active-task-${CLAUDE_CODE_SESSION_ID} (written by persona on task switch)
#   If absent, beat is untagged.
#
# jq is OPTIONAL — if absent, persona/tool/target extraction degrades to no-op
# (exit 0) so the hook never hard-fails on a clean machine.

set -e

payload=$(cat)

# jq-guarded extraction helper: outputs value or empty string; never errors.
_jq_extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r "${1} // empty" 2>/dev/null || true
  fi
  # If jq absent: returns empty string, caller handles gracefully.
}

# Resolve persona
persona=$(_jq_extract '.subagent_type')

marker=".kb/scratch/.active-persona-${CLAUDE_CODE_SESSION_ID}"
if [ -z "$persona" ] && [ -n "$CLAUDE_CODE_SESSION_ID" ] && [ -f "$marker" ]; then
  persona=$(tr -d '[:space:]' < "$marker")
fi

if [ -z "$persona" ]; then
  exit 0
fi

# Resolve current task (optional)
task_marker=".kb/scratch/.active-task-${CLAUDE_CODE_SESSION_ID}"
current_task=""
if [ -n "$CLAUDE_CODE_SESSION_ID" ] && [ -f "$task_marker" ]; then
  current_task=$(tr -d '[:space:]' < "$task_marker")
fi

# Extract tool metadata — degrade to "?" / empty if jq absent
tool=$(_jq_extract '.tool_name')
[ -z "$tool" ] && tool="?"
target=$(_jq_extract '.tool_input.file_path')
timestamp=$(date "+%Y-%m-%d %H:%M")

mkdir -p .kb/scratch
scratch=".kb/scratch/${persona}-session.md"

# Write beat — include task tag if present
if [ -n "$target" ]; then
  if [ -n "$current_task" ]; then
    printf -- '- %s [%s] — %s %s\n' "$timestamp" "$current_task" "$tool" "$(basename "$target")" >> "$scratch"
  else
    printf -- '- %s — %s %s\n' "$timestamp" "$tool" "$(basename "$target")" >> "$scratch"
  fi
else
  if [ -n "$current_task" ]; then
    printf -- '- %s [%s] — %s\n' "$timestamp" "$current_task" "$tool" >> "$scratch"
  else
    printf -- '- %s — %s\n' "$timestamp" "$tool" >> "$scratch"
  fi
fi

exit 0
