# Bring Your Own GitKB

team-in-a-box ships with a file-based shim (`kb.sh`) that implements the 15-verb `git kb` contract against a plain `.kb/` directory tree. It requires no external services, no MCP server, and no network.

If you want to swap in the real GitKB binary — for semantic search, vector indexing, cross-repo shared context, or enterprise features — this document shows you how. **No agent charter changes are required.** The verb contract is identical.

---

## What to swap

Replace the PATH shim entry in `.claude/tools/git-kb` with a pointer to the real `git-kb` binary, or add the real binary's parent directory earlier on PATH so it shadows the shim.

The shim at `.claude/tools/git-kb` currently does:
```bash
exec "$SCRIPT_DIR/kb.sh" "$@"
```

Once the real binary is on PATH ahead of `.claude/tools/`, `git kb` resolves to it automatically.

---

## MCP server block

If you use GitKB's MCP server mode (for richer tool access from within Claude Code), add this block to your `.claude/settings.json` under `"mcpServers"`:

```json
{
  "mcpServers": {
    "gitkb": {
      "type": "stdio",
      "command": "<GITKB_BINARY_PATH>",
      "args": ["mcp", "--root", "<GITKB_ROOT>"],
      "env": {}
    }
  }
}
```

Replace `<GITKB_BINARY_PATH>` with the absolute path to your `git-kb` binary (e.g. `/usr/local/bin/git-kb`) and `<GITKB_ROOT>` with the absolute path to your repo root (e.g. `/home/user/my-project`).

Once configured, MCP tools `kb_show`, `kb_list`, `kb_search`, `kb_symbols`, `kb_callers`, and `kb_impact` become available inside Claude Code sessions.

---

## The 15-verb contract

Both the file-based shim and the real GitKB binary honor the same verb surface. Charters call these verbs — they do not read `.kb/` files directly.

| Verb | Purpose |
|---|---|
| `resolve` | Determine the active task for the current session |
| `ready` | Return the highest-scored ready task |
| `context` | Return journal + task + referenced docs in one call |
| `assign` | Atomically claim a task for an agent |
| `unassign` | Release a task claim |
| `commit` | Append an event and optionally git-commit KB files |
| `show` | Return the content of a KB doc by slug |
| `list` | List tasks (with optional filters) or docs by path prefix |
| `board` | Print the kanban view (by status or assignee) |
| `set` | Set a field on a task or doc |
| `create` | Create a task or doc |
| `ai semantic` | Fuzzy/semantic search across KB content |
| `checkout` | Materialize a doc into the edit workspace |
| `events` | Print the append-only events log |

Any verb not in this table must exit 0 — agent Session Start blocks must never hard-fail on an unknown verb.

---

## Migration notes

The file-based shim stores everything in `.kb/` relative to the git repo root. The real GitKB binary uses the same root convention by default. Documents seeded into `.kb/docs/` are addressable by the same slugs in both implementations — there is no migration of content required when switching.

`.kb/scratch/` and `.kb/claims/` are ephemeral and gitignored; they are not migrated.
