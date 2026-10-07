# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this repo is

The Docusaurus 3 **site** for the jEAP (Java Enterprise Application Platform) docs, deployed to GitHub Pages at `jeap-admin-ch.github.io`. It holds the site shell (config, theme, homepage) — **not** the documentation content. The content under `docs/` is aggregated from external jEAP source repositories at build time.

## Commands

```bash
./dev.sh         # Install deps + clone docs from repos + dev server (localhost:3000, hot reload)
./preview.sh     # Install deps + clone docs + production build (build/) + serve — closest to deployed result, fails on broken links
```

Raw npm scripts (`npm start` / `npm run build` / `npm run serve`) assume deps are installed and `docs/` is already assembled — the shell scripts above wrap aggregation + Docusaurus together. There are **no linters** in this project.

`npm test` runs both test suites and is what CI runs before every build:

| Command | What it covers |
|---|---|
| `npm run test:components` | React components (Vitest + Testing Library, `src/**/*.test.{js,jsx}`, config in `vitest.config.mjs`) |
| `npm run test:scripts` | The docs pipeline scripts (`tests/scripts/*.test.sh`, plain bash — no extra deps) |

The script tests drive the **real** `scripts/*.sh` against fixture trees in a temp directory (`clone-docs.sh` is pointed at throwaway local git repos via `REPO_BASE_URL="file://…"` with `AUTODISCOVER=false`, so nothing hits the network or needs `gh`). The rewrite rules are never re-implemented in the tests, so a test can only pass if the script itself behaves as asserted. Run one suite with `bash tests/scripts/run.sh prepare`. **Change a rewrite rule in `prepare-docs.sh` and you must update or extend `tests/scripts/prepare-docs-links.test.sh`** — those regexes are the pipeline's most breakage-prone part, and a wrong rule surfaces only as a broken link in some unrelated repo's section days later. The same applies to `check-diagram-sources.sh` and `tests/scripts/check-diagram-sources.test.sh`, whose git cases build real repositories with real commits — a date check is the kind of thing that keeps passing after it stops working.

Both `dev.sh` and `preview.sh` accept `--local <path>` (repeatable) and `--no-autodiscover`:

```bash
./dev.sh --local ../jeap-spring-boot-starters              # full site, that section served from your LOCAL working tree
./dev.sh --local ../jeap-admin-ch --no-autodiscover        # umbrella-only, umbrella served from local (offline)
```

