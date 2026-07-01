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
#                  A "Getting started" page is pinned FIRST within its section,
#                  tree-wide: any getting-started.md (or getting-started/ folder)
#                  gets sidebar_position 0, so every documented repo that ships
#                  one shows it as its first sidebar entry (unpositioned siblings
#                  follow alphabetically). Forced, so it wins over source-shipped
#                  front matter too.
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
#                  Per repo section, a separate pass (run inside step 2) rewrites
#                  relative links that point at source-repo files which are NOT
#                  published as doc pages — links escaping docs/ via `..`, README
#                  links to files/dirs outside docs/, or links to non-doc assets
#                  (.sh/.conf/source) — into links to the file on GitHub.
#
# Configuration (environment variables):
#   DOCS_DEST          Docs directory to transform. Default: <site-root>/docs
#   UMBRELLA_REPO_URL  GitHub URL of the umbrella repo (target for ../README.md links).
#                      Default: https://github.com/jeap-admin-ch/jeap
#   SITE_BASE_URL      Public site URL whose absolute links are folded to internal ones.
#                      Default: https://jeap-admin-ch.github.io
#   REPO_WEB_BASE_URL  GitHub org base URL the source repos live under; used to build
#                      links to repository files that are not published as doc pages.
#                      Default: https://github.com/jeap-admin-ch
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
REPO_WEB_BASE_URL="${REPO_WEB_BASE_URL:-https://github.com/jeap-admin-ch}"

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

# Pin a page to a sidebar position, FORCING it even when the file
# already ships front matter (unlike set_position, which yields to source front
# matter). Replaces an existing sidebar_position inside the first front-matter
# block, inserts one when the block lacks it, or prepends a block when absent.
force_position() {  # <relative-file> <position>
  local rel="$1" pos="$2"
  local f="$DOCS_DEST/$rel"
  [ -f "$f" ] || { warn "ordering: $rel not present — skipping"; return 0; }
  log "ordering: pinning sidebar_position=$pos on $rel"
  if [ "$(head -n 1 "$f")" = "---" ]; then
    POS="$pos" perl -0777 -i -pe '
      s{\A(---\n)(.*?\n)(---\n)}{
        my ($open, $body, $close) = ($1, $2, $3);
        $body =~ s/^sidebar_position:.*\n/"sidebar_position: $ENV{POS}\n"/me
          or $body = "sidebar_position: $ENV{POS}\n" . $body;
        $open . $body . $close;
      }se;
    ' "$f"
  else
    local tmp; tmp="$(mktemp)"
    { printf -- '---\nsidebar_position: %s\n---\n\n' "$pos"; cat "$f"; } > "$tmp"
    mv "$tmp" "$f"
  fi
}

# Write a folder's _category_.json (label + position). index.md inside the
# folder stays the category landing page (no "link" key — index convention).
# The optional <collapsed> arg (default "true") sets whether the category starts
# collapsed in the sidebar; top-level categories pass "false" so they render
# expanded initially.
write_category() {  # <dir> <label> <position> [collapsed]
  local dir="$1" label="$2" pos="$3" collapsed="${4:-true}"
  log "ordering: category $(basename "$dir") -> position $pos (label: $label, collapsed: $collapsed)"
  cat > "$dir/_category_.json" <<JSON
{
  "label": "$label",
  "position": $pos,
  "collapsed": $collapsed
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
      # Top-level categories render expanded by default (collapsed: false).
      write_category "$DOCS_DEST/$name" "$label" "$pos" false
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
# 1b. Categories — route the auto-discovered repo sections (step 2) into App
#     Building Blocks subcategories instead of letting them sit flat at the top
#     level. The mapping lives WITH the content in the umbrella's docs/_categories
#     (see that file's header for the format): category lines (<folder> | <Label>)
#     define the subcategories in sidebar order, routing lines (<repo> = <folder>)
#     assign individual repos. Defaults for an unrouted repo: name contains
#     "starter" -> spring-boot-starters, otherwise -> libraries. If the manifest
#     is absent this is a no-op and repo sections fall back to flat placement.
# ---------------------------------------------------------------------------
BB_DIR="building-blocks"            # App Building Blocks folder (claimed by _order)
CATEGORIES_FILE="$DOCS_DEST/_categories"
ROUTES=""                            # space-separated "repo=folder" routing entries
CAT_COUNTS=""                        # space-separated "folder=count" (per-category repo counter)
CATEGORIES_ENABLED=0

# Resolve a routing alias (the friendly names) to a category folder.
resolve_alias() {  # <folder-or-alias>
  case "$1" in
    library)    printf 'libraries' ;;
    starter)    printf 'spring-boot-starters' ;;
    tool)       printf 'tooling' ;;
    reusablems) printf 'reusable-microservices' ;;
    *)          printf '%s' "$1" ;;
  esac
}

