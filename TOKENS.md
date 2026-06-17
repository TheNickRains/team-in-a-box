# TOKENS.md — Generification Token Manifest

Contract for `setup.sh` (the next extraction slice). Every `{{TOKEN}}` placed in this pass,
its meaning, exact locations, and a sensible default setup.sh should offer interactively.

---

## Token Table

| Token | Meaning | Default (setup.sh prompt) |
|---|---|---|
| `{{PROJECT_NAME}}` | The product/project name — replaces the origin project name everywhere it appears | `MyProject` |
| `{{HUMAN_NAME}}` | The chair's name (human-in-the-loop) — replaces the human operator's name | `Human` |
| `{{STACK_DESCRIPTION}}` | One-sentence tech stack summary for CLAUDE.md Project Context | `Next.js, TypeScript, pnpm, Supabase` |
| `{{DEPLOY_INSTRUCTIONS}}` | Deployment instructions / command(s) for CLAUDE.md and README.md | `pnpm run deploy` |
| `{{DEPLOY_DOMAIN}}` | Self-hosting domain for fullstack.md | `localhost` |
| `{{KB_PRODUCT_THESIS_SLUG}}` | GitKB slug for the product thesis / "what this product is and why" | `context/immutable/product-thesis` |
| `{{KB_SCHEMA_SLUG}}` | GitKB slug for the data model / schema | `context/immutable/schema` |
| `{{KB_STAGES_SLUG}}` | GitKB slug for product stages / current build target | `context/extensible/product-stages` |
| `{{KB_SPRINT_OVERVIEW_SLUG}}` | GitKB slug for current sprint overview | `context/extensible/sprint/overview` |
| `{{KB_HUMAN_TODO_SLUG}}` | GitKB slug for the human chair's to-do list | `context/extensible/human-todo` |
| `{{KB_CHARTER_EVAL_SLUG}}` | GitKB slug for the Barnum eval / charter derivation methodology | `context/extensible/charter-eval` |
| `{{DOMAIN_DESCRIPTION}}` | One-phrase description of the scientist's domain (algorithm / ML domain) | `algorithm, signal extraction, cohort matching, evaluation` |
| `{{ALGORITHM_CODE_PATHS}}` | Comma-separated code paths scientist owns | `lib/compute-<project>, scripts/enrich.py` |
| `{{INFRA_EPIC_NAME}}` | Name of the infrastructure/plumbing epic fullstack owns | `epic-infra` |
| `{{LANDING_EPIC_NAME}}` | Name of the landing/UI epic designer owns | `epic-landing` |
| `{{PRIMARY_EPIC_PAIR}}` | Name of the algorithm/domain epic shared by architect and scientist | `epic-algorithm` |
| `{{THEME_TOKEN_NAMESPACE}}` | CSS custom property namespace for design tokens | `--app-*` |
| `{{DESIGN_REFERENCE_PATH}}` | Path to design reference material | `Reference/design-brief/` |
| `{{FRAMEWORK_DOCS_PATH}}` | Path to framework documentation inside node_modules or equivalent | `node_modules/next/dist/docs/` |
| `{{ENV_VAR_LIST}}` | Markdown bullet list of required environment variables with descriptions | *(see .env.example — fill after cloning)* |
| `{{PROTECTED_CODE_PATHS}}` | Colon-separated paths chair-guard.sh treats as write-protected (manifest note only — hook not edited) | `app:lib:components` |

---

## Token Locations (exact files + occurrences)

### `{{PROJECT_NAME}}`
- `CLAUDE.md` line 5 — H1 title
- `AGENTS.md` line 1 — H1 title
- `COORDINATION.md` line 1 — H1 title
- `README.md` line 1 — H1 title, line 3 — description sentence
- `.claude/agents/architect.md` — H1 title
- `.claude/agents/designer.md` — H1 title
- `.claude/agents/fullstack.md` — H1 title
- `.claude/agents/general.md` — H1 title
- `.claude/agents/naieve-copywriter.md` — H1 title
- `.claude/agents/recorder.md` — H1 title
- `.claude/agents/scientist.md` — H1 title
- `.claude/agents/scrum-master.md` — H1 title
- `.claude/agents/senior-engineer.md` — H1 title
- `.claude/agents/strategist.md` — H1 title
- `.claude/agents/technical-copywriter.md` — H1 title
- `.claude/agents/ux.md` — H1 title

### `{{HUMAN_NAME}}`
- `AGENTS.md` — Hub and Spoke paragraph, Boardroom Ideology paragraph
- `.claude/commands/boardroom.md` — Round 1 spawn prompt (Chair line, ×3 — all occurrences replaced), synthesis block (Chair line)
- `.claude/commands/defer.md` — stash file format (Chair line)
- `.claude/commands/resume-boardroom.md` — re-spawn prompt (Chair line)
- `.claude/commands/me.md` — `git kb show` command, heading match
- `CHARTER.template.md` — H1 title
- `AGENTS.md` — scientist roster description (inside `{{DOMAIN_DESCRIPTION}}` token; indirect)

### `{{STACK_DESCRIPTION}}`
- `CLAUDE.md` — Project Context, Stack paragraph

### `{{DEPLOY_INSTRUCTIONS}}`
- `CLAUDE.md` — Project Context, Deployment paragraph
- `README.md` — Scripts table row for deploy command, deploy convention note

