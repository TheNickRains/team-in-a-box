# {{PROJECT_NAME}} — How Work Gets Structured

## The Decomposition Model

Work has three levels:

```
Epic      — the plan; a reference doc that names the goal and owns the tasks beneath it
  Features    — a feature or deliverable; has an assignee and a parent epic
    Tasks — the dispatch unit; one agent, one shot, one clear outcome
```

The chair dispatches at the **subtask** grain. If something can't be finished by one agent in one session, it's not a subtask yet — scope it smaller. Epics and tasks are planning artifacts; subtasks are the unit of work.

---

## Headlights

Only plan the next 6ft. Don't build a task tree for work you can't see yet. The shape of subtask 4 depends on what subtask 1 returns — you don't know that yet, so don't pretend you do.

**In practice:** create the next one or two dispatchable subtasks. When they return, create the next. The backlog is a direction, not a commitment.

**General is the headlights enforcer.** Call when the next 6ft is unclear, too much is in flight, or a task isn't closing. One verdict, one load-bearing reason — no speculative sequencing.

---

## Scope Before Dispatch

Before routing any task, the chair has to know the shape of the work. Two paths:

**Clear domain, clear scope** → dispatch directly to the right persona (`/dispatch`).

**Uncertain approach, cross-cutting, or high-stakes** → convene a boardroom first (`/boardroom`). By continuing rounds the participants are able to engage in socratic discourse until a suitable output has been reached. The boardroom's output is a decision + the next falsifiable step. That step becomes the subtask.

Never dispatch into uncertainty. A wrong dispatch wastes a full agent spawn on the wrong thing. A one-round boardroom is cheaper than rework.

---

## Sprint Ownership

**Human owns prioritization and approval.** Agents propose; Human approves. The chair never autonomously populates the task board.

- For a single obvious next step: surface it to Human, proceed when confirmed.
- For 3 or more tasks: write out the full list before creating anything. Human reviews and approves the sequence.

**ScrumMaster owns the mechanical ceremony.** Once Human approves, ScrumMaster handles:

- Opening and routing worktrees for each task branch
- Marking tasks in-flight, tracking status, logging blockers
- Calling "done" and closing worktrees after Human confirms

The chair does not decide what gets built. It decides how to structure and route what Human has decided to build. ScrumMaster makes sure what started actually closes.

---

## Source of Truth

All active work lives in GitKB. The sprint board is the authoritative view of what's in flight, what's blocked, and what's next.

```bash
git kb board                          # full sprint kanban
git kb board --group-by assignee      # who owns what
git kb list --type task --status active  # what's in flight
```

Tasks not in GitKB don't exist. If work is happening, it has a task. If it doesn't have a task, create one before proceeding.

---

## Dispatch Flow

```
Human gives direction
  → chair scopes
      (General if next step is unclear or too much is in flight)
      (boardroom if cross-cutting or high-stakes)
    → chair surfaces task list to Human
      → Human approves
        → ScrumMaster opens worktree + marks task in-flight
          → chair dispatches one subtask at a time
            → agent returns output
              → ScrumMaster updates status; calls close when Human confirms
                → chair routes next subtask or surfaces blocker to Human
```

The chair is the constant in this loop. It never leaves the loop to write code.