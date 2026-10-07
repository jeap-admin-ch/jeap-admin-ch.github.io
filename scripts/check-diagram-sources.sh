#!/usr/bin/env bash
#
# check-diagram-sources.sh — enforce the diagram source/image pairing in a docs tree.
#
# jEAP documentation keeps a diagram as TWO files committed side by side: the
# editable source (e.g. `images/overview.drawio`) and the image exported from it
# (`images/overview.svg`). The author exports the image by hand, so the one thing
# that can go wrong is forgetting to: the source is committed changed, the image
# stays as it was, and the doc site keeps showing the old picture with nobody
# noticing. This script is the gate against that, and it also keeps the sources
# themselves out of what gets published.
#
# Subcommands:
#   sources <tree>                      List the diagram sources in <tree>, one
#                                       relative path per line. No git needed.
#   prune <tree>                        Delete those sources from <tree>. Run on
#                                       the ASSEMBLED tree, so the published site
#                                       carries the pictures, not the editor files.
#   check [--deepen] <repo> [<subdir>]  Fail if a source was committed more
#                                       recently than its image. <repo> is a git
#                                       checkout; <subdir> is the tree to examine
#                                       within it (default `docs`).
#
# What counts as a diagram source (same rule in all three implementations of it —
# this script, jeap_pipeline.doc_diagram_sources and the Jenkins OSS enforcer):
#
#   A file is the source of an image when, in the SAME folder, there is an image
#   file whose stem it extends — its name is `<image-stem>.<anything>` — and its
#   own extension is NOT one of the extensions the doc service publishes.
#
#   overview.svg   + overview.drawio       -> overview.drawio is the source
#   overview.png   + overview.drawio.xml   -> overview.drawio.xml is the source
#   report.svg     + report.pdf            -> NOT a pair; .pdf is published, so
#                                             the PDF is an asset of its own
#   diagram.svg    + diagram.png           -> NOT a pair; both are published
#
# The rule is deliberately about the NAME and not about a list of known diagram
# tools: the story this implements chose hand-exported images precisely so that
# the convention works for any editor, and a tool allowlist would need a code
# change for every new one. Requiring the companion to be an image, and the
# candidate to be something the doc service would refuse anyway, is what keeps it
# from swallowing a real asset.
#
# Why committer dates and not file mtimes: git neither stores nor restores
# mtimes. A clone writes every file at checkout time, so in CI all mtimes are
# effectively equal and their order is arbitrary — an mtime check would pass by
# luck. The committer date of the commit that last touched each file is the only
# thing that survives a clone.
#
# Why --deepen: in a shallow clone `git log -1 -- <path>` answers with the
# shallow boundary commit for every file that was last touched further back,
# which would make every pair look equally old and the check pass silently. With
# --deepen the repository is deepened — in rounds, only as far as it takes to get
# a reliable answer for the pairs actually found — and the check refuses to
# report a verdict until it has one. Without --deepen a shallow repository is an
# error rather than a pass.
#
# ---------------------------------------------------------------------------
# This file is shared, verbatim, by two repositories, because the two pipelines
# that gate the convention cannot depend on one another:
#
#   jeap-admin-ch.github.io  scripts/check-diagram-sources.sh
#       called by clone-docs.sh for every repo whose docs are published
#   jeap-microservice-pipeline
#       resources/ch/admin/bit/jeap/microservicepipeline/oss/check_diagram_sources.sh
#       run by oss/DiagramSourceEnforcer on the author's own build
#
# Keep them identical - `diff` between the two must be empty - and change both
# in one go. The same rule has a third implementation in Python, for the doc
# pipeline of the business applications:
# jeap-python-pipeline-lib, src/jeap_pipeline/doc_diagram_sources.py, whose
# tests are the most thorough of the three.
# ---------------------------------------------------------------------------
#
set -uo pipefail

# Extensions the doc service publishes (jeap-doc-service's Arc42Template
# allowedFileExtensions). A file with one of these is an asset in its own right
# and never treated as somebody's diagram source.
PUBLISHED_EXTENSIONS="md png jpg jpeg gif webp avif svg pdf txt csv json yaml yml"

# The published extensions that are pictures — only these can have a source.
IMAGE_EXTENSIONS="svg png jpg jpeg gif webp avif"