### `{{DEPLOY_DOMAIN}}`
- `.claude/agents/fullstack.md` — "What you own" bullet (self-hosting line)

### `{{KB_PRODUCT_THESIS_SLUG}}`
- `CLAUDE.md` — knowledge base boot block, first `git kb show` line

### `{{KB_SCHEMA_SLUG}}`
- `CLAUDE.md` — knowledge base boot block, second `git kb show` line
- `.claude/agents/architect.md` — lazy reads block
- `.claude/agents/scientist.md` — lazy reads block

### `{{KB_STAGES_SLUG}}`
- `CLAUDE.md` — knowledge base boot block, third `git kb show` line

### `{{KB_SPRINT_OVERVIEW_SLUG}}`
- `.claude/commands/boardroom.md` — Phase 0 recorder context brief fetch list
- `.claude/commands/kanban.md` — parallel Bash block, sprint header line
- `.claude/commands/standup.md` — parallel Bash block, sprint header line

### `{{KB_HUMAN_TODO_SLUG}}`
- `.claude/commands/me.md` — `git kb show` command

### `{{KB_CHARTER_EVAL_SLUG}}`
- `CHARTER.template.md` — footer line

### `{{DOMAIN_DESCRIPTION}}`
- `AGENTS.md` — scientist roster description line
- `.claude/agents/scientist.md` — frontmatter description field, "What you own" heading bullet

### `{{ALGORITHM_CODE_PATHS}}`
- `.claude/agents/scientist.md` — "What you own" signal-extraction bullet

### `{{INFRA_EPIC_NAME}}`
- `.claude/agents/fullstack.md` — "What you own" epic owner bullet

### `{{LANDING_EPIC_NAME}}`
- `.claude/agents/designer.md` — "What you own" epic owner bullet

### `{{PRIMARY_EPIC_PAIR}}`
- `.claude/agents/architect.md` — frontmatter description, "What you own" joint-ownership bullet
- `.claude/agents/scientist.md` — frontmatter description, "What you own" joint-ownership bullet

### `{{THEME_TOKEN_NAMESPACE}}`
- `.claude/agents/designer.md` — "What you own" theme tokens bullet

### `{{DESIGN_REFERENCE_PATH}}`
- `.claude/agents/designer.md` — Hard rules, reference material bullet

### `{{FRAMEWORK_DOCS_PATH}}`
- `.claude/agents/fullstack.md` — Hard rules, Next.js docs bullet
- `.claude/agents/senior-engineer.md` — Hard rules, Next.js docs bullet
- `.claude/agents/general.md` — Hard rules, Next.js docs bullet

### `{{ENV_VAR_LIST}}`
- `README.md` — Environment variables section body

### `{{PROTECTED_CODE_PATHS}}` (manifest-only — chair-guard.sh not edited)
- **Not placed in any file.** Record here for setup.sh to wire via env injection into `.claude/hooks/chair-guard.sh` `CHAIR_PROTECTED_PATHS` default. Runtime slice owns the hook edit.

---

## Judgment Calls (deviations from audit verdicts)

1. **kanban.md and standup.md hardcoded sprint dates/names** — audit covered `{{KB_SPRINT_OVERVIEW_SLUG}}` for the `git kb show` call but didn't explicitly cover hardcoded sprint name/date strings in the formatted output block. Verdict: deleted both origin-project-specific values; replaced with a generic instruction to read the sprint overview slug.

2. **scrum-master.md and ux.md header** — audit specified `"for {{PROJECT_NAME}}"` on the 12 agent headers. scrum-master.md and ux.md had different header patterns (`# ScrumMaster — Living Kanban`, `# UX — User Experience Engineer`). Applied consistent treatment: prepended "for {{PROJECT_NAME}}" into the header to make them structurally parallel.

3. **AGENTS.md scientist roster line** — audit specified `{{DOMAIN_DESCRIPTION}}` for scientist.md:3 and :14. The roster entry in AGENTS.md also contained the origin project's domain description — same content. Replaced with `{{DOMAIN_DESCRIPTION}}` there too, consistent with the audit's intent.

4. **naieve-copywriter.md reading-level cap jargon list** — audit said "replace with generic examples or remove." Chose to remove the parenthetical list entirely and replace with a generic instruction ("Replace any jargon word the reader didn't bring to the page"), which preserves the rule's intent without any product-specific vocabulary.

5. **general.md domain-specific "source of truth" rule** — the audit listed this line under scientist.md, senior-engineer.md, and strategist.md but not general.md explicitly. general.md line 40 contains the identical rule. Applied the same DELETE + commented stub treatment for consistency.

6. **CHARTER.template.md Tensions scaffold** — audit said keep the CONSTANT structural sections and an empty Validation log. The Tensions section in the original has 6 numbered items with the origin user's specific content. Template preserves 6 numbered `[PRIOR]` stubs (matching the /charter command's output format) so the `/charter` run can fill them without having to add structure.

7. **designer.md origin-project design direction** — the audit verdict was DELETE. Removed only the origin-project-specific phrase from the first hard rule; the surrounding generic texture/grain/motion principle was kept. Added `# add your domain's hard rules here` stub at the end of the Hard rules block.

8. **README.md deploy section** — the deploy row in the Scripts table and the deploy convention paragraph both referenced origin-project-specific deploy instructions. Replaced both with `{{DEPLOY_INSTRUCTIONS}}` token.
