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
| `./preview.sh` | `docusaurus build` + `docusaurus serve` | **Pre-push check** — view the real deployed output | No | Yes |

Both assemble content the production way: they **clone** the source repos (committed state only), unless you
point them at a local checkout with `--local` (see below).

Both `dev.sh` and `preview.sh` serve at `http://localhost:3000`, but they are not the same:

- **`dev.sh`** runs the **dev server** with hot reload. It compiles in memory and is lenient — it does
  *not* enforce the production `onBrokenLinks: 'throw'` check. Best for writing/iterating.
- **`preview.sh`** produces the **real production build** (`build/`) and serves those static files — exactly
  what gets deployed. It runs the full pipeline, so it catches build-only failures (broken links, broken
  Mermaid, SSR issues) that the dev server tolerates. Use it to verify before pushing.

### Previewing a local checkout (`--local`)

Both scripts accept `--local <path>` (repeatable) and `--no-autodiscover`. `--local` serves a repo's docs from
a **local checkout** — the working tree, including **uncommitted** edits — instead of cloning it from GitHub;
everything else is still cloned/auto-discovered as usual, so the overridden repo's local copy wins. The
section name is the directory basename. A checkout whose `docs/` ships an `_order` manifest (the umbrella) is
placed at the site root; any other repo becomes its own nested section. `--no-autodiscover` skips GitHub org
auto-discovery, assembling only the umbrella plus any `--local` repos — but the umbrella is **still cloned from
GitHub** unless you also `--local` an umbrella checkout (only then is it fully GitHub-free). The dev server
watches the copied `docs/`, so re-run the script to pick up further edits.

```bash
./dev.sh --local ../jeap-spring-boot-starters         # full site, that section from your local working tree
./dev.sh --local ../a --local ../b                    # multiple local overrides at once
./dev.sh --local ../jeap-admin-ch --no-autodiscover   # umbrella-only, umbrella from local (fully offline)
./preview.sh --local ../jeap-spring-boot-starters     # same, with the production broken-link check
```

## Blog

The site includes a Docusaurus blog at `/blog`, backed by Markdown files in `blog/` (unlike `docs/`, this
directory **is** committed to this repo).

To add a post, create a new `blog/YYYY-MM-DD-slug.md` file with front matter, e.g.:

```md
---
slug: my-post-slug
title: My Post Title
authors: [jeap-team]
tags: [announcement]
---

Short teaser shown on the blog list page.

<!-- truncate -->

Full post content below the fold.
---
```

* `authors` references an entry in `blog/authors.yml`; `tags` references entries in `blog/tags.yml` -
  add new authors/tags there as needed.
* `slug` is required (not just derived from the filename) and should remain stable once published.
* RSS and Atom feeds are generated automatically (`blog/rss.xml`, `blog/atom.xml`) and linked from the
  blog sidebar and the site footer under "Blog".

### Publishing release announcements automatically

Release blog posts for jEAP repositories are not written by hand. For repositories set up to do so (e.g.
`jeap-spring-boot-parent`), a GitHub Actions workflow (`publish-public-blogpost.yml` in that repository)
runs on every push to `main` and, based on the latest `CHANGELOG.md` entry, commits a new post directly to
this repository's `blog/` directory - the run is a no-op if a post for that version already exists.

## Tests

`npm test` runs both suites; CI runs it before every build (deploy and PR preview alike).

| Command | What it covers |
|---|---|
| `npm run test:components` | React components — Vitest + Testing Library, `src/**/*.test.{js,jsx}` |
| `npm run test:scripts` | The docs pipeline — `tests/scripts/*.test.sh`, plain bash, no extra dependencies |

The script tests exist because the pipeline is built out of regex rewrite rules that are easy to break by
accident and impossible to verify from the site build alone: a wrong rule surfaces as a broken link in some
unrelated repository's section, days later. They drive the **real** scripts against fixture doc trees in a
temporary directory and assert both directions — the shapes that must be rewritten *and* the near-misses that
must survive untouched (an over-eager rule is the failure mode that reaches production silently). Nothing is
re-implemented in the tests, so a test can only pass if the script itself behaves as asserted.

They need no network and no `gh` CLI: `clone-docs.sh` is pointed at throwaway local git repositories via
`REPO_BASE_URL="file://…"` with `AUTODISCOVER=false`, and the site's own `docs/` is never touched.

```bash
npm run test:scripts                  # all suites
bash tests/scripts/run.sh prepare     # only suites whose name matches "prepare"
```

Add a test alongside any change to the rewrite rules in `scripts/prepare-docs.sh` — that is where the
breakage risk is concentrated.

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
├── blog/                          # Blog posts (committed; see "Blog" section above)
├── src/
│   ├── css/custom.css             # Custom theme styles
│   ├── pages/                     # Custom React pages (home page)
│   └── theme/Mermaid/             # Swizzle-wrapped Mermaid: fullscreen lightbox with zoom/pan
├── static/                        # Static assets (images, favicon)
├── tests/
│   ├── scripts/                   # Bash tests for the docs pipeline scripts (npm run test:scripts)
│   └── setup.js, stubs/           # Vitest setup and stubs (component tests live next to the component)
├── dev.sh                         # Aggregate (clone / --local) + dev server (hot reload)
├── preview.sh                     # Aggregate (clone / --local) + production build + serve
├── docusaurus.config.js           # Docusaurus configuration
├── sidebars.js                    # Sidebar navigation (autogenerated from docs/)
├── vitest.config.mjs              # Component test runner config (npm run test:components)
└── package.json                   # Node.js dependencies and scripts
```
