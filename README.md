# team-in-a-box

**An engineering organization for Claude Code — not a role pack.**

Most "multi-agent" setups are invisible: auto-dispatched subagents that fire inside a single chat. No chain of command. No one to talk to. No memory of what went wrong last time.

team-in-a-box is different. You get a **manager who never writes code**, 12 **employees you can sit with 1:1**, and a **boardroom for the hard calls** — all wired from a single `./setup.sh`.

---

## How it works

```
You
 └─ Chair (CLAUDE.md) — the manager. Routes, holds context, NEVER codes.
      │   Has a subconscious: CHARTER.md — a living profile of how you think.
      │
      ├─ claude --agent architect      ← 1:1 direct session
      ├─ claude --agent fullstack      ← 1:1 direct session
      ├─ claude --agent ux             ← 1:1 direct session
      ├─ ... (12 seats total)
      │
      └─ /boardroom architect,scientist,strategist <question>
           Parallel Socratic dispute. Output: decision + next falsifiable step.
```

Work flows **Human → chair → agent → back to chair**. Agents never coordinate directly. The chair is the single point of context, sequence, and accountability.

---

## The three things that make this different

**1. Employees you talk to 1:1.**
Every seat is a real `claude --agent` session — its full charter, journal, and principles loaded. Pull any specialist into a room:

```bash
claude --agent architect     # schema, tradeoffs, ADRs
claude --agent fullstack     # implementation
claude --agent strategist    # what to cut, what to build next
```

This is not a subagent firing invisibly inside your chat. It's a conversation with a specialist who knows what they own and what they don't.

**2. A manager with a subconscious.**
The main session (the chair) never writes a line of code. It routes, holds context, convenes boardrooms, and demands cited file paths from everyone it talks to.

Run `/charter` once and the chair gets seeded with a living profile of how you think — your decision patterns, friction triggers, failure modes. The profile starts as a hypothesis and gets corrected by observation. The machine learns how *you* decide.

**3. A boardroom for hard calls.**
When a decision crosses domains or is hard to reverse:

```
/boardroom architect,scientist,senior-engineer what's the right data model for X
```

Each persona holds a position, names their assumption, and states the one falsifiable test that would change their mind. The chair (you) calls the meeting. Output: a decision + the next experiment, logged to the decisions-log. Not consensus — Socratic dispute.

---

## The 12 seats


| Seat                 | Class      | What it owns                                                          | Summon                                |
| -------------------- | ---------- | --------------------------------------------------------------------- | ------------------------------------- |
| architect            | Specialist | Schema, data model, structural tradeoffs, ADRs                        | `claude --agent architect`            |
| scientist            | Specialist | Algorithm, signal extraction, evaluation                              | `claude --agent scientist`            |
| strategist           | Specialist | Prioritization, scope cuts, what-to-build-next                        | `claude --agent strategist`           |
| senior-engineer      | Specialist | Pre-mortem, refactor-vs-ship, technical debt                          | `claude --agent senior-engineer`      |
| ux                   | Specialist | User flows, edge cases, wireframes — hard gate before UI starts       | `claude --agent ux`                   |
| fullstack            | Worker     | End-to-end implementation: routes, APIs, infra                        | `claude --agent fullstack`            |
| designer             | Worker     | UI, motion, layout hierarchy — never writes copy                      | `claude --agent designer`             |
| naieve-copywriter    | Worker     | First-touch surfaces: hero, landing, onboarding (5th-grade cap)       | `claude --agent naieve-copywriter`    |
| technical-copywriter | Worker     | Downstream copy: dashboard, investor narrative, blog, SEO             | `claude --agent technical-copywriter` |
| general              | System     | WIP discipline, headlights enforcer — call when too much is in flight | `claude --agent general`              |
| recorder             | System     | Compression only — pre-digests artifacts before boardroom spawns      | `claude --agent recorder`             |
| scrum-master         | System     | Living kanban, worktree lifecycle, calls "done"                       | `claude --agent scrum-master`         |


**Each agent is three things:** a charter (`.claude/agents/<name>.md`), a principles log (what went wrong), and a session journal (long-term memory across sessions). Agents without journals start cold. Agents without principles repeat mistakes.

---

## Install

```bash
# Clone (with git history)
git clone https://github.com/your-org/team-in-a-box my-project
cd my-project

# Or degit (clean slate)
npx degit your-org/team-in-a-box my-project
cd my-project
```

Then run the setup interview:

```bash
./setup.sh
```

The interview asks:

1. **Project name** — replaces `{{PROJECT_NAME}}` across all charters
2. **Your name** — wired into the chair identity and boardroom prompts
3. **Product description** — one sentence
4. **Stack** — e.g. `Node / TypeScript / Postgres`
5. **Deploy command** — wired into the chair's context block
6. **Which seats to activate** — `all` or a comma list

After answering, setup.sh substitutes all tokens, renders `CHARTER.md`, prunes unselected seats, symlinks `git kb` onto PATH, seeds the KB doc stubs, and drops one starter task on the board.

**The "it worked" moment:**

```
=======================================================
  my-project is ready.
=======================================================

Board:
[ ready ] First task: run /charter to seed your operating charter
```

---

## What to do first

```bash
# 1. Seed your operating charter (the manager's profile of how you think)
/charter

# 2. Open a persona for a direct 1:1
claude --agent architect

# 3. Commit the initialized project
git add -A && git commit -m "init: team-in-a-box setup"
```

---

## The commands


| Command                                   | What it does                                                                           |
| ----------------------------------------- | -------------------------------------------------------------------------------------- |
| `/charter`                                | Seed the living chair profile from birth data (astro prior; observation overwrites it) |
| `/boardroom persona1,persona2 <question>` | Parallel Socratic dispute; chair calls the meeting                                     |
| `/dispatch <task>`                        | Route a scoped task to the right agent                                                 |
| `/kanban`                                 | Print the sprint board                                                                 |
| `/standup`                                | Status across in-flight tasks                                                          |
| `/logoff`                                 | Close the session; agents journal; claims released                                     |
| `/defer`                                  | Stash a boardroom mid-session for resumption                                           |


---

## The KB

Context persists in `.kb/` — zero external dependencies, works offline, inside any git repo.

```
.kb/
  tasks/     — one file per task (status, assignee, tags)
  docs/      — KB docs by slug path
  claims/    — in-flight task claims (atomic)
  events.log — append-only event log
```

Agents read docs by slug: `git kb show context/immutable/headlights-methodology`. The shim resolves slugs to `.kb/docs/<slug>.md`.

If you want semantic search, vector indexing, or cross-repo shared context, swap in the real GitKB binary — the 15-verb `git kb` contract is identical. See `docs/gitkb-adapter.md`. No agent charter changes needed.

---

## What this is NOT

- **Not a role pack.** Role packs give Claude a persona label. This gives it an org chart, a chain of command, and memory of what went wrong.
- **Not auto-dispatched invisible subagents.** There is no one to talk to in those systems. Here, every seat has a charter, principles, and a journal. You pull them into the room.
- **Not a process framework.** Process frameworks tell you how to structure work. This tells your agents who owns what, who never writes code, and who calls "done."
- **Not a configuration you forget about.** The chair's profile of how you decide gets sharper every session. The agents log what went wrong. The machine learns.

---

## License

MIT — see [LICENSE](LICENSE).