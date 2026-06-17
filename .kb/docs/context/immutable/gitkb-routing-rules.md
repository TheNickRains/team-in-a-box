# GitKB Routing Rules (file-based shim)

This repo uses the file-based KB shim (`kb.sh`) behind the `git kb` command. Context lives in `.kb/` at the repo root. Agents MUST route through the verb surface — never read `.kb/store/` or `.kb/docs/` directly with `cat`/`grep`.

## Store layout

```
.kb/
  tasks/       — one .md file per task; front-matter lines: title/status/assignee/parent/tags
  docs/        — KB docs addressed by slug (e.g. context/immutable/headlights-methodology)
                 Resolved as .kb/docs/<slug>.md
  claims/      — atomic claim records (one file per in-flight task); gitignored
  scratch/     — session markers (.active-task-<session-id>); gitignored
  workspaces/  — journal checkout workspace (writable copy of docs for editing)
  events.log   — append-only event log; gitignored
```

## The 15-verb surface

Use these verbs; never raw-read the store:

| Verb | When to use |
|---|---|
| `git kb resolve --auto --quiet` | Find the active task for this session |
| `git kb ready --quiet` | Find the highest-priority ready task |
| `git kb context --task <id>` | Load journal + task + referenced docs in one call |
| `git kb assign <id> <agent>` | Claim a task (atomic; fails if already claimed) |
| `git kb unassign <id>` | Release a claim |
| `git kb commit <id> -m "<msg>"` | Append an event + git-stage KB files |
| `git kb show <slug>` | Read a KB doc by slug |
| `git kb list --path context/` | List docs under a path prefix |
| `git kb list --type task --status active` | List in-flight tasks |
| `git kb board` | Full kanban by status |
| `git kb board --group-by assignee` | Kanban by agent |
| `git kb set <id> --<field> <value>` | Update a task field |
| `git kb create task --title "..." --assignee <agent>` | Create a task |
| `git kb create <slug>` | Create a KB doc |
| `git kb ai semantic <query>` | Fuzzy search across KB content |
| `git kb checkout <slug>` | Materialize a doc into the edit workspace |
| `git kb events` | Print the events log |

## PATH setup

`git kb` resolves when `.claude/tools/git-kb` is on PATH:

```bash
export PATH="$(pwd)/.claude/tools:$PATH"
```

Or symlink: `ln -sf "$(pwd)/.claude/tools/git-kb" ~/.local/bin/git-kb`

## Slug convention

Docs are addressed by their path relative to `.kb/docs/`, without the `.md` suffix:
- `context/immutable/headlights-methodology` → `.kb/docs/context/immutable/headlights-methodology.md`
- `context/extensible/decisions-log` → `.kb/docs/context/extensible/decisions-log.md`

Immutable slugs (`context/immutable/`) contain project-invariant methodology. Extensible slugs (`context/extensible/`) contain project-specific content that grows over time.

## Collision protocol

If `git kb assign` fails (task already claimed), stop. Do not `--force`. Surface the collision to the chair.