`--local <path>` serves a repo's docs from a **local checkout** (working tree, uncommitted edits included) instead of cloning it from GitHub; everything else is still cloned/auto-discovered as usual, so the overridden repo's local copy wins. The section name is the directory basename; a checkout of the repo that the `REPOS` manifest places at the root (the umbrella, recognized by its git remote "origin", or by its directory name when it has none) is placed at the site root, any other repo as its own nested section. `--no-autodiscover` skips GitHub org auto-discovery, assembling only the umbrella plus any `--local` repos — but the umbrella is **still cloned from GitHub** unless you also pass a `--local` umbrella checkout (then it's fully GitHub-free). Re-run to pick up further edits.

## The docs aggregation pipeline (the core mechanic)

`docs/` is **generated and git-ignored** — never edit or commit files there; they are wiped and reassembled on every build. Two scripts run in sequence (split so each can run independently), with a third called by the first:

1. `scripts/clone-docs.sh` — assembles `docs/` from two sources:
   - **The static `REPOS` manifest** — clones the configured repos (depth-1, branch tip) and copies their `docs/` trees in. `root` placement copies to the top level; `nested` copies to `docs/<repo>/`. Default manifest is `jeap:root` (the umbrella repo's general doc).
   - **Auto-discovery** (on by default) — enumerates the GitHub org via the `gh` CLI and pulls in **every repo that ships a top-level `docs/` dir on `main`** as its own nested section (`docs/<repo>/`), using the repo's `README.md` as the section landing page (`index.md`). A repo that also ships its own `docs/index.md` has it demoted to `modules.md` to avoid colliding with the README-derived index. Auto-discovered repos are always cloned from `main`, regardless of `BRANCH`.

   Env vars: `REPO_BASE_URL`, `BRANCH` (static manifest only), `REPOS`, `DOCS_DEST`, `ORG` (org to enumerate), `AUTODISCOVER` (`true`/`false`), `EXCLUDE_REPOS` (space-separated hold-back list, default empty — none held back), `LOCAL_REPOS` (space-separated paths to local repo checkouts assembled from their working tree instead of cloned; the same-named repo is skipped during auto-discovery so the local copy wins — this is what backs the `--local` flag). Auto-discovery requires the `gh` CLI installed and authenticated (in CI, `GH_TOKEN`); with `AUTODISCOVER=false` it runs umbrella-only and needs no `gh`.
2. `scripts/prepare-docs.sh` — transforms the assembled tree **in place** (idempotent): applies the umbrella's order manifest (`docs/_order`) to position top-level curated content — listed files get `sidebar_position`, listed folders a labelled `_category_.json` (whose `index.md` is the section landing page via the category index convention); auto-discovered repo sections sort after at position 100+; a `getting-started` page (file or folder) is pinned first *within its section* tree-wide (`sidebar_position: 0`, forced over source front matter), so every documented repo that ships one shows it as its first sidebar entry; and it rewrites links valid on GitHub but broken in Docusaurus (`../README.md` → umbrella repo README; absolute site URLs → site-internal; links to source-repo files that have no published doc page — escaping `docs/` via `..`, README links to files/dirs outside `docs/`, non-doc assets — → the file on GitHub, base `REPO_WEB_BASE_URL`). The sidebar order thus lives **with the content in the umbrella repo** — add a section there by adding a line to `_order`, no change here. Because it operates in place, it can also run on a `docs/` tree copied in manually (skipping the clone).

   `docs/_order` format (shipped by the umbrella, one entry per line in display order; `#` comments and blanks ignored):
   ```
   what-is-jeap
   using-jeap
   building-blocks | Building Blocks
   ```
   Each entry names a top-level file or folder; its line number is the sidebar position. `| Label` (optional) sets a folder's category label. A file that already ships its own front matter wins over the manifest. Without `_order`, top-level entries fall back to Docusaurus' alphabetical order. The same manifest works in any **nested** folder: a folder that ships its own `_order` (a topic folder in the umbrella, or any folder of a repo's `docs/`, its root included) orders its direct children the same way; entries must name a direct child (no paths), nested categories start collapsed, and a folder entry without `| Label` gets no label so Docusaurus uses its `index.md` title. Nested manifests are applied after the repo sections are routed, and a `getting-started` pin still wins over them.

3. `scripts/check-diagram-sources.sh` — called by `clone-docs.sh` for every repo it clones, and usable on its own (`sources`, `pairs`, `prune`, `check [--deepen] <repo> [<subdir>]`). A jEAP diagram is **two committed files in one folder**: the editable source (`images/x.drawio`) and the image exported from it by hand (`images/x.svg`). A file counts as a source when its name extends an image's stem (`<image-stem>.<anything>`) **and** its own extension is not one the doc service publishes (`md png jpg jpeg gif webp avif svg pdf txt csv json yaml yml`) — so `x.drawio` and the older `x.drawio.xml` both pair up, while `report.pdf` next to `report.svg` does not. The rule is about the name rather than a list of diagram tools on purpose: hand-exported images were chosen precisely so the convention works for any editor.

   Two things it enforces: a **stale export fails the build** (the source was committed after its image — the author forgot to re-export, and the site would go on showing the old picture), and the **sources are pruned** from the assembled tree (an editor file cannot be opened in a browser). Pruning runs on the *destination*, so a `LOCAL_REPOS` working tree is never written to; the date check is skipped for `LOCAL_REPOS` entirely, since previewing uncommitted work is what that mode is for.

   `scripts/check-diagram-sources.sh` is **shared verbatim** with `jeap-microservice-pipeline`
   (`resources/ch/admin/bit/jeap/microservicepipeline/oss/check_diagram_sources.sh`), which runs it
   as an open-source precondition on the author's own build — the two pipelines gate the same
   convention and cannot depend on one another. `diff` between the two must be empty; change both in
   one go. The same rule has a third implementation in Python for the doc pipeline of the business
   applications (`jeap-python-pipeline-lib`, `src/jeap_pipeline/doc_diagram_sources.py`).

   A page type or browser code (`.mdx`, `.html`, `.js`, `.ts`, `.css`, ...) is **never** a diagram
   source, so a publishable MDX page beside an image is neither pruned nor dated against it. Every
   export format of one source is paired, so `flow.drawio` beside `flow.png` and `flow.svg` is
   checked against both.

   **Why commit dates and not mtimes**: git neither stores nor restores mtimes — a clone writes every file at checkout time, so in CI all mtimes are equal and their order is arbitrary. An mtime check would pass by luck. **Why `--deepen`**: in a depth-1 clone `git log -1 -- <path>` answers with the shallow boundary commit for everything older, which makes every pair look equally old and the check pass silently. So the checker detects a boundary-dated answer, deepens in rounds (64, 256, 1024, then `--unshallow`) until it has a real one, and **refuses to give a verdict** if it still does not. Repos are therefore still cloned at depth 1 and only a repo that actually ships a diagram ever fetches a second commit — which matters when the build clones ~70 of them.

To assemble from a local checkout on a feature branch (`AUTODISCOVER=false` keeps it offline — otherwise it would enumerate the real GitHub org via `gh`):
```bash
REPO_BASE_URL="file:///path/to/parentdir" BRANCH="feature/XYZ" REPOS="jeap-admin-ch:root" AUTODISCOVER=false \
  bash scripts/clone-docs.sh
bash scripts/prepare-docs.sh
```

## Conventions that matter

- **`onBrokenLinks: 'throw'`** (docusaurus.config.js) — any broken internal link fails the production build. The dev server (`dev.sh`) does *not* enforce this, so verify with `preview.sh` before pushing.
- **Sidebar is autogenerated** from the `docs/` directory tree (`sidebars.js` uses `type: 'autogenerated'`). Ordering comes from `sidebar_position` front matter and `_category_.json` — injected by `prepare-docs.sh`, not edited manually. To change ordering, edit `prepare-docs.sh`, not `sidebars.js`.
- **Mermaid** is enabled (`@docusaurus/theme-mermaid`) — ` ```mermaid ` blocks render. The theme component is swizzle-wrapped (`src/theme/Mermaid/`) to add a fullscreen lightbox with zoom/pan controls on every diagram.
- Site config (navbar, footer, i18n) lives in `docusaurus.config.js`; theme color overrides in `src/css/custom.css`; the homepage is a custom React page in `src/pages/index.js`.
- CI uses Node 22 (`.nvmrc`); local requires Node >= 18.

## Deployment

Push to `main` → `.github/workflows/deploy.yml` runs the full pipeline (npm ci → clone-docs → prepare-docs → build → deploy to GitHub Pages). The clone step runs with `GH_TOKEN: ${{ github.token }}` so its auto-discovery can enumerate the org via `gh`. PRs get a preview via `pr-preview.yml` (torn down by `pr-preview-teardown.yml`).

See `README.md` for the full rationale and script env-var reference.
