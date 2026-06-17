---
description: End the persona session — consolidate scratch into journal, commit, clean up. Usage: /logoff
---

You are ending this persona session. This is the hard-save. You will consolidate your scratch beats into a journal entry, commit, and clean up. You are running this inside your own session — no relay, no controller. You write your own journal.

## Step 1 — Read scratch

Read `.kb/scratch/<your-persona>-session.md`.

If scratch is empty: check for snapshots at `.kb/scratch/<your-persona>-snapshot-*.md`. If snapshots exist, read the most recent one — it's the last committed state. If neither exists, journal entry will note "no beats recorded this session."

## Step 2 — Consolidate beats into a journal entry

Group beats by task tag if present (beats marked `[task-slug]` belong together). Produce one Session sub-entry per task. Untagged beats get one entry covering all.

Format per your charter. Terse — file paths, decision dates, commit hashes. No narrative.

Beats marked `NOTE:` are manual checkpoints (decisions, rejected hypotheses, direction changes). First-class content, not metadata.

**Cross-references:** if any work touched another persona's domain, add a line:
```
- XRef: <persona> — <one-line topic>
```

If any work surfaced an open question spanning domains, append it to `context/extensible/open-questions` using that doc's format.

## Step 3 — Principles

Promote to `## Principles` only if a session insight will re-apply across future work — durable, non-obvious. Most sessions produce no new principle.

When promoting a new Principle: scan existing Principles for any it supersedes. Mark superseded ones inline:
```
[SUPERSEDED YYYY-MM-DD: see <new principle slug>]
```
Do not delete — mark and leave.

## Step 4 — Append to journal

Append the Session entry (and any new/updated Principles) to `context/extensible/journals/<your-persona>`.

Count total Session entries (grep `"^### "` | wc -l). If count exceeds 20:
- Move all but the 10 most recent Session entries to `context/extensible/journals/<your-persona>-archive`
- Archive is append-only. Never delete from archive.
- Commit both files in the same commit.

## Step 5 — Commit

```bash
git kb commit --all -m "journal: <your-persona> YYYY-MM-DD — <topic>"
```

**If the commit fails: do NOT clear scratch or snapshots.** Return the error verbatim in your save card. Scratch is the only record of this session if the commit fails.

## Step 6 — Clean up (only on successful commit)

- Truncate `.kb/scratch/<your-persona>-session.md` to empty
- Delete any `.kb/scratch/<your-persona>-snapshot-*.md` files
- Delete `.kb/scratch/.active-persona-${CLAUDE_CODE_SESSION_ID}`
- Delete `.kb/scratch/.active-task-${CLAUDE_CODE_SESSION_ID}` if it exists
- Delete `.kb/scratch/.turn-counter-${CLAUDE_CODE_SESSION_ID}` if it exists

## Step 7 — Return save card

Return in this exact format and nothing else:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 <your-persona> logged off — YYYY-MM-DD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Session committed to journal:
<one-line topic per task, or "no beats recorded">

Tasks covered: <task slugs, or "untagged">
Principles promoted: <0 or N — list if any>
Principles superseded: <0 or N — list if any>
Journal archived: yes (moved N sessions to archive) | no
Open questions appended: <0 or N>
Scratch cleared: ✓ | ✗ (commit failed — scratch preserved)
```

If commit failed, append:
```
Commit error: <error text verbatim>
Recover: fix the error and re-run /logoff, or manually commit
  .kb/scratch/<your-persona>-session.md
  .kb/scratch/<your-persona>-snapshot-*.md
```

After the save card, tell the user: "Run `/clear` or close the terminal when ready."