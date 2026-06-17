#!/usr/bin/env bash
#
# prepare-docs.sh — Step 2/2 of the jEAP documentation publication pipeline.
#
# Transforms an already-assembled `docs/` tree so it renders correctly on the
# Docusaurus GitHub Pages site. It operates IN PLACE on whatever is in DOCS_DEST,
# so it can run on content fetched by `clone-docs.sh` OR on a `docs/` tree you
# copied in manually (e.g. for local testing without the cloning step).
#
# All transformations are idempotent (safe to re-run):
#
#   1. Ordering    Injects Docusaurus `sidebar_position` front matter into the
#                  top-level general-doc pages so the sidebar reads logically
#                  (What is jEAP? -> Using jEAP -> App Building Blocks). The source
#                  repos stay free of generator-specific front matter — only these
#                  copies get it. Files that already have front matter are skipped.
#
#   2. Categories  Writes _category_.json for the building-blocks/ subfolder so it
#                  appears as a labelled, positioned group in the sidebar.
#
#   3. Link rewrite  Fixes links that are valid on GitHub but would break the
#                  Docusaurus build (onBrokenLinks: 'throw'):
#                    a) `](../README.md)` -> the umbrella repo's README on GitHub.
#                       (Points at the source repo root, which has no docs page.)
#                    b) absolute GitHub Pages URLs -> site-internal links, e.g.
#                       https://jeap-admin-ch.github.io/jeap-messaging/x -> /jeap-messaging/x
#                       (relevant once cross-repo links exist; harmless today).
#                  Intra-tree relative .md links are left untouched — they resolve
#                  correctly because the directory structure is preserved 1:1.
#
# Configuration (environment variables):
#   DOCS_DEST          Docs directory to transform. Default: <site-root>/docs
#   UMBRELLA_REPO_URL  GitHub URL of the umbrella repo (target for ../README.md links).
#                      Default: https://github.com/jeap-admin-ch/jeap
#   SITE_BASE_URL      Public site URL whose absolute links are folded to internal ones.
#                      Default: https://jeap-admin-ch.github.io
#
# Example:
#   bash scripts/prepare-docs.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCS_DEST="${DOCS_DEST:-$SITE_ROOT/docs}"
UMBRELLA_REPO_URL="${UMBRELLA_REPO_URL:-https://github.com/jeap-admin-ch/jeap}"
SITE_BASE_URL="${SITE_BASE_URL:-https://jeap-admin-ch.github.io}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$DOCS_DEST" ] || die "Docs directory not found: $DOCS_DEST (run clone-docs.sh or copy a docs/ tree in first)"

# ---------------------------------------------------------------------------
# 1. Ordering — prepend sidebar_position front matter to a top-level page.
#    No-op if the file is absent or already starts with a front-matter block.
# ---------------------------------------------------------------------------
set_position() {  # <relative-file> <position>
  local rel="$1" pos="$2"
  local f="$DOCS_DEST/$rel"
  [ -f "$f" ] || { warn "ordering: $rel not present — skipping"; return 0; }
  if [ "$(head -n 1 "$f")" = "---" ]; then
    log "ordering: $rel already has front matter — leaving as is"
    return 0
  fi
  log "ordering: setting sidebar_position=$pos on $rel"
  local tmp; tmp="$(mktemp)"
  {
    printf -- '---\nsidebar_position: %s\n---\n\n' "$pos"
    cat "$f"
  } > "$tmp"
  mv "$tmp" "$f"
}

set_position "what-is-jeap.md"    1
set_position "using-jeap.md"      2
set_position "building-blocks.md" 3

# ---------------------------------------------------------------------------
# 2. Categories — label and position the building-blocks/ subfolder.
# ---------------------------------------------------------------------------
if [ -d "$DOCS_DEST/building-blocks" ]; then
  log "categories: writing building-blocks/_category_.json"
  cat > "$DOCS_DEST/building-blocks/_category_.json" <<'JSON'
{
  "label": "Building Blocks",
  "position": 4
}
JSON
fi

# ---------------------------------------------------------------------------
# 3. Link rewriting — applied to every Markdown file. Uses '|' as the sed
#    delimiter so the URLs (which contain '/' and '#') need no escaping there;
#    only the regex-special '.' in SITE_BASE_URL is escaped.
# ---------------------------------------------------------------------------
log "links: rewriting ../README.md and absolute site URLs in $DOCS_DEST"
site_re="$(printf '%s' "$SITE_BASE_URL" | sed 's/\./\\./g')"
find "$DOCS_DEST" -type f -name '*.md' -print0 | while IFS= read -r -d '' f; do
  sed -i -E \
    -e "s|\]\((\.\./)+README\.md\)|](${UMBRELLA_REPO_URL}#readme)|g" \
    -e "s|\]\(${site_re}/|](/|g" \
    "$f"
done

log "prepare step complete for $DOCS_DEST"