# Category folder for a repo: explicit route > "starter" default > libraries.
# Prints nothing when categories are disabled (flat fallback).
category_for_repo() {  # <repo>
  local repo="$1" entry
  [ "$CATEGORIES_ENABLED" = "1" ] || return 0
  for entry in $ROUTES; do
    [ "${entry%%=*}" = "$repo" ] && { printf '%s' "${entry##*=}"; return 0; }
  done
  case "$repo" in
    *starter*) printf 'spring-boot-starters' ;;
    *)         printf 'libraries' ;;
  esac
}

# Next sidebar position within a category (100, 110, … per folder), tracked in
# CAT_COUNTS so each subcategory lists its repos in the order they are processed.
next_cat_pos() {  # <folder>
  local folder="$1" n=0 found=0 newlist="" tok
  for tok in $CAT_COUNTS; do
    if [ "${tok%%=*}" = "$folder" ]; then
      n="${tok##*=}"; found=1; newlist="$newlist ${folder}=$((n + 1))"
    else
      newlist="$newlist $tok"
    fi
  done
  [ "$found" = "1" ] || newlist="$newlist ${folder}=1"
  CAT_COUNTS="$newlist"
  printf '%s' "$((100 + n * 10))"
}

if [ -f "$CATEGORIES_FILE" ]; then
  CATEGORIES_ENABLED=1
  log "categories: applying manifest $CATEGORIES_FILE"
  cat_pos=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$line" ] || continue
    case "$line" in
      *"|"*)                                            # category definition
        folder="$(printf '%s' "$line" | sed -E 's/[[:space:]]*\|.*$//')"
        label="$(printf '%s' "$line" | sed -E 's/^[^|]*\|[[:space:]]*//')"
        cat_pos=$((cat_pos + 1))
        cdir="$DOCS_DEST/$BB_DIR/$folder"
        if [ ! -d "$cdir" ]; then
          warn "categories: subcategory '$folder' has no folder under $BB_DIR — creating a stub landing page"
          mkdir -p "$cdir"
          printf '# %s\n' "$label" > "$cdir/index.md"
        fi
        write_category "$cdir" "$label" "$cat_pos"
        ;;
      *"="*)                                            # repo routing
        repo="$(printf '%s' "$line" | sed -E 's/[[:space:]]*=.*$//')"
        dest="$(resolve_alias "$(printf '%s' "$line" | sed -E 's/^[^=]*=[[:space:]]*//')")"
        ROUTES="$ROUTES ${repo}=${dest}"
        ;;
      *)
        warn "categories: ignoring unrecognized line '$line'"
        ;;
    esac
  done < "$CATEGORIES_FILE"
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
# Rewrite relative links in a repo section that point at source-repo files which
# are NOT published as doc pages — links escaping docs/ via `..`, README links to
# files/dirs outside docs/, links to non-doc assets (.sh/.conf/source) — into
# links to the file in the public GitHub repository. Each link target is resolved
# back to its path in the SOURCE repo (the README lands at the repo root; every
# other page came from the repo's docs/, flattened up one level here), so the
# GitHub URL points at the real file. Links that resolve to a file present in the
# assembled section (other doc pages, co-located images) are left untouched.
# Runs BEFORE the docs/ link normalization (2b) so it sees the original targets.
# GitHub redirects /blob/main/<dir> -> /tree/main/<dir>, so one blob form serves
# both files and directories.
rewrite_repo_file_links() {  # <repo> <section-dir>
  local repo="$1" section="${2%/}" f rel d repodir
  while IFS= read -r -d '' f; do
    rel="${f#"$section"/}"
    case "$rel" in
      index.md)   repodir="" ;;                       # from the repo's README.md (root)
      modules.md) repodir="docs" ;;                   # from the repo's docs/index.md
      *) d="$(dirname "$rel")"; [ "$d" = "." ] && repodir="docs" || repodir="docs/$d" ;;
    esac
    REPO="$repo" REPO_WEB_BASE="$REPO_WEB_BASE_URL" REPODIR="$repodir" SECTION="$section" \
      perl -i -pe '
