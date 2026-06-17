---
description: Resume a deferred boardroom — re-spawns participants with prior discourse loaded. Usage: /resume-boardroom [stash-id]
---

The chair is picking up a previously deferred boardroom. The stash file in `.kb/boardrooms/` has the question, participants, and full round-by-round transcript. Each Agent spawn responds once — there is no persistent subagent across rounds in 2.1.x. Resume = re-spawn participants with the compressed prior discourse as context, and continue.

`$ARGUMENTS` — the stash ID (a filename in `.kb/boardrooms/`, with or without `.md`).

## Step 1 — Resolve the stash

**If `$ARGUMENTS` is empty:** list every file in `.kb/boardrooms/`. Format:

```
Available deferred boardrooms:

  <stash-id>       <deferred_at>   <participants>   <truncated question>
  <stash-id>       <deferred_at>   <participants>   <truncated question>

Resume with: /resume-boardroom <stash-id>
```

Stop and wait for the chair to choose.

**If `$ARGUMENTS` is provided:** read `.kb/boardrooms/<stash-id>.md`. Strip trailing `.md` if included. If the file doesn't exist, list available stashes and tell the chair the ID didn't match.

## Step 2 — Parse the stash

From frontmatter: `participants`, `status`, `deferred_at`, `note`.
From the body: the question, each round's full content, chair interjections, the final state line.

## Step 3 — Recorder compression of prior discourse

Invoke the `recorder` agent with:

```
Compress the following deferred boardroom transcript for participant re-spawn.

Question: <question>
Participants: <list>

For each round, compress each persona's position to:
- Position (1 sentence)
- Key ask from others (1 sentence)
- Any shift noted (1 sentence or "no shift")

<paste full stash body>

Target: under 2,000 tokens total. Preserve attribution clearly.
```

Hold recorder's output as `<PRIOR DISCOURSE COMPRESSED>`. Use this in re-spawn prompts instead of the raw stash.

## Step 4 — Re-spawn the participants

Single assistant message, one Agent call per participant in parallel, `run_in_background: false`. For each, `subagent_type = persona name`. Prompt:

```
You are rejoining a boardroom that was deferred and is now resuming.

Original question: <question>
Chair: {{HUMAN_NAME}}. Other participants: <list>.
Deferred at: <deferred_at>
Defer note: <note or "none">

PRIOR DISCOURSE (recorder-compressed — rounds 1 through N):
<PRIOR DISCOURSE COMPRESSED from Step 3>

State at defer: <final state line from the stash>

Your charter is loaded as your system instructions. Apply your identity, voice, ownership, hard rules.

Do NOT run /boot. Do NOT fetch shared docs — they are implicit in the prior discourse above. Do NOT spawn subagents. Do NOT journal — that happens at meeting close.

In under 60 words: acknowledge you're rejoining (ONE sentence), then state what you think the next move is from your seat (ONE sentence — continue to Round N+1, call it, ask chair to clarify, etc.).

Do NOT re-argue prior rounds.
```

## Step 5 — Print the resume card

When all participants return their acknowledgments:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Boardroom resumed — <YYYY-MM-DD HH:MM>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Topic: <question>
Participants: <list>
Rounds completed before defer: N
State at defer: <final state line>

Each seat checked in:

<emoji> <persona-1>: <1-sentence acknowledgment + next-move suggestion>
<emoji> <persona-2>: <same>

Chair, take it. Options:
- Continue to Round <N+1> with an interjection or just say "continue"
- Call the meeting → record decision to decisions-log
- Defer again → /defer
```

## Step 6 — Hand control back to the chair

Stop. Wait for the chair's direction. From here this terminal behaves exactly like a live boardroom — same round protocol as `/boardroom`, same recorder compression between rounds.

## Notes

- **Subagent identity is fresh.** Each Agent spawn is new; the recorder-compressed transcript is their shared ground.
- **If a participant's persona has been edited since defer:** they pick up the new charter. Correct — newer guidance overrides older snapshots.
- **If a stash is corrupted:** tell the chair what's salvageable, ask whether to re-spawn with partial transcript or abandon and start fresh.
- The stash file is NOT deleted on resume. Historical record.
- Recorder compression in Step 3 is non-optional — raw stash transcripts grow large; compressing keeps re-spawn payloads lean.