#!/usr/bin/env bash
#
# dev.sh — Aggregate the jEAP docs and run the Docusaurus dev server (hot reload).
#
# Flags:
#   --local <path>   Serve a repo's docs from a LOCAL checkout (working tree,
#                    uncommitted edits included) instead of cloning it from
#                    GitHub. Repeatable. The section name is the directory
#                    basename; the umbrella checkout (its docs/ ships an _order
#                    manifest) is placed at the site root, any other repo as its
#                    own nested section. Everything else is still cloned/auto-
#                    discovered from GitHub as usual.
#   --no-autodiscover  Skip GitHub org auto-discovery (AUTODISCOVER=false), so
#                    only the umbrella + any --local repos are assembled. NOTE:
#                    the umbrella is still cloned from GitHub unless you also pass
#                    a --local umbrella checkout — combine both for a fully
#                    GitHub-free preview of just the umbrella docs.
#
# Examples:
#   ./dev.sh                                        # full site, all repos from GitHub
#   ./dev.sh --local ../jeap-spring-boot-starters   # full site, that section from local
#   ./dev.sh --local ../jeap-admin-ch --no-autodiscover   # umbrella-only, from local (offline)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOCAL_REPOS=""
AUTODISCOVER="${AUTODISCOVER:-true}"

usage() {
  cat <<'EOF'
Usage: ./dev.sh [--local <path>]... [--no-autodiscover]

Aggregate the jEAP docs and run the Docusaurus dev server (hot reload) at
http://localhost:3000. With no flags it clones/auto-discovers every repo from
GitHub, exactly like the production build.

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
  ./dev.sh                                        # full site, all repos from GitHub
  ./dev.sh --local ../jeap-spring-boot-starters   # full site, that section from local
  ./dev.sh --local ../jeap-admin-ch --no-autodiscover   # umbrella-only, from local (offline)
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

echo "==> Starting dev server with hot reload..."
npm start
