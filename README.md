# jeap-admin-ch.github.io

Documentation site for the **jEAP** (Java Enterprise Application Platform) project, built with
[Docusaurus](https://docusaurus.io/) and published to GitHub Pages at
[jeap-admin-ch.github.io](https://jeap-admin-ch.github.io).

## How the documentation is assembled

This repository holds the **site** (Docusaurus config, theme, homepage) but **not** the documentation
content. The Markdown under `docs/` is **generated at build time** by aggregating the `docs/` directories
of the jEAP source repositories. `docs/` is therefore git-ignored — do not edit or commit it by hand.

Aggregation is a two-step pipeline (kept as two scripts so each step can run independently):

| Script | Purpose |
|---|---|
| `scripts/clone-docs.sh` | **Clone** the jEAP repos and copy their `docs/` into this repo's `docs/`. Two sources: the static `REPOS` manifest (the umbrella's general doc at the top level) and **auto-discovery** — enumerating the GitHub org and pulling in every repo that ships a top-level `docs/` dir as its own section under `docs/<repo>/`, with the repo's `README.md` as the landing page. Raw content only. |
| `scripts/prepare-docs.sh` | **Transform** the assembled `docs/` for the site: inject sidebar ordering (including pinning a `getting-started` page first within its section), write category metadata, and rewrite links that are valid on GitHub but would break in Docusaurus. Operates in place, so it can also run on a `docs/` tree you copied in manually (skipping the clone step). |

Both are configurable via environment variables — see the header comment in each script. `clone-docs.sh`
reads `REPO_BASE_URL`, `BRANCH`, `REPOS`, `DOCS_DEST`, plus the auto-discovery settings `ORG`,
`AUTODISCOVER` (`true`/`false`) and `EXCLUDE_REPOS` (repos to hold back). Auto-discovery uses the
[`gh` CLI](https://cli.github.com/) and must be authenticated (in CI, `GH_TOKEN`); set `AUTODISCOVER=false`
to run umbrella-only without `gh`. For example, to assemble from a local checkout on a feature branch
(offline, no org enumeration):

```bash
REPO_BASE_URL="file:///path/to/parentdir" BRANCH="feature/XYZ" REPOS="jeap-admin-ch:root" AUTODISCOVER=false \
  bash scripts/clone-docs.sh
bash scripts/prepare-docs.sh
```

## Prerequisites

- [Node.js](https://nodejs.org/) >= 18 (CI uses Node 22; locally, e.g. `nvm use 22`)

## Local scripts

All three convenience scripts install dependencies and run the aggregation pipeline first; they differ in
**what they do afterwards**:

| Script | Docusaurus mode | Use when | Hot reload | Production build |
|---|---|---|---|---|
| `./dev.sh` | `docusaurus start` (dev server) | **Authoring** — fast feedback while editing | Yes | No |
| `./dev-local.sh` | `docusaurus start` (dev server) | **Local preview** — view your *uncommitted* jeap-admin-ch docs without committing | Yes | No |
| `./preview.sh` | `docusaurus build` + `docusaurus serve` | **Pre-push check** — view the real deployed output | No | Yes |

`dev.sh` and `preview.sh` assemble content the production way: they **clone** the source repos
(committed state only). `dev-local.sh` is the exception — see below.

Both `dev.sh` and `preview.sh` serve at `http://localhost:3000`, but they are not the same:

- **`dev.sh`** runs the **dev server** with hot reload. It compiles in memory and is lenient — it does
  *not* enforce the production `onBrokenLinks: 'throw'` check. Best for writing/iterating.
- **`preview.sh`** produces the **real production build** (`build/`) and serves those static files — exactly
  what gets deployed. It runs the full pipeline, so it catches build-only failures (broken links, broken
  Mermaid, SSR issues) that the dev server tolerates. Use it to verify before pushing.
- **`dev-local.sh`** skips the clone entirely and copies the **working-tree** `docs/` from a local
  jeap-admin-ch checkout (default `../jeap-admin-ch`, override with an argument or `JEAP_ADMIN_CH_DIR`),
  runs the same preparation, then starts the dev server. Use it to preview docs you are editing **without
  committing them first** (a normal clone only sees committed content). The dev server watches the copied
  `docs/`, so re-run the script to pick up further edits in the source.

  ```bash
  ./dev-local.sh                      # uses ../jeap-admin-ch
  ./dev-local.sh /path/to/jeap-admin-ch
  ```

## Deployment

The site is automatically built and deployed to GitHub Pages on every push to `main` via the GitHub Actions
workflow at `.github/workflows/deploy.yml`.

The workflow:
1. Checks out the repository
2. Installs Node.js dependencies (`npm ci`)
3. **Clones** the jEAP documentation sources (`scripts/clone-docs.sh`, run with `GH_TOKEN` so auto-discovery can enumerate the org via `gh`)
4. **Prepares** the aggregated docs for GitHub Pages (`scripts/prepare-docs.sh`)
5. Builds the Docusaurus site (`npm run build`)
6. Deploys the `build/` output to GitHub Pages

## Project structure

```
├── .github/workflows/deploy.yml   # GitHub Pages deployment workflow
├── scripts/
│   ├── clone-docs.sh              # Step 1: clone source repos, assemble docs/
│   └── prepare-docs.sh            # Step 2: transform docs/ for the site
├── docs/                          # Documentation from jEAP repositories (git-ignored; do not edit)
├── src/
│   ├── css/custom.css             # Custom theme styles
│   └── pages/                     # Custom React pages (home page)
├── static/                        # Static assets (images, favicon)
├── dev.sh                         # Aggregate (clone) + dev server (hot reload)
├── dev-local.sh                   # Use local working-tree docs (no clone) + dev server
├── preview.sh                     # Aggregate (clone) + production build + serve
├── docusaurus.config.js           # Docusaurus configuration
├── sidebars.js                    # Sidebar navigation (autogenerated from docs/)
└── package.json                   # Node.js dependencies and scripts
```
