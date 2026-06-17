---
description: Show the sprint kanban board — tasks by status, persona workload, blockers, headlights check
---

When the user runs `/kanban`:

1. Run these in parallel via Bash:
   - `git kb board --tags sprint` — status-grouped view (DRAFT / ACTIVE / BLOCKED / COMPLETED)
   - `git kb board --tags sprint --group-by assignee` — workload-by-persona view
   - `git kb list --type task --tags sprint` — full task list with statuses
   - `git kb show {{KB_SPRINT_OVERVIEW_SLUG}}` — sprint state + end date

2. Format the response like this:

```
# Sprint Kanban — <today's date>
**Sprint:** `git kb show {{KB_SPRINT_OVERVIEW_SLUG}}` — check end date

## Status view
<git kb board --tags sprint output, lightly trimmed>

## Workload by persona
<git kb board --tags sprint --group-by assignee output, lightly trimmed>

## Tasks I'd surface
- **Load-bearing now:** <name 1-2 active tasks that block everything else>
- **Ready to start:** <name draft tasks with no dependencies>
- **Waiting on:** <name draft tasks blocked by an active one>

## The General's check — stop starting, start finishing
- WIP count: how many tasks are active right now? If more than 2-3 per persona, name what closes first.
- Anything on this board that's 60ft instead of 6ft? Slice it.
- Any task with no assignee? (the board shows (UNSET) column for those)
- Any active task that's been active without progress for too long? Name the blocker — not the excuse.
- Any new "ready to start" tasks the user wants to open? Push back if WIP is too high. Close before opening.

## Moves available
- Promote a draft to active: `git kb set <slug> --status active`
- Mark a task done: `git kb set <slug> --status completed`
- Reassign: `git kb assign <slug> <persona>`
- Drill into a task: `git kb show <slug>`
```

3. End with: "What moves today?"

4. Do NOT spawn personas as part of /kanban. Board is observation only. Dispatch is separate.

5. If you notice obvious decay (markdown checklists drifting from native tasks, untriaged tasks accumulating, an active task with no journal entry from its persona in days), flag it.
