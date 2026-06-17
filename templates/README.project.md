# {{PROJECT_NAME}}

{{PROJECT_NAME}} — add a one-line description of what your project builds.

## Stack

| Layer | Version |
|---|---|
| Next.js | 16.2.4 |
| React | 19.2.4 |
| TypeScript | ^5 |
| pnpm | 10.15.1 (pinned in `packageManager`) |
| Supabase | @supabase/supabase-js ^2 |
| Cloudflare R2 | via @aws-sdk/client-s3 ^3 |
| Deploy platform | {{DEPLOY_INSTRUCTIONS}} |

> **Node version:** no `.nvmrc` or `engines` field is present in `package.json`. The repo currently runs on Node 23. This is an open gap — pin a version if you need reproducibility across machines.

## Setup

```bash
# 1. Clone
git clone <repo-url>
cd {{PROJECT_NAME}}

# 2. Install dependencies (pnpm only — do not use npm or yarn)
pnpm install

# 3. Configure environment
cp .env.example .env.local
# Open .env.local and fill in values — get them from the repo owner.

# 4. Start the dev server
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000).

## Scripts

| Command | What it does |
|---|---|
| `pnpm dev` | Next.js dev server with webpack (HMR on localhost:3000) |
| `pnpm build` | Production build (webpack) |
| `pnpm start` | Serve the production build locally |
| `pnpm lint` | Run ESLint |
| `pnpm run deploy` | {{DEPLOY_INSTRUCTIONS}} |

**Deploy convention:** see `{{DEPLOY_INSTRUCTIONS}}` — follow your project's deploy protocol exactly.

## Services

<!-- add your project's service descriptions here -->

## Environment variables

See `.env.example` for the full list with descriptions. Short summary:

{{ENV_VAR_LIST}}
