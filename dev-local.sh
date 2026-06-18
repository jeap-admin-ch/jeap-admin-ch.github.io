#!/usr/bin/env bash
#
# dev-local.sh — Run the dev server against the CURRENT LOCAL state of jeap-admin-ch,
# optionally including a local jEAP repo as a nested doc section.
#
# Convenience wrapper for local authoring. Unlike the normal pipeline (which clones
# the umbrella repo and therefore only sees *committed* content), this copies the
# working-tree docs/ from a local jeap-admin-ch checkout — so your uncommitted edits
# show up immediately — runs the same content preparation as production, then starts
# the Docusaurus dev server.
#
# Hot reload note: the dev server watches the copied docs/ in THIS repo, not the
# source. To pick up further edits made in <src>/docs, re-run this script.
#
# Usage:
#   ./dev-local.sh [path-to-jeap-admin-ch]
#   ./dev-local.sh --include <path-to-repo> [path-to-jeap-admin-ch]
#
# Options:
#   --include <path>  Include a local repo's docs/ as a nested section in the site.
#                     The repo's directory name determines the section URL (e.g.
#                     ../jeap-messaging → /jeap-messaging/). The repo's README.md
#                     becomes the section landing page, mirroring the auto-discovery
#                     behaviour of clone-docs.sh. May be specified multiple times.
#
# Source directory resolution for the umbrella (first match wins):
#   1. First positional argument (after options)
#   2. $JEAP_ADMIN_CH_DIR
#   3. ../jeap-admin-ch (sibling of this repository)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INCLUDE_REPOS=()

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --include)
      [ -n "${2:-}" ] || { echo "ERROR: --include requires a path argument" >&2; exit 1; }
      INCLUDE_REPOS+=("$2")
      shift 2
      ;;
    *)
      # First positional argument is the umbrella path.
      POSITIONAL_SRC="$1"
      shift
      ;;
  esac
done

SRC_DIR="${POSITIONAL_SRC:-${JEAP_ADMIN_CH_DIR:-$SCRIPT_DIR/../jeap-admin-ch}}"
DOCS_DEST="$SCRIPT_DIR/docs"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$SRC_DIR/docs" ] || die "No docs/ directory found in '$SRC_DIR'. Pass the path to your jeap-admin-ch checkout as an argument."
SRC_DIR="$(cd "$SRC_DIR" && pwd)"  # normalise to an absolute path for clear logging

log "Using LOCAL docs (working tree, including uncommitted changes): $SRC_DIR/docs"
rm -rf "$DOCS_DEST"
mkdir -p "$DOCS_DEST"
cp -R "$SRC_DIR/docs/." "$DOCS_DEST/"

# --- Include additional local repos as nested sections ---
for repo_path in "${INCLUDE_REPOS[@]}"; do
  [ -d "$repo_path/docs" ] || die "No docs/ directory found in '$repo_path'."
  repo_path="$(cd "$repo_path" && pwd)"
  repo_name="$(basename "$repo_path")"
  dest="$DOCS_DEST/$repo_name"

  log "Including LOCAL repo '$repo_name' from $repo_path/docs"
  mkdir -p "$dest"
  cp -R "$repo_path/docs/." "$dest/"

  # Mirror the auto-discovery convention: README.md becomes the landing page.
  if [ -f "$dest/index.md" ]; then
    mv "$dest/index.md" "$dest/modules.md"
  fi
  if [ -f "$repo_path/README.md" ]; then
    cp "$repo_path/README.md" "$dest/index.md"
  fi
done

log "Preparing docs for the site"
bash "$SCRIPT_DIR/scripts/prepare-docs.sh"

if [ ! -d node_modules ]; then
  log "Installing dependencies (node_modules missing)"
  npm ci
fi

log "Starting dev server — re-run this script to pick up further edits"
npm start
