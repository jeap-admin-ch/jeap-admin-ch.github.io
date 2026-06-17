#!/usr/bin/env bash
#
# dev-local.sh — Run the dev server against the CURRENT LOCAL state of jeap-admin-ch.
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
#
# Source directory resolution (first match wins):
#   1. $1 (command-line argument)
#   2. $JEAP_ADMIN_CH_DIR
#   3. ../jeap-admin-ch (sibling of this repository)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SRC_DIR="${1:-${JEAP_ADMIN_CH_DIR:-$SCRIPT_DIR/../jeap-admin-ch}}"
DOCS_DEST="$SCRIPT_DIR/docs"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$SRC_DIR/docs" ] || die "No docs/ directory found in '$SRC_DIR'. Pass the path to your jeap-admin-ch checkout as an argument."
SRC_DIR="$(cd "$SRC_DIR" && pwd)"  # normalise to an absolute path for clear logging

log "Using LOCAL docs (working tree, including uncommitted changes): $SRC_DIR/docs"
rm -rf "$DOCS_DEST"
mkdir -p "$DOCS_DEST"
cp -R "$SRC_DIR/docs/." "$DOCS_DEST/"

log "Preparing docs for the site"
bash "$SCRIPT_DIR/scripts/prepare-docs.sh"

if [ ! -d node_modules ]; then
  log "Installing dependencies (node_modules missing)"
  npm ci
fi

log "Starting dev server — re-run this script to pick up further edits in $SRC_DIR/docs"
npm start
