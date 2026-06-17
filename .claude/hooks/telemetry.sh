#!/bin/bash
# Telemetry: parses session + subagent transcripts on Stop, appends
# structured records to ~/.claude/telemetry.jsonl.
#
# Captures: orchestrator turns + all subagent turns with proper persona attribution.
# Deduplication: tracks logged message IDs per session to handle streaming updates and repeated Stop fires.
#
# jq is REQUIRED for transcript parsing. If jq is absent, this hook exits 0
# silently — telemetry is best-effort and must not block the session.
#
# tail -r is not portable (macOS-only). We use a portable reverse helper:
#   _reverse(): uses `tac` when available, falls back to `tail -r`.

payload=$(cat)

# Hard dependency on jq for transcript parsing — degrade gracefully if absent
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)
transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null || true)

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi

project=$(basename "$(pwd)")
timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
ledger="$HOME/.claude/telemetry.jsonl"
watermark_dir="$HOME/.claude/telemetry-watermarks"
watermark_file="$watermark_dir/${session_id}.txt"

mkdir -p "$(dirname "$ledger")"
mkdir -p "$watermark_dir"

# Initialize watermark file if it doesn't exist
touch "$watermark_file"

# Read existing watermarks (message IDs we've already logged for this session)
logged_msg_ids=$(cat "$watermark_file" 2>/dev/null || true)

# Portable reverse: tac (Linux/GNU) first, then tail -r (macOS BSD), then awk fallback.
_reverse() {
  if command -v tac >/dev/null 2>&1; then
    tac "$@"
  elif tail -r /dev/null >/dev/null 2>&1; then
    tail -r "$@"
  else
    # Pure awk fallback — no external deps beyond awk (POSIX)
    awk '{lines[NR]=$0} END{for(i=NR;i>=1;i--) print lines[i]}' "$@"
  fi
}

# Detect if main orchestrator is running as a persona (claude --agent <name>)
# agentSetting appears on first line of transcript when using --agent flag
main_persona=$(jq -r 'select(.type == "agent-setting") | .agentSetting // empty' "$transcript_path" 2>/dev/null | head -1)
if [ -z "$main_persona" ]; then
  main_persona="orchestrator"
fi

# Function to extract and log NEW assistant turns from a transcript
log_transcript() {
  local file="$1"
  local default_persona="$2"
  local temp_raw="/tmp/telemetry_raw_$$"
  local temp_deduped="/tmp/telemetry_dedup_$$"
  local temp_seen="/tmp/telemetry_seen_$$"

  # Step 1: Extract all assistant turns with message IDs
  jq -c '
    select(.type == "assistant" and .message.usage != null)
    | {
        msg_id: .message.id,
        model: .message.model,
        input_tokens: .message.usage.input_tokens,
        output_tokens: .message.usage.output_tokens,
        cache_creation_tokens: (.message.usage.cache_creation_input_tokens // 0),
        cache_read_tokens: (.message.usage.cache_read_input_tokens // 0),
        tool_calls: ([.message.content[]? | select(.type == "tool_use") | .name] | length),
        turn_timestamp: .timestamp,
        persona: (.attributionAgent // "'"$default_persona"'")
      }
  ' "$file" 2>/dev/null > "$temp_raw"

  # Step 2: Dedupe - reverse, keep first of each msg_id (= last in original), reverse back
  : > "$temp_seen"
  : > "$temp_deduped"
  _reverse "$temp_raw" 2>/dev/null | while IFS= read -r line; do
    msg_id=$(printf '%s' "$line" | jq -r '.msg_id')
    if ! grep -qF "$msg_id" "$temp_seen" 2>/dev/null; then
      echo "$msg_id" >> "$temp_seen"
      echo "$line" >> "$temp_deduped"
    fi
  done

  # Step 3: Process deduped records (reverse to restore chronological order)
  _reverse "$temp_deduped" 2>/dev/null | while IFS= read -r turn; do
    msg_id=$(printf '%s' "$turn" | jq -r '.msg_id')

    # Skip if already logged in a previous Stop fire
    if echo "$logged_msg_ids" | grep -qF "$msg_id"; then
      continue
    fi

    # Append record to ledger
    record=$(printf '%s' "$turn" | jq -c \
      --arg session_id "$session_id" \
      --arg project "$project" \
      --arg logged_at "$timestamp" \
      'del(.msg_id) + {
        session_id: $session_id,
        project: $project,
        logged_at: $logged_at
      }')
    printf '%s\n' "$record" >> "$ledger"

    # Mark this message as logged
    echo "$msg_id" >> "$watermark_file"
  done

  rm -f "$temp_raw" "$temp_deduped" "$temp_seen"
}

# Log main transcript (using detected persona or "orchestrator")
log_transcript "$transcript_path" "$main_persona"

# Log subagent transcripts if they exist
transcript_dir=$(dirname "$transcript_path")
transcript_base=$(basename "$transcript_path" .jsonl)
subagents_dir="$transcript_dir/$transcript_base/subagents"

if [ -d "$subagents_dir" ]; then
  for subagent_file in "$subagents_dir"/agent-*.jsonl; do
    [ -f "$subagent_file" ] && log_transcript "$subagent_file" "subagent"
  done
fi

# Cleanup: remove watermark files older than 7 days (fire-and-forget)
find "$watermark_dir" -type f -name "*.txt" -mtime +7 -delete 2>/dev/null || true

exit 0