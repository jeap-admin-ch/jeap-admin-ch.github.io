# jeap-admin-ch.github.io

Documentation site for the **jEAP** (Java Enterprise Application Platform) project, published to GitHub Pages.

## Prerequisites

- [Node.js](https://nodejs.org/) >= 18

## Local Development

Run the dev server with hot reload (changes appear instantly without a full rebuild):

```bash
./dev.sh
```

The site will be available at `http://localhost:3000`.

## Build Locally

Run the build script to verify the site compiles correctly:

```bash
./build.sh
```

This installs dependencies and produces the static site in the `build/` directory.

## Preview Locally

Build the site and serve it locally in one step:

```bash
./preview.sh
```

This installs dependencies, builds the production site, and starts a local server at `http://localhost:3000`.

## Deployment

The site is automatically deployed to GitHub Pages on every push to `main` via the GitHub Actions workflow at `.github/workflows/deploy.yml`.

The workflow:
1. Checks out the repository
2. Installs Node.js dependencies
3. Builds the Docusaurus site
4. Deploys the `build/` output to GitHub Pages

## Project Structure

```
├── .github/workflows/deploy.yml   # GitHub Pages deployment workflow
├── docs/                          # Documentation pages (Markdown)
├── src/
│   ├── css/custom.css             # Custom theme styles
│   └── pages/                     # Custom React pages (home page)
├── static/                        # Static assets (images, favicon)
├── dev.sh                         # Dev server with hot reload
├── build.sh                       # Local build script
├── preview.sh                     # Build and serve locally
├── docusaurus.config.js           # Docusaurus configuration
├── sidebars.js                    # Sidebar navigation configuration
└── package.json                   # Node.js dependencies and scripts
```
