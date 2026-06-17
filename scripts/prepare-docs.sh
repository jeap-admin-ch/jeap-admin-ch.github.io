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
#   1. Ordering    Applies the umbrella's order manifest (docs/_order) to the
#                  top-level curated content: each listed file gets a Docusaurus
#                  `sidebar_position`, each listed folder a positioned, labelled
#                  _category_.json. The order thus lives WITH the content in the
#                  umbrella repo — adding a section there needs no change here.
#                  The source repos stay free of generator-specific front matter;
#                  only these site copies get it, and files that already have
#                  front matter are left untouched. See the section-1 banner
#                  below for the manifest format.
#
#   2. Repo sections  For each auto-discovered repo section (a top-level subfolder
#                  with an index.md, assembled by clone-docs.sh from a repo's
#                  README + docs/): truncates the README at its trailing
#                  boilerplate (Changes/Note/License), rewrites the README's
#                  docs/ and image links to the relocated paths, and writes a
#                  _category_.json labelled with the repo name. index.md is the
#                  section landing page (Docusaurus category index convention).
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
# 1. Ordering — apply the umbrella's order manifest (docs/_order) to the
#    top-level curated content, so the sidebar order lives WITH the content
#    instead of being hard-coded here. Adding a section in the umbrella means
#    adding a line to its _order; this script needs no change.
#
#    Manifest format (shipped by the umbrella at docs/_order, which the `root`
#    placement lands at the docs root). One entry per line, in display order:
#
#        what-is-jeap
#        using-jeap
#        building-blocks | Building Blocks
#
#    - Blank lines and `#` comments are ignored.
#    - Each entry names a top-level file or folder in the assembled tree; its
#      line number becomes the sidebar position.
#    - `| Label` is optional and sets a folder's category label (ignored for
#      files, which take their label from the page title / front matter); a
#      folder with no label defaults to its prettified name (foo-bar -> Foo Bar).
#    - Files get sidebar_position front matter (skipped if the file already
#      ships its own front matter — the source wins). Folders get a
#      _category_.json. Auto-discovered repo sections (step 2) sort after these.
#    - `_order` is underscore-prefixed, so Docusaurus ignores it as a route.
# ---------------------------------------------------------------------------

# Prepend sidebar_position front matter to a top-level page. No-op if the file
# is absent or already starts with a front-matter block (source front matter wins).
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

# Write a folder's _category_.json (label + position). index.md inside the
# folder stays the category landing page (no "link" key — index convention).
write_category() {  # <dir> <label> <position>
  local dir="$1" label="$2" pos="$3"
  log "ordering: category $(basename "$dir") -> position $pos (label: $label)"
  cat > "$dir/_category_.json" <<JSON
{
  "label": "$label",
  "position": $pos
}
JSON
}

# Folders claimed by the manifest — recorded so the repo-section loop (step 2)
# skips them and never applies its README/link transforms to curated sections.
MANIFEST_DIRS=""

ORDER_FILE="$DOCS_DEST/_order"
if [ -f "$ORDER_FILE" ]; then
  log "ordering: applying manifest $ORDER_FILE"
  pos=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                                   # strip trailing comment
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$line" ] || continue                           # skip blank/comment-only lines
    entry="$line"; label=""
    case "$line" in
      *"|"*)
        entry="$(printf '%s' "$line" | sed -E 's/[[:space:]]*\|.*$//')"
        label="$(printf '%s' "$line" | sed -E 's/^[^|]*\|[[:space:]]*//')"
        ;;
    esac
    pos=$((pos + 1))
    name="${entry%.md}"                                  # tolerate a .md suffix
    if [ -d "$DOCS_DEST/$name" ]; then
      [ -n "$label" ] || label="$(printf '%s' "$name" | sed -E 's/[-_]/ /g; s/(^| )([a-z])/\1\U\2/g')"
      write_category "$DOCS_DEST/$name" "$label" "$pos"
      MANIFEST_DIRS="$MANIFEST_DIRS $name"
    elif [ -f "$DOCS_DEST/$name.md" ]; then
      set_position "$name.md" "$pos"
    else
      warn "ordering: manifest entry '$entry' not found in $DOCS_DEST — skipping"
    fi
  done < "$ORDER_FILE"
else
  warn "ordering: no manifest at $ORDER_FILE — top-level entries fall back to Docusaurus' default (alphabetical) order"
fi

# ---------------------------------------------------------------------------
# 2. Repo sections — process each auto-discovered repo folder (a top-level
#    subfolder with an index.md that the order manifest did NOT claim). Folders
#    are processed in alphabetical order so the sidebar lists repos A->Z;
#    positions start at 100 and step by 10 so auto-discovered repos sort after
#    the manifest-ordered umbrella content (positions 1..N).
#
#    The folder list is sorted explicitly with LC_ALL=C: bash already expands
#    globs in sorted order, but pinning the collation to byte order keeps the
#    ordering identical regardless of the runner's locale (local vs CI). The
#    loop reads from a process substitution (not a pipe) so repo_pos survives.
# ---------------------------------------------------------------------------
repo_pos=100
while IFS= read -r dir; do
  repo="$(basename "$dir")"
  # Skip folders the manifest already positioned (curated umbrella sections).
  case " $MANIFEST_DIRS " in *" $repo "*) continue ;; esac
  [ -f "$dir/index.md" ] || continue

  log "repo section: $repo (position $repo_pos)"

  # 2a. Truncate the README-derived landing page at its trailing boilerplate.
  #     Drops everything from the first Changes/Changelog/Note(s)/License heading
  #     to end of file — removing the ./CHANGELOG.md and ./LICENSE links that
  #     would otherwise break the build.
  sed -i -E '/^##[[:space:]]+([Cc]hangelog|[Cc]hange[[:space:]]+[Ll]og|[Cc]hanges?|[Nn]otes?|[Ll]icen[sc]e)([[:space:]].*)?$/,$d' \
    "$dir/index.md"

  # 2b. Rewrite the README's links so they resolve after relocation:
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

  # 2c. Label the section with the repo name and position it after the umbrella.
  #     index.md is auto-detected as the category landing page, so no "link" key
  #     here (that would conflict with the index convention).
  cat > "$dir/_category_.json" <<JSON
{
  "label": "$repo",
  "position": $repo_pos
}
JSON
  repo_pos=$((repo_pos + 10))
done < <(printf '%s\n' "$DOCS_DEST"/*/ | LC_ALL=C sort)

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
