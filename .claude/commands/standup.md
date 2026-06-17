---
description: Daily standup across all personas — pull latest Session entries, summarize what shipped, what's blocked, what's next
---

When the user runs `/standup`:

1. Run these in parallel via Bash:
   - `git kb show context/extensible/journals/architect`
   - `git kb show context/extensible/journals/fullstack`
   - `git kb show context/extensible/journals/designer`
   - `git kb show context/extensible/journals/scientist`
   - `git kb show context/extensible/journals/copywriter`

2. From each journal, extract ONLY the most recent Session entry (the bottom-most entry under `## Sessions`).

3. Also run `git kb show {{KB_SPRINT_OVERVIEW_SLUG}}` and note the target end date / sprint state.

4. Format the standup as:

```
# Standup — <today's date> <current time if known>

**Sprint:** check `{{KB_SPRINT_OVERVIEW_SLUG}}` for current sprint + end date

## architect
<latest session bullets — Decided / Open / Next>

## fullstack
<latest session bullets — Shipped / Blocked / Next>

## designer
<latest session bullets — Shipped / Considered-rejected / Next>

## scientist
<latest session bullets — Hypothesis / Result / Next>

## copywriter
<latest session bullets — Brief / Shipped / Killed / Next>

## Cross-team open questions
- <consolidate the most pressing items from each "Open" / "Next" / "Blocked">

## The General's check — stop starting, start finishing
- WIP across personas: count what's in flight. Flag if a single persona has more than 2 active tasks.
- Anything currently in flight that's 60ft ahead instead of 6ft? Flag it. Slice it.
- Any task in flight without a journal Session entry in 3+ days? Name the silent blocker.
- What closes by tomorrow? Anchor the next 6ft to a closeable thing, not a started thing.
```

5. End with: "Who needs to be dispatched? Suggested: <name top 1-2 priorities>."

6. Do NOT spawn personas as part of standup. Standup is observation only. Action happens after the user picks who to dispatch.
