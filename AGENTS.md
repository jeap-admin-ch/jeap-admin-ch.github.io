# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this repo is

The Docusaurus 3 **site** for the jEAP (Java Enterprise Application Platform) docs, deployed to GitHub Pages at `jeap-admin-ch.github.io`. It holds the site shell (config, theme, homepage) — **not** the documentation content. The content under `docs/` is aggregated from external jEAP source repositories at build time.

## Commands

```bash
./dev.sh         # Install deps + clone docs from repos + dev server (localhost:3000, hot reload)
./preview.sh     # Install deps + clone docs + production build (build/) + serve — closest to deployed result, fails on broken links
```

Raw npm scripts (`npm start` / `npm run build` / `npm run serve`) assume deps are installed and `docs/` is already assembled — the shell scripts above wrap aggregation + Docusaurus together. There are **no tests or linters** in this project.

Both `dev.sh` and `preview.sh` accept `--local <path>` (repeatable) and `--no-autodiscover`:

```bash
./dev.sh --local ../jeap-spring-boot-starters              # full site, that section served from your LOCAL working tree
./dev.sh --local ../jeap-admin-ch --no-autodiscover        # umbrella-only, umbrella served from local (offline)
```

`--local <path>` serves a repo's docs from a **local checkout** (working tree, uncommitted edits included) instead of cloning it from GitHub; everything else is still cloned/auto-discovered as usual, so the overridden repo's local copy wins. The section name is the directory basename; a checkout whose `docs/` ships an `_order` manifest (the umbrella) is placed at the site root, any other repo as its own nested section. `--no-autodiscover` skips GitHub org auto-discovery, assembling only the umbrella plus any `--local` repos — but the umbrella is **still cloned from GitHub** unless you also pass a `--local` umbrella checkout (then it's fully GitHub-free). Re-run to pick up further edits.

## The docs aggregation pipeline (the core mechanic)

`docs/` is **generated and git-ignored** — never edit or commit files there; they are wiped and reassembled on every build. Two scripts run in sequence (split so each can run independently):

1. `scripts/clone-docs.sh` — assembles `docs/` from two sources:
   - **The static `REPOS` manifest** — clones the configured repos (depth-1, branch tip) and copies their `docs/` trees in. `root` placement copies to the top level; `nested` copies to `docs/<repo>/`. Default manifest is `jeap:root` (the umbrella repo's general doc).
   - **Auto-discovery** (on by default) — enumerates the GitHub org via the `gh` CLI and pulls in **every repo that ships a top-level `docs/` dir on `main`** as its own nested section (`docs/<repo>/`), using the repo's `README.md` as the section landing page (`index.md`). A repo that also ships its own `docs/index.md` has it demoted to `modules.md` to avoid colliding with the README-derived index. Auto-discovered repos are always cloned from `main`, regardless of `BRANCH`.

   Env vars: `REPO_BASE_URL`, `BRANCH` (static manifest only), `REPOS`, `DOCS_DEST`, `ORG` (org to enumerate), `AUTODISCOVER` (`true`/`false`), `EXCLUDE_REPOS` (space-separated hold-back list, default `jeap-governance-service jeap-python-pipeline-lib`), `LOCAL_REPOS` (space-separated paths to local repo checkouts assembled from their working tree instead of cloned; the same-named repo is skipped during auto-discovery so the local copy wins — this is what backs the `--local` flag). Auto-discovery requires the `gh` CLI installed and authenticated (in CI, `GH_TOKEN`); with `AUTODISCOVER=false` it runs umbrella-only and needs no `gh`.
2. `scripts/prepare-docs.sh` — transforms the assembled tree **in place** (idempotent): applies the umbrella's order manifest (`docs/_order`) to position top-level curated content — listed files get `sidebar_position`, listed folders a labelled `_category_.json` (whose `index.md` is the section landing page via the category index convention); auto-discovered repo sections sort after at position 100+; a `getting-started` page (file or folder) is pinned first *within its section* tree-wide (`sidebar_position: 0`, forced over source front matter), so every documented repo that ships one shows it as its first sidebar entry; and it rewrites links valid on GitHub but broken in Docusaurus (`../README.md` → umbrella repo README; absolute site URLs → site-internal; links to source-repo files that have no published doc page — escaping `docs/` via `..`, README links to files/dirs outside `docs/`, non-doc assets — → the file on GitHub, base `REPO_WEB_BASE_URL`). The sidebar order thus lives **with the content in the umbrella repo** — add a section there by adding a line to `_order`, no change here. Because it operates in place, it can also run on a `docs/` tree copied in manually (skipping the clone).

   `docs/_order` format (shipped by the umbrella, one entry per line in display order; `#` comments and blanks ignored):
   ```
   what-is-jeap
   using-jeap
   building-blocks | Building Blocks
   ```
   Each entry names a top-level file or folder; its line number is the sidebar position. `| Label` (optional) sets a folder's category label. A file that already ships its own front matter wins over the manifest. Without `_order`, top-level entries fall back to Docusaurus' alphabetical order.

To assemble from a local checkout on a feature branch (`AUTODISCOVER=false` keeps it offline — otherwise it would enumerate the real GitHub org via `gh`):
```bash
REPO_BASE_URL="file:///path/to/parentdir" BRANCH="feature/XYZ" REPOS="jeap-admin-ch:root" AUTODISCOVER=false \
  bash scripts/clone-docs.sh
bash scripts/prepare-docs.sh
```

## Conventions that matter

- **`onBrokenLinks: 'throw'`** (docusaurus.config.js) — any broken internal link fails the production build. The dev server (`dev.sh`) does *not* enforce this, so verify with `preview.sh` before pushing.
- **Sidebar is autogenerated** from the `docs/` directory tree (`sidebars.js` uses `type: 'autogenerated'`). Ordering comes from `sidebar_position` front matter and `_category_.json` — injected by `prepare-docs.sh`, not edited manually. To change ordering, edit `prepare-docs.sh`, not `sidebars.js`.
- **Mermaid** is enabled (`@docusaurus/theme-mermaid`) — ` ```mermaid ` blocks render.
- Site config (navbar, footer, i18n) lives in `docusaurus.config.js`; theme color overrides in `src/css/custom.css`; the homepage is a custom React page in `src/pages/index.js`.
- CI uses Node 22 (`.nvmrc`); local requires Node >= 18.

## Deployment

Push to `main` → `.github/workflows/deploy.yml` runs the full pipeline (npm ci → clone-docs → prepare-docs → build → deploy to GitHub Pages). The clone step runs with `GH_TOKEN: ${{ github.token }}` so its auto-discovery can enumerate the org via `gh`. PRs get a preview via `pr-preview.yml` (torn down by `pr-preview-teardown.yml`).

See `README.md` for the full rationale and script env-var reference.