# How far to deepen per round before giving up and fetching the whole history.
DEEPEN_ROUNDS="64 256 1024"

usage() {
  sed -n '3,55p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# Print the diagram sources of a tree, one path relative to <tree> per line,
# sorted. Pure name analysis: no git, no file contents.
list_sources() {  # <tree>
  local tree="${1%/}"
  [ -d "$tree" ] || return 0
  ( cd "$tree" && find . -type f -print0 ) \
    | LC_ALL=C sort -z \
    | pair_up "${2:-sources}"
}

# Print "<source> <image>" for every pair found, one per line, sorted.
list_pairs() {  # <tree>
  local tree="${1%/}"
  [ -d "$tree" ] || return 0
  ( cd "$tree" && find . -type f -print0 ) \
    | LC_ALL=C sort -z \
    | pair_up "${2:-pairs}"
}

# The pairing rule reads NUL-delimited paths. Human-readable modes print lines;
# internal sources0/pairs0 modes preserve every filename byte using NUL records.
# Never parse the human-readable pair output to drive validation or pruning.
pair_up() {  # <sources|pairs>   (paths on stdin)
  awk -v RS='\0' -v mode="$1" \
      -v published="$PUBLISHED_EXTENSIONS" \
      -v images="$IMAGE_EXTENSIONS" '
    BEGIN {
      n = split(published, a, " "); for (i = 1; i <= n; i++) is_published[a[i]] = 1
      n = split(images, a, " ");    for (i = 1; i <= n; i++) is_image[a[i]] = 1
    }
    # The part of a path after the last slash, and the directory before it.
    function base(p) { return (p ~ /\//) ? substr(p, length(dir(p)) + 2) : p }
    function dir(p)  { if (p !~ /\//) return ""; sub(/\/[^\/]*$/, "", p); return p }
    # Lower-cased extension after the LAST dot, "" when there is none.
    function ext(name,    i) {
      i = length(name)
      while (i > 0 && substr(name, i, 1) != ".") i--
      if (i <= 1) return ""                       # no dot, or a dotfile
      return tolower(substr(name, i + 1))
    }
    # The name without its last extension.
    function stem(name,    i) {
      i = length(name)
      while (i > 0 && substr(name, i, 1) != ".") i--
      if (i <= 1) return name
      return substr(name, 1, i - 1)
    }
    {
      sub(/^\.\//, "", $0)
      path[NR] = $0
      d = dir($0); b = base($0)
      folder[NR] = d; name[NR] = b; extension[NR] = ext(b)
      count = ++per_folder[d]
      member[d, count] = NR
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (extension[i] == "" || is_published[extension[i]]) continue
        d = folder[i]
        best = 0; best_len = -1
        for (k = 1; k <= per_folder[d]; k++) {
          j = member[d, k]
          if (j == i || !is_image[extension[j]]) continue
          s = stem(name[j])
          if (s == name[i]) continue
          if (index(name[i], s ".") != 1) continue
          # The most specific companion wins: with both a.png and a.b.png
          # present, a.b.drawio belongs to a.b.png.
          if (length(s) > best_len) { best_len = length(s); best = j }
        }
        if (best == 0) continue
        if (mode == "pairs0") printf "%s%c%s%c", path[i], 0, path[best], 0
        else if (mode == "sources0") printf "%s%c", path[i], 0
        else if (mode == "pairs") printf "%s %s\n", path[i], path[best]
        else                 printf "%s\n", path[i]
      }
    }
  '
}

# Delete the diagram sources from an assembled tree. Empties left behind are not
# removed: an images/ folder holding only sources would mean the page references
# an image that was never exported, and that is the check's verdict to give, not
# something to tidy away here.
prune_sources() {  # <tree>
  local tree="${1%/}" rel pruned=0 records
  records="$(mktemp)" || die "cannot create a discovery record file"
  # Capture the producer status before removing anything; process substitution
  # would turn failed/partial discovery into successful empty input.
  if ! list_sources "$tree" sources0 > "$records"; then
    rm -f -- "$records"
    die "cannot discover diagram sources in $tree"
  fi
  local sources=()
  mapfile -d '' -t sources < "$records" || { rm -f -- "$records"; die "cannot read source records"; }
  rm -f -- "$records"
  for rel in "${sources[@]}"; do
    [ -n "$rel" ] || continue
    rm -f "$tree/$rel" || die "cannot remove diagram source $tree/$rel"
    pruned=$((pruned + 1))
  done
  [ "$pruned" -eq 0 ] || printf 'Pruned %s diagram source(s) from %s\n' "$pruned" "$tree"
}

# The commits the shallow history is grafted at, space-padded for substring
# matching. Empty for a complete repository.
shallow_boundary() {  # <repo>
  local file state boundary
  state="$(git -C "$1" rev-parse --is-shallow-repository)" || die "cannot determine shallow history"
  case "$state" in
    false) return 0 ;;
    true) ;;
    *) die "invalid shallow history response" ;;
  esac
  file="$(git -C "$1" rev-parse --git-path shallow)" || die "cannot locate shallow history"
  case "$file" in
    ''|--*|*$'\n'*) die "invalid shallow history path" ;;
    /*) ;;
    *) file="$1/$file" ;;
  esac
  [ -f "$file" ] || die "shallow checkout has no boundary file"
  boundary="$(tr '\n' ' ' < "$file")" || die "cannot read shallow history"
  [ -n "$boundary" ] || die "shallow boundary file is empty"
  printf ' %s ' "$boundary"
}

# "<sha> <unix-timestamp> <iso-date>" of the commit that last touched <path>, or
# "" when the path has no commit at all (untracked, or ignored).
last_commit() {  # <repo> <path>
  git --literal-pathspecs -C "$1" log -1 --format='%H %ct %cI' -- "$2"
}

# Does the shallow boundary make any of these paths undatable? `git log -1 --
# <path>` answers with the grafted commit for every file that was last touched
# beyond it, and that answer cannot be told apart from "really changed there" —
# so a boundary-dated path has no usable date, shallow or not. A complete
# repository has no boundary and always answers reliably.
boundary_dated() {  # <repo> <path>...
  local repo="$1"; shift
  local boundary sha path
  boundary="$(shallow_boundary "$repo")" || die "cannot inspect diagram history"
  [ -n "$boundary" ] || return 1
  for path in "$@"; do
    sha="$(last_commit "$repo" "$path")" || die "cannot read history for $path"
    sha="${sha%% *}"
    [ -n "$sha" ] || continue
    case "$boundary" in *" $sha "*) return 0 ;; esac
  done
  return 1
}

# Deepen the repository until the commits that last touched the given paths are
# no longer the shallow boundary — i.e. until the dates are the real ones. Only
# ever called when a pair was actually found, so a repository whose docs hold no
# diagram keeps its depth-1 clone. Deepening in rounds rather than unshallowing
# outright keeps the common case (a diagram touched recently) to one small fetch;
# the full history is taken only when the rounds did not reach far enough.
deepen_until_datable() {  # <repo> <path>...
  local repo="$1"; shift
  local depth

  for depth in $DEEPEN_ROUNDS; do
    boundary_dated "$repo" "$@" || return 0
    printf 'Deepening %s by %s commits to date its diagrams\n' "$(basename "$repo")" "$depth"
    git -C "$repo" fetch --quiet --deepen "$depth" 2>/dev/null || break
  done

  boundary_dated "$repo" "$@" || return 0

  # Still grafted at a commit that matters: take the whole history rather than
  # report a verdict based on the boundary.
  printf 'Unshallowing %s to date its diagrams\n' "$(basename "$repo")"
  git -C "$repo" fetch --quiet --unshallow 2>/dev/null || true
}

# Was the source committed after its image was? The committer dates decide. They
# are only one second apart in resolution though, and two commits pushed
# together can share a second, so an equal date is resolved by asking which
# commit came first in the history: if the image's commit is an ancestor of the
# source's, the export predates the edit and the image is stale after all.
is_stale() {  # <repo> <src-sha> <src-ts> <img-sha> <img-ts>
  local repo="$1" src_sha="$2" src_ts="$3" img_sha="$4" img_ts="$5"
  [ "$src_ts" -gt "$img_ts" ] && return 0
  [ "$src_ts" -eq "$img_ts" ] || return 1
  [ "$src_sha" != "$img_sha" ] || return 1
  local status=0
  git -C "$repo" merge-base --is-ancestor "$img_sha" "$src_sha" || status=$?
  [ "$status" -le 1 ] || die "cannot compare diagram commit ancestry"
  return "$status"
}

check_tree() {  # [--deepen] <repo> [<subdir>]
  local deepen=false
  if [ "${1:-}" = "--deepen" ]; then deepen=true; shift; fi

  local repo="${1:-}" subdir="${2:-docs}"
  [ -n "$repo" ] || die "check needs a repository directory"
  [ -d "$repo" ] || die "not a directory: $repo"

  local tree="$repo/${subdir#./}"
  tree="${tree%/}"
  [ -d "$tree" ] || return 0

  local pairs=() records
  records="$(mktemp)" || die "cannot create a discovery record file"
  if ! list_pairs "$tree" pairs0 > "$records"; then
    rm -f -- "$records"
    die "cannot discover diagram pairs in $tree"
  fi
  mapfile -d '' -t pairs < "$records" || { rm -f -- "$records"; die "cannot read pair records"; }
  rm -f -- "$records"
  if [ "${#pairs[@]}" -eq 0 ]; then
    return 0
  fi

  local count=$((${#pairs[@]} / 2))
  printf 'Checking %s diagram source/image pair(s) in %s\n' "$count" "${tree#"$repo"/}"

  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 \
    || die "$tree holds $count diagram source/image pair(s) but $repo is not a git repository, so the export cannot be verified"

  local paths=() source image i
  for ((i=0; i<${#pairs[@]}; i+=2)); do
    source="${pairs[i]}"; image="${pairs[i+1]}"
    paths+=("$subdir/$source" "$subdir/$image")
  done

  [ "$deepen" = true ] && deepen_until_datable "$repo" "${paths[@]}"

  if boundary_dated "$repo" "${paths[@]}"; then
    die "the history of $repo does not reach back to the commits that last touched its $count diagram source/image pair(s), so their dates cannot be compared.
Deepen the clone (this check does it itself when run with --deepen, the jEAP doc workflow checks out with the history) — a shallow clone answers with its boundary commit for every older file, which would let a stale diagram through unnoticed."
  fi

  local stale=0 skipped=0 src_info img_info src_sha img_sha src_ts img_ts src_iso img_iso
  for ((i=0; i<${#pairs[@]}; i+=2)); do
    source="${pairs[i]}"; image="${pairs[i+1]}"
    src_info="$(last_commit "$repo" "$subdir/$source")" || die "cannot read history for $source"
    img_info="$(last_commit "$repo" "$subdir/$image")" || die "cannot read history for $image"
    if [ -z "$src_info" ] || [ -z "$img_info" ]; then
      printf 'WARN: %s / %s is not committed yet — skipping the export check for it\n' \
        "$source" "$image" >&2
      skipped=$((skipped + 1))
      continue
    fi
    read -r src_sha src_ts src_iso <<< "$src_info"
    read -r img_sha img_ts img_iso <<< "$img_info"
    if is_stale "$repo" "$src_sha" "$src_ts" "$img_sha" "$img_ts"; then
      stale=$((stale + 1))
      printf 'STALE: %s was changed after %s was exported\n' "$source" "$image" >&2
      printf '    source last committed: %s (%s)\n' "$src_iso" "${src_sha:0:9}" >&2
      printf '    image  last committed: %s (%s)\n' "$img_iso" "${img_sha:0:9}" >&2
    fi
  done

  if [ "$stale" -gt 0 ]; then
    die "$stale diagram(s) were changed without re-exporting the image.
Open the diagram source, export it over the image next to it (same base name) and commit both files."
  fi

  printf 'All %s diagram(s) are exported up to date%s\n' \
    "$((count - skipped))" "$([ "$skipped" -eq 0 ] || printf ' (%s uncommitted pair(s) skipped)' "$skipped")"
}

case "${1:-}" in
  -h|--help|'')
    usage
    [ -n "${1:-}" ] || exit 1
    exit 0
    ;;
  sources) shift; list_sources "${1:?sources needs a tree directory}" ;;
  pairs)   shift; list_pairs   "${1:?pairs needs a tree directory}" ;;
  prune)   shift; prune_sources "${1:?prune needs a tree directory}" ;;
  check)   shift; check_tree "$@" ;;
  *)       die "unknown subcommand '$1' (use sources, pairs, prune or check)" ;;
esac
