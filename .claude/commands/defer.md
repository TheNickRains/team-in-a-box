---
description: Stash a live boardroom to disk so it can be resumed later (even after machine shutdown). Usage: /defer [optional note]
---

The chair wants to pause an active boardroom and pick it up later. Subagent context dies when the terminal closes — but the boardroom's externalized state (question, participants, what each round produced, chair interjections) lives in this controller's conversation and can be written to disk.

`/defer` captures that state into `.kb/boardrooms/` as a structured stash file. `/resume-boardroom <id>` reads it back and re-spawns the participants with the prior transcript loaded so they pick up where they left off.

`$ARGUMENTS` — optional one-line note about why we're deferring (e.g., "need overnight to sit with the falsifier", "waiting on eval data"). Adds context for future-you.

## Preconditions

If this terminal is NOT currently running a boardroom (no boardroom rounds in this conversation's history), tell the chair: "No active boardroom in this terminal — nothing to defer." Stop.

## Step 1 — Build the stash

Capture from this controller's conversation history:

- **Question** — original boardroom question
- **Participants** — comma-separated persona names
- **Rounds completed** — each round's full output (every persona's position, attribution preserved)
- **Chair interjections** — anything the chair added between rounds, with round number
- **Current state** — one of:
  - `awaiting-chair-after-round-N` (round just finished, chair hasn't directed yet)
  - `mid-round-N` (some participants returned, others didn't)
  - `awaiting-question` (boardroom convened but question not yet provided)
- **Defer note** — `$ARGUMENTS` if provided, else blank

## Step 2 — Compute the stash ID

`YYYY-MM-DDTHHMM-<topic-slug>` where `<topic-slug>` is 3–5 kebab-case words distilled from the question. Example: `2026-05-14T1430-eval-set-size`.

## Step 3 — Write the stash file

Path: `.kb/boardrooms/<stash-id>.md`. Create the directory if missing.

Format:

```markdown
---
stash_id: <stash-id>
deferred_at: <ISO timestamp>
status: <current-state>
participants: <comma-separated>
note: <defer note or empty>
---

# Boardroom — <question>

**Chair:** {{HUMAN_NAME}}
**Participants:** <list>
**Question:** <question>

---

## Round 1

### <persona-1>
<full position from Round 1>

### <persona-2>
<full position from Round 1>

[etc.]

### Chair interjection before round 2
<text, if any>

---

## Round 2

[same pattern]

---

## State at defer
<one-line summary of where we paused>
```

## Step 4 — Print the defer card

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Boardroom deferred — <YYYY-MM-DD HH:MM>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stash ID: <stash-id>
Topic: <question, truncated to 80 chars>
Participants: <list>
Rounds completed: N
State: <current-state>
Note: <defer note or "—">

Resume with:  /resume-boardroom <stash-id>
List stashes: /resume-boardroom

Safe to /clear or shut down.
```

## Step 5 — Do not /clear

The chair decides when to clear. The stash is on disk; live subagents die naturally on terminal close. `/resume-boardroom` re-spawns them.

## Notes

- `.kb/boardrooms/` is local-only. If the chair works across multiple machines, commit to GitKB instead. Default local — most defers are "shut my laptop, resume tomorrow."
- Stashes are not auto-deleted on resume. They're historical record. Chair prunes manually.
- If the stash path already exists (rare — same minute, same topic slug), append `-2`, `-3`, etc.