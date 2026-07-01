#!/usr/bin/env bash
#
# preview.sh — Aggregate the jEAP docs and run a PRODUCTION build + serve.
#
# Closest to the deployed result: enforces onBrokenLinks: 'throw', so it fails
# on any broken internal link (the dev server does not). Run this before pushing.
#
# Flags (same as dev.sh):
#   --local <path>   Serve a repo's docs from a LOCAL checkout (working tree,
#                    uncommitted edits included) instead of cloning it from
#                    GitHub. Repeatable. The section name is the directory
#                    basename; the umbrella checkout (its docs/ ships an _order
#                    manifest) is placed at the site root, any other repo as its
#                    own nested section.
#   --no-autodiscover  Skip GitHub org auto-discovery (AUTODISCOVER=false); the
#                    umbrella still comes from GitHub unless a --local umbrella
#                    checkout is also given.
#
# Examples:
#   ./preview.sh                                       # full site, all repos from GitHub
#   ./preview.sh --local ../jeap-spring-boot-starters  # broken-link check for local docs
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOCAL_REPOS=""
AUTODISCOVER="${AUTODISCOVER:-true}"

usage() {
  cat <<'EOF'
Usage: ./preview.sh [--local <path>]... [--no-autodiscover]

Aggregate the jEAP docs, run a PRODUCTION build, and serve it at
http://localhost:3000 — closest to the deployed result. Enforces
onBrokenLinks: 'throw', so it fails on any broken internal link. Run before
pushing. With no flags it clones/auto-discovers every repo from GitHub.

Options:
  --local <path>     Serve a repo's docs from a LOCAL checkout (working tree,
                     uncommitted edits included) instead of cloning it from
                     GitHub. Repeatable. Section name = directory basename; the
                     umbrella checkout (its docs/ ships an _order manifest) lands
                     at the site root, any other repo as its own nested section.
                     Everything else is still cloned/auto-discovered from GitHub.
  --no-autodiscover  Skip GitHub org auto-discovery: assemble only the umbrella +
                     any --local repos. The umbrella still comes from GitHub
                     unless you also pass a --local umbrella checkout.
  -h, --help         Show this help and exit.

Examples:
  ./preview.sh                                       # full site, all repos from GitHub
  ./preview.sh --local ../jeap-spring-boot-starters  # broken-link check for local docs
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage; exit 0
      ;;
    --local)
      [ $# -ge 2 ] || { echo "ERROR: --local requires a path argument" >&2; exit 1; }
      path="$2"; shift 2
      [ -d "$path/docs" ] || { echo "ERROR: --local '$path' has no docs/ directory" >&2; exit 1; }
      path="$(cd "$path" && pwd)"  # normalise to an absolute path
      LOCAL_REPOS="${LOCAL_REPOS:+$LOCAL_REPOS }$path"
      ;;
    --no-autodiscover)
      AUTODISCOVER="false"; shift
      ;;
    *)
      echo "ERROR: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

echo "==> Installing dependencies..."
npm ci

echo "==> Aggregating documentation from jEAP repos..."
LOCAL_REPOS="$LOCAL_REPOS" AUTODISCOVER="$AUTODISCOVER" bash scripts/clone-docs.sh
bash scripts/prepare-docs.sh

echo "==> Building Docusaurus site..."
npm run build

echo "==> Serving site at http://localhost:3000 ..."
npm run serve
