#!/bin/bash
# Checkpoint: appends a manual beat to the active persona's scratch file.
# Fires on PostToolUse, matcher: checkpoint.
# Wired via .claude/settings.json.
#
# Purpose: capture non-file-edit beats — decisions made, hypotheses rejected,
# direction changes, blockers surfaced — that auto-checkpoint.sh misses because
# they don't trigger Edit or Write.
#
# The persona calls the checkpoint tool with a "beat" string. This hook
# reads that string from the tool input and appends it to scratch.
#
# Tool definition lives in .claude/tools/checkpoint.json
#
# jq is OPTIONAL — if absent, persona and beat extraction degrade to no-op (exit 0).

set -e

payload=$(cat)

# jq-guarded extraction: returns value or empty; never errors
_jq_extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r "${1} // empty" 2>/dev/null || true
  fi
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

# Extract beat text from tool input
beat=$(_jq_extract '.tool_input.beat')
if [ -z "$beat" ]; then
  exit 0
fi

# Resolve current task (optional)
task_marker=".kb/scratch/.active-task-${CLAUDE_CODE_SESSION_ID}"
current_task=""
if [ -n "$CLAUDE_CODE_SESSION_ID" ] && [ -f "$task_marker" ]; then
  current_task=$(tr -d '[:space:]' < "$task_marker")
fi

timestamp=$(date "+%Y-%m-%d %H:%M")
mkdir -p .kb/scratch
scratch=".kb/scratch/${persona}-session.md"

if [ -n "$current_task" ]; then
  printf -- '- %s [%s] — NOTE: %s\n' "$timestamp" "$current_task" "$beat" >> "$scratch"
else
  printf -- '- %s — NOTE: %s\n' "$timestamp" "$beat" >> "$scratch"
fi

exit 0