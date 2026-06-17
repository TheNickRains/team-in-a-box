#!/bin/bash
# Soft-commit: snapshots the active persona's scratch file every 10 turns.
# Fires on Stop (end of every assistant turn).
# Wired via .claude/settings.json (Stop hook).
#
# Purpose: protect against logoff failure. If the session dies before /logoff,
# committed snapshots are on disk. Logoff consolidates from snapshots if scratch
# is lost. Nothing beyond the last 10 turns is ever unrecoverable.
#
# Counter tracked in .kb/scratch/.turn-counter-${CLAUDE_CODE_SESSION_ID}
# Snapshot written to .kb/scratch/<persona>-snapshot-<timestamp>.md
# Snapshot committed via git kb commit (silent on failure — soft-commit is
# best-effort, not a hard guarantee).
#
# jq is OPTIONAL — if absent, persona extraction degrades to marker-only.
# Hook exits 0 on any jq absence (no hard failures on clean machines).

set -e

SNAPSHOT_EVERY=10

# Resolve persona (same priority order as auto-checkpoint.sh)
payload=$(cat)

# jq-guarded extraction: returns value or empty; never errors
_jq_extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r "${1} // empty" 2>/dev/null || true
  fi
}

persona=$(_jq_extract '.subagent_type')

marker=".kb/scratch/.active-persona-${CLAUDE_CODE_SESSION_ID}"
if [ -z "$persona" ] && [ -n "$CLAUDE_CODE_SESSION_ID" ] && [ -f "$marker" ]; then
  persona=$(tr -d '[:space:]' < "$marker")
fi

if [ -z "$persona" ]; then
  exit 0
fi

scratch=".kb/scratch/${persona}-session.md"
if [ ! -f "$scratch" ] || [ ! -s "$scratch" ]; then
  exit 0
fi

# Increment turn counter
counter_file=".kb/scratch/.turn-counter-${CLAUDE_CODE_SESSION_ID}"
count=0
if [ -f "$counter_file" ]; then
  count=$(cat "$counter_file" 2>/dev/null || echo 0)
fi
count=$((count + 1))
printf '%s' "$count" > "$counter_file"

# Snapshot every N turns
if [ $((count % SNAPSHOT_EVERY)) -ne 0 ]; then
  exit 0
fi

timestamp=$(date "+%Y%m%dT%H%M")
snapshot=".kb/scratch/${persona}-snapshot-${timestamp}.md"

cp "$scratch" "$snapshot"

# Best-effort commit — silent on failure
git kb commit "$snapshot" \
  -m "scratch: ${persona} auto-snapshot $(date '+%Y-%m-%d') turn ${count}" \
  >/dev/null 2>&1 || true

exit 0