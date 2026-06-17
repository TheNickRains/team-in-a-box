# team-in-a-box

A portable engineering organization for Claude Code. Drop it into any repo and get a fully-wired team of agent personas: a chair (PM), 12 specialist/worker seats, a boardroom protocol, a headlights planning discipline, and a file-based KB that persists context across sessions — no external service required.

---

## What it is

**Hub-and-spoke agent system.** The chair (CLAUDE.md) is the PM. Specialists advise; workers execute. Work flows Human → chair → agent → chair. Agents never coordinate directly.

**12 seats out of the box:**
- Specialists: architect, scientist, strategist, senior-engineer, ux
- Workers: fullstack, designer, naieve-copywriter, technical-copywriter
- System: general (headlights enforcer), recorder (compression), scrum-master (kanban)

**Boardroom protocol.** Cross-cutting or high-stakes decisions go to `/boardroom architect,scientist,...` — one round of Socratic dispute per persona, chair calls the result.

**Headlights discipline.** Only plan the next 6ft. Add abstractions when the task demands them, not before. General is the enforcer.

**File-based KB.** Zero external dependencies. Context lives in `.kb/` — tasks, docs, claims, journals, events. `git kb` is a PATH shim over `kb.sh`. Works offline, in any git repo, no MCP server required.

---

## Install

```bash
# Option A — clone
git clone https://github.com/your-org/team-in-a-box my-project-team
cd my-project-team

# Option B — degit (no git history)
npx degit your-org/team-in-a-box my-project-team
cd my-project-team
```

Then run setup:

```bash
./setup.sh
```

---

## What setup.sh does

`setup.sh` runs interactively and asks you for:

1. **Project name** — replaces `{{PROJECT_NAME}}` everywhere (CLAUDE.md, all agent charters, README)
2. **Your name** — replaces `{{HUMAN_NAME}}` (chair identity in CLAUDE.md, boardroom prompts, CHARTER.md)
3. **Stack description** — one sentence for CLAUDE.md's Project Context block
4. **Deploy instructions** — your deploy command(s), wired into CLAUDE.md and README
5. **Self-hosting domain** — for the fullstack agent's ownership bullet
6. **KB slug overrides** — the four boot-time `git kb show` slugs (product thesis, schema, stages, sprint overview); defaults are sensible for most projects
7. **Scientist domain** — what your algorithm/ML agent owns
8. **Epic names** — infra epic, landing epic, primary algorithm epic
9. **Design token namespace** — CSS custom property prefix
10. **Design reference path** — where your design brief lives

After answering, setup.sh:
- Renders all `{{TOKEN}}` placeholders in CLAUDE.md, AGENTS.md, COORDINATION.md, and all agent charters
- Copies `CHARTER.template.md` → `CHARTER.md` and prompts you to run `/charter` to seed it
- Writes `templates/README.project.md` → `README.md` with your project's stack and deploy info
- Prints next steps

---

## The file-based KB

Context lives in `.kb/`:

```
.kb/
  tasks/       — one file per task (front-matter: title/status/assignee/parent/tags)
  docs/        — KB docs by slug path (e.g. context/immutable/headlights-methodology.md)
  claims/      — atomic claim files (one per in-flight task)
  scratch/     — session markers (ephemeral, gitignored)
  workspaces/  — journal checkout workspace
  events.log   — append-only event log (gitignored)
```

Agents address docs by slug: `git kb show context/immutable/headlights-methodology`. The slug resolves to `.kb/docs/<slug>.md`. You can create docs with `git kb create <slug>` or by writing `.kb/docs/<slug>.md` directly.

Seeded slugs (filled at install time):
- `context/immutable/headlights-methodology` — the 6ft planning rule
- `context/immutable/gitkb-routing-rules` — how to use the shim
- `context/extensible/decisions-log` — boardroom decision record
- `context/extensible/open-questions` — cross-domain questions queue
- Plus scaffold stubs for: `route-map`, `dev-environment`, `eval-methodology`, `visual-identity`, `api-architecture`, `patterns/sequential-reveal`, and others

---

## Pointing git-kb onto PATH

The `git kb` command resolves when `git-kb` (the stub in `.claude/tools/`) is on your PATH. Two ways:

```bash
# Per-session (add to your shell rc or a direnv .envrc)
export PATH="$(pwd)/.claude/tools:$PATH"

# Permanent symlink
ln -sf "$(pwd)/.claude/tools/git-kb" ~/.local/bin/git-kb
```

Verify: `git kb board` should print an empty kanban.

---

## Bring your own GitKB

The default shim is zero-dependency but limited (no semantic search, no vector index, no cross-repo shared context). If you want to swap in the real GitKB binary, see `docs/gitkb-adapter.md`. The 15-verb contract is identical — charters need no changes.

---

## License

MIT
