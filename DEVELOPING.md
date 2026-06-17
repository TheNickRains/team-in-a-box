# DEVELOPING.md — Working ON the Framework

Audience: a Claude session (or human) working on team-in-a-box itself, not deploying it to a project.

---

## Golden Rule

**Never run `./setup.sh` in this working copy.**

`setup.sh` is a one-way activation. Once it completes, the canonical template is gone — you cannot recover it without resetting from git. The blast radius, by line number:

| What happens | setup.sh lines |
|---|---|
| Token-substitution in place: `CLAUDE.md`, `AGENTS.md`, `COORDINATION.md`, all `.claude/agents/*.md`, all `.claude/commands/*.md`, `CHARTER.template.md`, `templates/README.project.md` | 303–328 |
| `README.md` overwritten from `templates/README.project.md` | 338–348 |
| `CHARTER.md` created from `CHARTER.template.md` | 351–358 |
| Unselected seat charters deleted from `.claude/agents/` | 364–393 |
| `.claude/tools/chair-guard.env` created (untracked) | 404–410 |
| `.claude/hooks/chair-guard.sh` patched in place | 411–437 |
| `.kb/` runtime directories and `events.log` created (untracked) | 192–194 |
| `git-kb` symlink added to `~/.local/bin` (untracked, outside repo) | 483–484 |
| `.claude/.init-state` created (untracked) | 558–559 |
| **Deleted:** `TOKENS.md`, `CHARTER.template.md`, `templates/`, `DEVELOPING.md` | 548–553 |

All substitution is in-place (`sed` via tmp file). There is no dry-run flag. There is no undo.

---

## Dogfooding Without Activating

You can use the team to improve the team — no activation required.

- `claude --agent architect` (or any seat) — loads the tokenized charter. The unsubstituted `{{TOKENS}}` appear as literal text in identity lines. Nothing breaks; agents understand the context.
- `/boardroom` — runs fine. Personas spawn, hold positions, produce output.
- `/charter` — writes `CHARTER.md` from `CHARTER.template.md`. It does NOT run `setup.sh`. Safe.
- `git kb` shim — works from the raw template state as long as `.kb/` dirs exist (run `mkdir -p .kb/scratch .kb/tasks .kb/claims .kb/docs && touch .kb/events.log` once if needed).

The only capability that requires activation is testing that `setup.sh` itself works correctly — token substitution, seat pruning, README replacement, chair-guard wiring.

---

## Safe Ways to Test the Activation Flow

When you change `setup.sh`, a charter, or a command template and need to verify a real install:

### 1. Worktree (recommended)

```bash
git worktree add ../tiab-activate throwaway-test
cd ../tiab-activate
./setup.sh --yes
# test the result
cd /Users/nicholasrains/code/team-in-a-box
git worktree remove --force ../tiab-activate
git branch -D throwaway-test
```

The canonical tree is never physically touched. The worktree gets its own working directory; `setup.sh` runs against that copy. Cleanup is one command.

### 2. Throwaway copy

```bash
cp -R /Users/nicholasrains/code/team-in-a-box /tmp/tiab-test
cd /tmp/tiab-test
./setup.sh --yes
# test the result
rm -rf /tmp/tiab-test
```

No git involvement. Fast. No residue in the repo.

### 3. Branch-in-place (use with care)

A branch preserves committed history and `git checkout <dev-branch>` restores tracked files that `setup.sh` modified — BUT `setup.sh` leaves untracked residue that a checkout does NOT remove:

- `CHARTER.md` (created, not in tree)
- `.claude/.init-state` (created, not in tree)
- `.kb/` runtime dirs (created, not in tree)
- `git-kb` symlink in `~/.local/bin` (outside repo)

Full restore after an in-place test:

```bash
git checkout <dev-branch>
git reset --hard
git clean -nd          # ALWAYS preview first
git clean -fd          # then delete untracked residue
```

Never commit the activated state to a branch you intend to merge. Check with `git status` before committing anything.

---

## Commit / Push Discipline

This is the published public repo. Hard rules:

- Do NOT `git commit` or `git push` without the human's explicit approval.
- Never force-push or rewrite already-pushed history. Forward-only.
- Stage specific files by name — never `git add -A` or `git add .` on this repo.

---

## Editing Rules

**Keep charters tokenized.** Never hardcode a specific project name, domain, or path into `.claude/agents/*.md`. The token placeholders (e.g. `{{PROJECT_NAME}}`, `{{DEPLOY_DOMAIN}}`) are what make activation work.

**Token contract is three-way.** If you add, rename, or remove a token:

1. Update `TOKENS.md` — add the row and its locations.
2. Update `setup.sh` step 5 — add the `"TOKEN_NAME:$V_TOKEN_NAME"` line in `_substitute_file` (lines 100–123) and add a `V_TOKEN_NAME=` assignment in step 3 (lines 236–284).
3. Update every placement site listed in `TOKENS.md`.

If any of the three is missing, activation produces a file with a literal `{{TOKEN_NAME}}` string where the value should be — and step 6e's assertion will catch it and abort.

**The assertion exclusion list** (setup.sh line 453) skips `./docs/*`, `./templates/*`, `./TOKENS.md`, `./CHARTER.template.md`, and `./DEVELOPING.md` when scanning for unresolved `{{` tokens. If you add a new scaffolding-only file that intentionally contains `{{...}}` examples, add it to that `case` block.
