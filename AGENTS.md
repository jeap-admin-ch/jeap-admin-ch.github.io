# Copilot Instructions

## Project Overview

This is the **jEAP** (Java Enterprise Application Platform) documentation site, built with [Docusaurus 3](https://docusaurus.io/) and deployed to GitHub Pages.

## Build & Development Commands

```bash
./dev.sh       # Install deps + start dev server with hot reload (localhost:3000)
./build.sh     # Install deps + production build (output in build/)
./preview.sh   # Install deps + build + serve locally
```

Underlying npm scripts (use after `npm ci`):

```bash
npm start      # Dev server
npm run build  # Production build (fails on broken links)
```

There are no tests or linters configured in this project.

## Architecture

- **docs/** — Documentation pages as Markdown files. Each file uses [Docusaurus frontmatter](https://docusaurus.io/docs/api/plugins/@docusaurus/plugin-content-docs#markdown-front-matter) (e.g., `sidebar_position`).
- **src/pages/** — Custom React pages (the homepage). Uses JSX with Docusaurus theme components.
- **src/css/custom.css** — Theme color overrides using Docusaurus CSS variables (`--ifm-*`).
- **sidebars.js** — Manually configured sidebar navigation. New docs must be added here to appear in the sidebar.
- **docusaurus.config.js** — Site-wide configuration (navbar, footer, i18n, presets).
- **static/** — Static assets served at the site root (images, favicon).

## Key Conventions

- **Broken links fail the build** — `onBrokenLinks: 'throw'` in docusaurus.config.js means any broken internal link will cause `npm run build` to fail. Always verify links when adding or renaming pages.
- **Sidebar is manual** — Adding a new doc file requires a corresponding entry in `sidebars.js`.
- **Node.js 22** — CI uses Node 22.21.1. Local development requires Node >= 18.
- **No external contributions** — This is an open-source project (Apache 2.0) that does not accept external PRs per CONTRIBUTING.md.

## Deployment

Pushes to `main` trigger automatic deployment via `.github/workflows/deploy.yml`. PRs run the build job for validation but do not deploy.
