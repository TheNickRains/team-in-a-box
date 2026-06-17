---
description: Route a scoped task/subtask to the right specialist agent — or convene a boardroom when the path is unclear. The orchestrator dispatches; it does NOT write code itself. Usage: /dispatch <task-slug> [or a freeform ask]
---

`$ARGUMENTS` — a task/subtask slug to dispatch, OR a freeform description of work to route.

Examples:
- `/dispatch auth-onboarding-flow` — dispatch a known task to its assignee
- `/dispatch rework the signup flow into a step-by-step wizard` — freeform; you scope + route it
- `/dispatch auth-onboarding-flow --boardroom` — force a boardroom instead of single dispatch

## Where this command runs (hard requirement)

`/dispatch` spawns specialists via the `Agent(subagent_type=…)` tool. **That tool only exists in the top-level orchestrator session.** A persona session (anything started via `claude --agent <name>`) does NOT have it and cannot spawn sub-agents. If you find yourself running `/dispatch` and there is no Agent tool available, you are in a persona seat, not the orchestrator — stop and tell the chair to dispatch from the orchestrator chat. Do not try to fake the spawn by shelling out to `claude -p`.

## The one rule this command exists to enforce

**The orchestrator routes work; it does NOT do the work.** When running `/dispatch`, you do not open the Edit/Write tools on product code. You read the task, decide the route, and spawn the specialist (or a boardroom). If you catch yourself reaching for Edit on `app/`, `lib/`, or `components/`, you have slipped into executor mode — stop and dispatch instead.

The only files `/dispatch` itself may write are: GitKB task docs (to create/update subtasks) and `.kb/scratch` notes.

## Task hierarchy (already supported, no new model)

- **Epic** (the plan) — `reference` doc, `tags:[…,epic]`
- **Task** (a feature) — `task` doc, `parent: <epic-slug>`, has an `assignee`
- **Subtask** (a to-do — the dispatch unit) — `task` doc, `parent: <task-slug>`

Dispatch operates at the **task/subtask** grain. If the thing handed to you is bigger than one specialist can finish in one shot, it is not dispatchable yet — scope it first (see Mode B).

## Step 1 — Resolve the input

If `$ARGUMENTS` looks like a slug, fetch it:
```
git kb show <slug>
```
Read: title, description, `assignee`, `parent`, `status`, any `blocks`/`blockedBy`.

If it's freeform, you have no task doc yet — you're in scoping territory. Go to Mode B.

If a slug is given but `git kb show` fails, run `git kb list --type task --tags sprint` and ask the chair which task they meant. Do not guess.

## Step 2 — Decide the route

Apply this decision in order:

1. **Blocked?** If the task has an unmet `blockedBy` / depends on an incomplete task → do not dispatch. Tell the chair what blocks it. Stop.
2. **Single, clear domain + well-scoped?** → **Mode A: single dispatch.**
3. **Cross-cutting (2+ persona domains), high-stakes, or you're not wholly sure how to approach it?** → **Mode B: boardroom to scope, then dispatch.**
4. **Chair passed `--boardroom`?** → Mode B regardless.

When unsure between A and B, **default to B.** A wrong single-dispatch wastes a whole spawn on the wrong approach; a boardroom is cheaper than rework.

State your routing call to the chair in one line before acting: `Routing <slug> → <persona>` or `Routing <slug> → boardroom(<personas>)`. Then proceed.

## Mode A — Single dispatch

1. Confirm the assignee. If the task has no `assignee`, infer the right persona from `.claude/agents/*.md` ownership and set it: `git kb assign <slug> <persona>`.
2. Call ScrumMaster to open a worktree and mark it in-flight: tell ScrumMaster the slug and assignee. ScrumMaster handles `git kb set <slug> --status active` and `git worktree add`.
3. Spawn the specialist via the Agent tool (`subagent_type = assignee`, `run_in_background: false`) with a self-contained brief:

```
You are being dispatched for a single scoped task. Your charter is loaded as your system instructions.

Task: <title>
Slug: <slug>
Parent: <parent task/epic title>
Description: <full description from the doc>

Relevant code paths (read these, don't reason about code you haven't opened):
<list any paths named in the task or that you know are involved — be specific>

Do NOT run /boot. Do NOT spawn other agents. Do NOT expand scope beyond this task — if you discover the task is bigger than stated, STOP and report back rather than ballooning it.

When done:
1. Commit your own work (git add + commit with a clear message).
2. Return a TERSE summary only: what changed (files), what's verifiable now, what's next, any blocker. Do NOT paste full diffs.
```

4. When the agent returns, relay its terse summary to the chair and:
   - Success → hand to ScrumMaster to call close: ScrumMaster updates status to completed and cleans up the worktree after Human confirms.
   - Blocker → leave active, surface the blocker to the chair, propose the unblocking move (often a boardroom or a dependency task).

## Mode B — Boardroom to scope, then dispatch

You're not sure of the approach, or it spans domains. Do not dispatch into uncertainty.

1. Pick participants from the domains the work touches (designer for form/UX, architect for structure, fullstack for implementation reality, scientist for algorithm, strategist for what-matters, senior-engineer for cost/risk). Keep it to the 2–4 who actually own a piece.
2. Hand off to the boardroom flow — tell the chair:
   `This needs scoping. Convening: /boardroom <personas> <the scoping question>`
   and run that flow (or instruct the chair to, if they prefer to chair it live).
3. The boardroom's output is a **decision + the falsifiable next step**. Convert that into one or more dispatchable subtasks:
   ```
   git kb create task --title "<subtask>" --parent <parent-task-slug> \
     --assignee <persona> --tags sprint --status draft
   ```
4. Surface the new subtask list to the chair for approval (per task-approval rule — agents propose, chair approves). Do NOT auto-dispatch the freshly minted subtasks; that's the chair's call.

## Headlights / cost discipline

- One dispatch = one spawn = real tokens. Don't dispatch a task a single sentence of guidance would resolve.
- Don't pre-create a subtask tree for work six feet past the current one. Scope only the next dispatchable unit.
- Boardroom is the more expensive route — use it to *avoid* wrong work, not to avoid deciding.

## Deferred (NOT in v0 — do not build until single dispatch is proven)

- **Dependency-ordered sequencing:** dispatching a chain of subtasks in `blockedBy` order, awaiting each before the next. Real feature, but it doesn't work until single dispatch is solid. Build it when the chair has run single dispatch enough to trust it.
- **Auto-terminal `/init` fan-out:** a slash command can't open terminals. If true separate-session hub-and-spoke is wanted, the chair runs `claude --agent <name>` by hand; dispatch can print the exact command to copy.
