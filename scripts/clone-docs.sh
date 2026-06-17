#!/usr/bin/env bash
#
# clone-docs.sh — Step 1/2 of the jEAP documentation publication pipeline.
#
# Clones jEAP source repositories and assembles their `docs/` directories into
# this Docusaurus site's `docs/` directory. It only fetches and places raw
# content; the content transformations for GitHub Pages (sidebar ordering,
# category metadata, link rewriting) are done separately by `prepare-docs.sh`.
#
# Why two scripts? So the steps can be run independently. For example, you can
# skip cloning and instead copy a `docs/` tree in manually (e.g. from a local
# checkout), then run `prepare-docs.sh` on it.
#
# Pipeline:
#   1. clone-docs.sh    — fetch raw docs/ content from the source repos (this script)
#   2. prepare-docs.sh  — transform the assembled content for GitHub Pages
#
# Configuration (environment variables):
#   REPO_BASE_URL  Base URL/prefix the repos are cloned from.
#                  Default: https://github.com/jeap-admin-ch
#                  For local testing, point at a parent directory via file://, e.g.
#                    REPO_BASE_URL="file:///home/dev/IdeaProjects"
#   BRANCH         Branch to clone — always the latest tip of this branch.
#                  Default: main
#   REPOS          Whitespace/newline separated manifest of "<name>:<placement>"
#                  entries, where placement is one of:
#                    root    -> the repo's docs/ is copied to the top level of docs/
#                    nested  -> the repo's docs/ is copied to docs/<name>/
#                  Default: "jeap:root"  (the umbrella repo holding the general doc)
#   DOCS_DEST      Destination docs directory. Default: <site-root>/docs
#
# Examples:
#   # Production: clone the umbrella general doc from GitHub (main):
#   bash scripts/clone-docs.sh
#
#   # Local test: clone the umbrella doc from a local checkout on a feature branch.
#   # The umbrella repo's directory there is named "jeap-admin-ch", so override REPOS:
#   REPO_BASE_URL="file:///home/dev/IdeaProjects" \
#   BRANCH="feature/JEAP-7069" \
#   REPOS="jeap-admin-ch:root" \
#     bash scripts/clone-docs.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_BASE_URL="${REPO_BASE_URL:-https://github.com/jeap-admin-ch}"
BRANCH="${BRANCH:-main}"
REPOS="${REPOS:-jeap:root}"
DOCS_DEST="${DOCS_DEST:-$SITE_ROOT/docs}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git not found"

# Fresh temporary workspace for the clones; always cleaned up on exit.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# docs/ is generated content: start from a clean slate so the step is idempotent.
log "Resetting destination docs tree: $DOCS_DEST"
rm -rf "$DOCS_DEST"
mkdir -p "$DOCS_DEST"

# Clone a single repo and copy its docs/ into the destination at the given placement.
aggregate_one() {
  local name="$1" placement="$2"
  local url="$REPO_BASE_URL/$name"
  local checkout="$WORK_DIR/$name"

  log "Cloning $name ($BRANCH) from $url"
  git clone --depth 1 --branch "$BRANCH" "$url" "$checkout" \
    || die "git clone failed for '$name' @ '$BRANCH' from $url"

  if [ ! -d "$checkout/docs" ]; then
    warn "$name has no docs/ directory — skipping"
    return 0
  fi

  case "$placement" in
    root)
      log "Placing $name docs/ at the top level of $DOCS_DEST"
      # Trailing /. copies the directory contents (incl. subfolders) without
      # nesting an extra docs/ level.
      cp -R "$checkout/docs/." "$DOCS_DEST/"
      ;;
    nested)
      log "Placing $name docs/ under $DOCS_DEST/$name/"
      mkdir -p "$DOCS_DEST/$name"
      cp -R "$checkout/docs/." "$DOCS_DEST/$name/"
      ;;
    *)
      die "Unknown placement '$placement' for repo '$name' (use root|nested)"
      ;;
  esac
}

for entry in $REPOS; do
  name="${entry%%:*}"
  placement="${entry##*:}"
  [ -n "$name" ] || continue
  aggregate_one "$name" "$placement"
done

count="$(find "$DOCS_DEST" -name '*.md' | wc -l | tr -d ' ')"
log "Clone step complete: $count markdown file(s) assembled in $DOCS_DEST"
log "Next: run scripts/prepare-docs.sh to transform the content for GitHub Pages."
