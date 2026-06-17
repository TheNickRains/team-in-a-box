#!/bin/bash
# journal.sh <name> <topic> <body>
# Appends a dated Session entry to an agent's own journal.
#
# Write path: checkout → append to workspace file → commit via kb shim.
# Works against both the file-based KB shim and the real GitKB binary —
# both expose the same verb contract (list, checkout, commit).
#
# Validation: the named journal must exist as a doc under
# context/extensible/journals/<name> (either in .kb/docs/ or .kb/workspaces/).
# On a clean install with no pre-existing journals, any name is accepted
# (the checkout verb creates a placeholder). This keeps the tool usable
# out-of-the-box without requiring pre-seeded journal docs.
set -euo pipefail

NAME="${1:?usage: journal.sh <name> <topic> <body>}"
TOPIC="${2:?missing topic}"
BODY="${3:?missing body}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKSPACE="$REPO_ROOT/.kb/workspaces/main"
DOC_PATH="context/extensible/journals/$NAME"

# Guard: validate name against known journal slugs via git kb list (read-only, sanctioned).
# Falls back to permissive (allowed=1) when no journals exist yet (clean install).
allowed=0
known_count=0
while IFS= read -r slug; do
  [ -z "$slug" ] && continue
  known_count=$((known_count + 1))
  stem="${slug##*/}"
  [ "$stem" = "$NAME" ] && allowed=1 && break
done < <(git -C "$REPO_ROOT" kb list --path "context/extensible/journals" --no-pager 2>/dev/null \
  | awk 'NR>2 && $2 != "" { print $2 }')

# No journals in store yet (clean install) — allow any well-formed name
if [ "$known_count" -eq 0 ]; then
  allowed=1
fi

if [ "$allowed" -ne 1 ]; then
  echo "journal.sh: '$NAME' is not a known journal. Refusing write." >&2
  exit 2
fi

# materialize the document to workspace (idempotent: safe if already checked out)
git -C "$REPO_ROOT" kb checkout "$DOC_PATH" -q

TARGET="$WORKSPACE/$DOC_PATH.md"

# date header owned by script; body owned by agent
DATE="$(date '+%Y-%m-%d')"
{
  printf '\n### %s — %s\n' "$DATE" "$TOPIC"
  printf '%s\n' "$BODY"
} >> "$TARGET"

# commit through kb — fail loud, no || true
git -C "$REPO_ROOT" kb commit "$DOC_PATH" \
  -m "journal: $NAME session entry $DATE"

echo "journal.sh: appended to $NAME journal ($DATE)."