BEGIN {
  $repo = $ENV{REPO}; $webbase = $ENV{REPO_WEB_BASE};
  $repodir = $ENV{REPODIR}; $section = $ENV{SECTION};
  # Normalize <repodir>/<target> to a repo-root-relative path; undef if it
  # escapes above the repo root (cannot be expressed as a repo file link).
  sub norm {
    my ($dir, $p) = @_;
    my $c = $dir eq "" ? $p : "$dir/$p";
    my @out;
    for my $seg (split m{/}, $c) {
      next if $seg eq "" || $seg eq ".";
      if ($seg eq "..") { return undef unless @out; pop @out; }
      else { push @out, $seg; }
    }
    return join("/", @out);
  }
  # Map a repo-root-relative path to its location in the assembled section, or
  # "" when the repo path has no published page (lives outside docs/).
  sub translate {
    my ($r) = @_;
    return "index.md"   if $r eq "README.md";
    return "modules.md" if $r eq "docs/index.md";
    return $1           if $r =~ m{^docs/(.+)$};
    return "";
  }
  sub rw {
    my ($url) = @_;
    return $url if $url =~ m{^(?:[a-zA-Z][a-zA-Z0-9+.\-]*:|//|/|#)};  # scheme/root/anchor
    my ($p, $suf) = $url =~ m{^([^#?]*)([#?].*)?$};
    $suf = "" unless defined $suf;
    return $url if $p eq "";
    my $r = norm($repodir, $p);
    return $url unless defined $r;
    return $url if $r eq "";
    my $a = translate($r);
    return $url if $a ne "" && -e "$section/$a";       # resolves to a real file here
    return "$webbase/$repo/blob/main/$r$suf";
  }
}
s{\]\(([^)\s]+)((?:\s+[^)]*)?)\)}{"](" . rw($1) . $2 . ")"}ge;
' "$f"
  done < <(find "$section" -type f -name '*.md' -print0)
}

repo_pos=100
MOVED_LINKS=""                        # "repo|docs/<new path>" entries for step 3b
while IFS= read -r dir; do
  repo="$(basename "$dir")"
  # Skip folders the manifest already positioned (curated umbrella sections).
  case " $MANIFEST_DIRS " in *" $repo "*) continue ;; esac
  [ -f "$dir/index.md" ] || continue

  # Route this repo into an App Building Blocks subcategory when the _categories
  # manifest is present; otherwise leave it flat at the top level (positions
  # 100+). Moving happens before the per-repo transforms so they run at the
  # final location; the glob below was expanded up front, so the move is safe.
  cat_folder="$(category_for_repo "$repo")"
  if [ -n "$cat_folder" ]; then
    catdir="$DOCS_DEST/$BB_DIR/$cat_folder"
    if [ ! -f "$catdir/_category_.json" ]; then
      # Routed to a category not declared in _categories — create + label it so
      # the build stays valid (placed after the declared categories).
      label="$(printf '%s' "$cat_folder" | sed -E 's/[-_]/ /g; s/(^| )([a-z])/\1\U\2/g')"
      mkdir -p "$catdir"
      [ -f "$catdir/index.md" ] || printf '# %s\n' "$label" > "$catdir/index.md"
      write_category "$catdir" "$label" 90
    fi
    mv "$dir" "$catdir/$repo"
    dir="$catdir/$repo"
    pos="$(next_cat_pos "$cat_folder")"
    MOVED_LINKS="$MOVED_LINKS ${repo}|docs/$BB_DIR/$cat_folder/$repo"
  else
    pos="$repo_pos"
    repo_pos=$((repo_pos + 10))
  fi

  log "repo section: $repo (-> ${cat_folder:-<top level>}, position $pos)"

  # 2a. Truncate the README-derived landing page at its trailing boilerplate.
  #     Drops everything from the first Changes/Changelog/Note(s)/License heading
  #     to end of file — removing the ./CHANGELOG.md and ./LICENSE links that
  #     would otherwise break the build.
  sed -i -E '/^##[[:space:]]+([Cc]hangelog|[Cc]hange[[:space:]]+[Ll]og|[Cc]hanges?|[Nn]otes?|[Ll]icen[sc]e)([[:space:]].*)?$/,$d' \
    "$dir/index.md"

  # 2a-bis. Rewrite links to source-repo files that have no published doc page
  #     (escaping docs/ via .., README links outside docs/, non-doc assets) to
  #     point at the file on GitHub. Runs before 2b so it sees original targets.
  rewrite_repo_file_links "$repo" "$dir"

  # 2b. Rewrite the README's links so they resolve after relocation. A leading
  #     `./` is optional so both `docs/x.md` and `./docs/x.md` are covered:
  #       docs/index.md -> ./modules.md  (collision rename done by clone-docs)
  #       docs/<x>.md   -> ./<x>.md      (sibling subpages)
  #       docs/images/  -> images/       (co-located assets; covers ![..](..))
  find "$dir" -type f -name '*.md' -print0 | while IFS= read -r -d '' f; do
    sed -i -E \
      -e 's|\]\((\./)?docs/index\.md\)|](./modules.md)|g' \
      -e 's|\]\((\./)?docs/([^)]+)\.md\)|](./\2.md)|g' \
      -e 's|\]\((\./)?docs/images/|](images/|g' \
      "$f"
  done

  # 2c. Label the section with the repo name and position it after the umbrella.
  #     index.md is auto-detected as the category landing page, so no "link" key
  #     here (that would conflict with the index convention).
  cat > "$dir/_category_.json" <<JSON
{
  "label": "$repo",
  "position": $pos
}
JSON
done < <(printf '%s\n' "$DOCS_DEST"/*/ | LC_ALL=C sort)

# ---------------------------------------------------------------------------
# 2d. Pin "Getting started" first within its section — applied tree-wide, so
#     every documented repo section (and any curated folder) that ships a
#     getting-started page shows it as its first entry. A sidebar_position of 0
#     wins the top slot; unpositioned siblings fall to Docusaurus' alphabetical
#     order after it (lodash orderBy sorts a missing position as undefined =
#     last). Forced, so it beats source-shipped front matter too. Covers both a
#     getting-started.md page and a getting-started/ subsection.
# ---------------------------------------------------------------------------
log "ordering: pinning getting-started pages first within their sections"
while IFS= read -r -d '' f; do
  force_position "${f#"$DOCS_DEST"/}" 0
done < <(find "$DOCS_DEST" -type f -name 'getting-started.md' -print0)
while IFS= read -r -d '' d; do
  write_category "$d" "Getting Started" 0
done < <(find "$DOCS_DEST" -type d -name 'getting-started' -print0)

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

# 3b. Routed-repo links — rewrite content links that point at a routed repo's
#     old top-level path (/docs/<repo>) to its new nested path under
#     building-blocks/<category>/. Runs after 3a (which has already folded
#     absolute site URLs to /docs/<repo>). Keeps curated content decoupled from
#     the routing: recategorizing a repo updates its inbound links for free.
#     The trailing ([/)]) match covers both `/docs/<repo>/...` and `/docs/<repo>)`.
if [ -n "$MOVED_LINKS" ]; then
  log "links: rewriting routed repo paths (/docs/<repo> -> nested) in $DOCS_DEST"
  for entry in $MOVED_LINKS; do
    repo="${entry%%|*}"; newbase="${entry##*|}"
    find "$DOCS_DEST" -type f -name '*.md' -print0 | while IFS= read -r -d '' f; do
      sed -i -E "s|\]\(/docs/${repo}([/)])|](/${newbase}\1|g" "$f"
    done
  done
fi

log "prepare step complete for $DOCS_DEST"
