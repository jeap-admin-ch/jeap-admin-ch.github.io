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
#   3. Repo sections  For each auto-discovered repo section (a top-level subfolder
#                  with an index.md, assembled by clone-docs.sh from a repo's
#                  README + docs/): truncates the README at its trailing
#                  boilerplate (Changes/Note/License), rewrites the README's
#                  docs/ and image links to the relocated paths, and writes a
#                  _category_.json labelled with the repo name. index.md is the
#                  section landing page (Docusaurus category index convention).
#
#   4. Link rewrite  Fixes links that are valid on GitHub but would break the
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
# 3. Repo sections — process each auto-discovered repo folder (a top-level
#    subfolder with an index.md, other than building-blocks). Folders are
#    sorted so positions are deterministic; positions start at 10 and step by
#    10 so all repo sections sort after the hand-written umbrella pages (1-4).
# ---------------------------------------------------------------------------
repo_pos=10
for dir in "$DOCS_DEST"/*/; do
  repo="$(basename "$dir")"
  [ "$repo" = "building-blocks" ] && continue
  [ -f "$dir/index.md" ] || continue

  log "repo section: $repo (position $repo_pos)"

  # 3a. Truncate the README-derived landing page at its trailing boilerplate.
  #     Drops everything from the first Changes/Changelog/Note(s)/License heading
  #     to end of file — removing the ./CHANGELOG.md and ./LICENSE links that
  #     would otherwise break the build.
  sed -i -E '/^##[[:space:]]+([Cc]hangelog|[Cc]hange[[:space:]]+[Ll]og|[Cc]hanges?|[Nn]otes?|[Ll]icen[sc]e)([[:space:]].*)?$/,$d' \
    "$dir/index.md"

  # 3b. Rewrite the README's links so they resolve after relocation:
  #       docs/index.md -> ./modules.md  (collision rename done by clone-docs)
  #       docs/<x>.md   -> ./<x>.md      (sibling subpages)
  #       docs/images/  -> images/       (co-located assets; covers ![..](..))
  find "$dir" -type f -name '*.md' -print0 | while IFS= read -r -d '' f; do
    sed -i -E \
      -e 's|\]\(docs/index\.md\)|](./modules.md)|g' \
      -e 's|\]\(docs/([^)]+)\.md\)|](./\1.md)|g' \
      -e 's|\]\(docs/images/|](images/|g' \
      "$f"
  done

  # 3c. Label the section with the repo name and position it after the umbrella.
  #     index.md is auto-detected as the category landing page, so no "link" key
  #     here (that would conflict with the index convention).
  cat > "$dir/_category_.json" <<JSON
{
  "label": "$repo",
  "position": $repo_pos
}
JSON
  repo_pos=$((repo_pos + 10))
done

# ---------------------------------------------------------------------------
# 4. Link rewriting — applied to every Markdown file. Uses '|' as the sed
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
