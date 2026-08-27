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
# The script assembles content from three sources:
#   1. The static REPOS manifest (the umbrella general doc, placed at root).
#   2. Auto-discovery: every repo in the GitHub org that ships a top-level docs/
#      directory on its main branch is pulled in as its own nested section
#      (docs/<repo>/), with the repo's README.md as the section landing page.
#   3. JME auto-discovery: every repo in the jme-admin-ch org (jEAP Microservice
#      Examples) is pulled in as its own nested section under docs/jme-examples/,
#      README-only (no docs/ directory required — most JME repos don't have
#      one). The jme umbrella repo and .github are always skipped. See
#      JME_ORG/JME_DIR/AUTODISCOVER_JME/EXCLUDE_JME_REPOS below.
#
# Configuration (environment variables):
#   REPO_BASE_URL  Base URL/prefix the repos are cloned from.
#                  Default: https://github.com/jeap-admin-ch
#                  For local testing, point at a parent directory via file://, e.g.
#                    REPO_BASE_URL="file:///home/dev/IdeaProjects"
#   BRANCH         Branch to clone for the static REPOS manifest (the umbrella doc).
#                  Default: main. Auto-discovered repos always use main.
#   REPOS          Whitespace/newline separated manifest of "<name>:<placement>"
#                  entries, where placement is one of:
#                    root    -> the repo's docs/ is copied to the top level of docs/
#                    nested  -> the repo's docs/ is copied to docs/<name>/
#                  Default: "jeap:root"  (the umbrella repo holding the general doc)
#   DOCS_DEST      Destination docs directory. Default: <site-root>/docs
#   ORG            GitHub org to auto-discover repos from. Default: jeap-admin-ch
#   AUTODISCOVER   "true" to enumerate the org and pull in every repo with a docs/
#                  directory; "false" for umbrella-only (offline / no gh CLI).
#                  Default: true. Requires the `gh` CLI to be installed and
#                  authenticated (in CI set GH_TOKEN).
#   EXCLUDE_REPOS  Space-separated repo names to hold back from auto-discovery
#                  (e.g. repos whose docs/ layout does not yet match the
#                  authoritative jeap-spring-boot-jwe-starter shape).
#                  Default: "jeap-python-pipeline-lib"
#   LOCAL_REPOS    Space/newline separated list of paths to LOCAL repo checkouts.
#                  Each is assembled from its working tree (uncommitted edits
#                  included) instead of being cloned, and the same-named repo is
#                  skipped during auto-discovery so the local copy wins. The
#                  section name is the directory basename. Placement is detected
#                  from the checkout: a top-level docs/_order file (the umbrella's
#                  order manifest) means root placement; otherwise the repo is
#                  placed as its own nested section (docs/<name>/), README as the
#                  landing page — exactly like an auto-discovered repo.
#                  Default: empty.
#   JME_ORG        GitHub org to auto-discover JME example repos from.
#                  Default: jme-admin-ch
#   JME_REPO_BASE_URL  Base URL/prefix JME repos are cloned from.
#                  Default: https://github.com/<JME_ORG>
#   JME_DIR        Destination folder (under DOCS_DEST) JME repo sections are
#                  nested under. Default: jme-examples
#   AUTODISCOVER_JME  "true"/"false" for the JME auto-discovery pass. Default:
#                  same as AUTODISCOVER.
#   EXCLUDE_JME_REPOS  Space-separated JME repo names to hold back. The jme
#                  umbrella repo and .github are always skipped regardless.
#                  Default: empty.
#
# Examples:
#   # Production: umbrella doc + all auto-discovered repos from GitHub (main):
#   bash scripts/clone-docs.sh
#
#   # Local test: clone the umbrella doc from a local checkout on a feature branch,
#   # without auto-discovery. The umbrella repo's directory there is named
#   # "jeap-admin-ch", so override REPOS:
#   REPO_BASE_URL="file:///home/dev/IdeaProjects" \
#   BRANCH="feature/JEAP-xxxx" \
#   REPOS="jeap-admin-ch:root" \
#   AUTODISCOVER=false \
#     bash scripts/clone-docs.sh
#
#   # Full site from GitHub, but one section served from a local checkout you are
#   # editing (uncommitted edits visible), everything else auto-discovered:
#   LOCAL_REPOS="../jeap-spring-boot-starters" bash scripts/clone-docs.sh
#
set -euo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: bash scripts/clone-docs.sh

Step 1/2 of the docs pipeline: clone the jEAP source repos and assemble their
docs/ trees into this site's docs/ directory. Configured entirely via environment
variables (no flags). Run scripts/prepare-docs.sh afterwards.

Environment variables (defaults in brackets):
  REPO_BASE_URL   Base URL/prefix repos are cloned from.
                  [https://github.com/jeap-admin-ch] (file:// for local testing)
  BRANCH          Branch for the static REPOS manifest only. [main]
  REPOS           Whitespace-separated "<name>:<placement>" manifest, placement
                  root|nested. [jeap:root]
  DOCS_DEST       Destination docs directory. [<site-root>/docs]
  ORG             GitHub org to auto-discover repos from. [jeap-admin-ch]
  AUTODISCOVER    true = enumerate the org and pull in every repo with a docs/
                  dir; false = umbrella-only (offline, no gh CLI). [true]
  EXCLUDE_REPOS   Space-separated repo names to hold back from auto-discovery.
                  [jeap-python-pipeline-lib]
  LOCAL_REPOS     Space-separated paths to LOCAL repo checkouts, assembled from
                  their working tree (uncommitted edits included) instead of
                  cloned; the same-named repo is skipped during auto-discovery so
                  the local copy wins. Section name = directory basename; a
                  checkout whose docs/ ships an _order manifest lands at the site
                  root, others as nested sections. []
  JME_ORG         GitHub org to auto-discover JME example repos from. [jme-admin-ch]
  JME_REPO_BASE_URL  Base URL/prefix JME repos are cloned from. [https://github.com/<JME_ORG>]
  JME_DIR         Destination folder JME repo sections nest under. [jme-examples]
  AUTODISCOVER_JME  true/false for the JME auto-discovery pass. [same as AUTODISCOVER]
  EXCLUDE_JME_REPOS  Space-separated JME repo names to hold back. []

Examples:
  bash scripts/clone-docs.sh
  LOCAL_REPOS="../jeap-spring-boot-starters" bash scripts/clone-docs.sh
  REPO_BASE_URL="file:///home/dev/IdeaProjects" BRANCH="feature/X" \
    REPOS="jeap-admin-ch:root" AUTODISCOVER=false bash scripts/clone-docs.sh
EOF
    exit 0
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_BASE_URL="${REPO_BASE_URL:-https://github.com/jeap-admin-ch}"
BRANCH="${BRANCH:-main}"
REPOS="${REPOS:-jeap:root}"
DOCS_DEST="${DOCS_DEST:-$SITE_ROOT/docs}"
ORG="${ORG:-jeap-admin-ch}"
AUTODISCOVER="${AUTODISCOVER:-true}"
EXCLUDE_REPOS="${EXCLUDE_REPOS:-jeap-python-pipeline-lib}"
LOCAL_REPOS="${LOCAL_REPOS:-}"

# JME (jEAP Microservice Examples) org — a second, independent auto-discovery
# pass, since its repos mostly ship only a README (no docs/ dir). Placed under
# its own top-level section (JME_DIR), README-only. AUTODISCOVER_JME defaults
# to AUTODISCOVER so it stays offline-friendly for the same local test runs.
JME_ORG="${JME_ORG:-jme-admin-ch}"
JME_REPO_BASE_URL="${JME_REPO_BASE_URL:-https://github.com/$JME_ORG}"
JME_DIR="${JME_DIR:-jme-examples}"
AUTODISCOVER_JME="${AUTODISCOVER_JME:-$AUTODISCOVER}"
# Repos never auto-discovered from the JME org: the umbrella repo (jme, just a
# curated list of the others) and the org profile repo.
JME_STRUCTURAL_SKIP="jme .github"
EXCLUDE_JME_REPOS="${EXCLUDE_JME_REPOS:-}"

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

# Place a repo checkout as its own nested section (<dest-parent>/<name>/). The
# repo's README.md becomes the section landing page (index.md); if the repo
# ships a docs/ directory its contents become the subpages (a repo that also
# ships its own docs/index.md would collide with the README-derived index.md,
# so the former is demoted to modules.md). A repo with no docs/ directory gets
# a README-only section (index.md, no subpages). Shared by auto-discovery
# (from a clone) and LOCAL_REPOS (from a working-tree checkout).
place_nested_from_checkout() {
  local name="$1" checkout="$2" dest_parent="${3:-$DOCS_DEST}"
  local dest="$dest_parent/$name"

  mkdir -p "$dest"
  if [ -d "$checkout/docs" ]; then
    log "Placing $name docs/ under $dest/ (README as landing page)"
    cp -R "$checkout/docs/." "$dest/"
    # README always wins the index.md slot; demote a repo-provided docs/index.md.
    if [ -f "$dest/index.md" ]; then
      mv "$dest/index.md" "$dest/modules.md"
    fi
  else
    log "Placing $name under $dest/ (README-only, no docs/ directory)"
  fi

  if [ -f "$checkout/README.md" ]; then
    cp "$checkout/README.md" "$dest/index.md"
  else
    warn "$name has no README.md — section will have no landing page"
  fi
}

# Auto-discovered repos are always cloned from main and placed as their own
# nested section via place_nested_from_checkout. require_docs="true" (the
# default) skips repos with no docs/ directory, as used by the jeap-admin-ch
# auto-discovery pass; pass "false" to also accept README-only repos (used by
# the JME examples pass, where README-only is the norm).
aggregate_nested_repo() {
  local name="$1" base_url="${2:-$REPO_BASE_URL}" dest_parent="${3:-$DOCS_DEST}" require_docs="${4:-true}"
  local url="$base_url/$name"
  local checkout="$WORK_DIR/$name"

  log "Cloning $name (main) from $url"
  git clone --depth 1 --branch main "$url" "$checkout" \
    || die "git clone failed for '$name' @ 'main' from $url"

  if [ "$require_docs" = "true" ] && [ ! -d "$checkout/docs" ]; then
    warn "$name has no docs/ directory — skipping"
    return 0
  fi

  place_nested_from_checkout "$name" "$checkout" "$dest_parent"
}

# Assemble a repo from a LOCAL checkout (working tree, uncommitted edits
# included) instead of cloning it. The section name is the directory basename.
# A top-level docs/_order file (the umbrella's order manifest) selects root
# placement; otherwise the repo is placed as its own nested section.
aggregate_local_repo() {
  local path="$1"
  [ -d "$path/docs" ] || die "LOCAL_REPOS entry '$path' has no docs/ directory"
  local name; name="$(basename "$path")"

  if [ -f "$path/docs/_order" ]; then
    log "Placing LOCAL $name docs/ at the top level of $DOCS_DEST (working tree, incl. uncommitted changes)"
    cp -R "$path/docs/." "$DOCS_DEST/"
  else
    log "Placing LOCAL $name docs/ as a nested section (working tree, incl. uncommitted changes)"
    place_nested_from_checkout "$name" "$path"
  fi
}

# Is repo $1 listed in the static REPOS manifest? (Those are handled above.)
in_static_manifest() {
  local needle="$1" entry
  for entry in $REPOS; do
    [ "${entry%%:*}" = "$needle" ] && return 0
  done
  return 1
}

# Is repo $1 in the EXCLUDE_REPOS hold-back list?
is_excluded() {
  local needle="$1" r
  for r in $EXCLUDE_REPOS; do
    [ "$r" = "$needle" ] && return 0
  done
  return 1
}

# Is repo $1 provided by a LOCAL_REPOS checkout? (Matched by directory basename.)
is_local() {
  local needle="$1" path
  for path in $LOCAL_REPOS; do
    [ "$(basename "$path")" = "$needle" ] && return 0
  done
  return 1
}

# Does any LOCAL_REPOS checkout resolve to root placement (umbrella / _order)?
# Such a local override replaces the default static root manifest clone.
local_has_root=false
for path in $LOCAL_REPOS; do
  if [ -f "$path/docs/_order" ]; then
    local_has_root=true
    break
  fi
done

# Local overrides first: a local root override (umbrella) replaces the static
# root manifest clone below; nested locals are skipped during auto-discovery.
for path in $LOCAL_REPOS; do
  [ -n "$path" ] || continue
  aggregate_local_repo "$path"
done

for entry in $REPOS; do
  name="${entry%%:*}"
  placement="${entry##*:}"
  [ -n "$name" ] || continue
  # A local umbrella (root placement via _order) supersedes the static root clone.
  if [ "$placement" = "root" ] && [ "$local_has_root" = "true" ]; then
    log "Skipping static manifest '$name' (root docs provided by a LOCAL_REPOS checkout)"
    continue
  fi
  aggregate_one "$name" "$placement"
done

# ---------------------------------------------------------------------------
# Auto-discovery: enumerate the org and pull in every repo (on main) that has a
# top-level docs/ directory, skipping structural repos, the umbrella, the
# static manifest and the EXCLUDE_REPOS hold-back list.
# ---------------------------------------------------------------------------
if [ "$AUTODISCOVER" = "true" ]; then
  if ! command -v gh >/dev/null; then
    warn "AUTODISCOVER=true but the gh CLI is not available — skipping auto-discovery"
  else
    # Repos never auto-discovered regardless of docs/ presence.
    structural_skip="jeap jeap-admin-ch.github.io .github repository-mirroring"
    log "Auto-discovering repos with docs/ in org '$ORG'"

    # Names of non-empty repos whose default branch is main.
    discovered="$(gh repo list "$ORG" --limit 300 \
      --json name,isEmpty,defaultBranchRef \
      --jq '.[] | select(.isEmpty == false) | select(.defaultBranchRef.name == "main") | .name' \
      | tr -d '\r')"

    while IFS= read -r name; do
      [ -n "$name" ] || continue
      case " $structural_skip " in *" $name "*) continue ;; esac
      in_static_manifest "$name" && continue
      if is_local "$name"; then
        log "Skipping $name (provided by a LOCAL_REPOS checkout)"
        continue
      fi
      if is_excluded "$name"; then
        log "Skipping $name (in EXCLUDE_REPOS)"
        continue
      fi
      # Probe for a top-level docs/ tree before cloning.
      if [ -z "$(gh api "repos/$ORG/$name/git/trees/main" \
            --jq '.tree[] | select(.path == "docs" and .type == "tree") | .path' \
            2>/dev/null | tr -d '\r')" ]; then
        continue
      fi
      aggregate_nested_repo "$name"
    done <<EOF
$discovered
EOF
  fi
else
  log "AUTODISCOVER=false — assembling only the static REPOS manifest"
fi

# ---------------------------------------------------------------------------
# JME auto-discovery: a second, independent org (jme-admin-ch, jEAP Microservice
# Examples). Unlike the jeap-admin-ch pass above, README-only repos (no docs/)
# are accepted — that's the norm here — and repos land nested under JME_DIR
# (e.g. docs/jme-examples/<repo>/) instead of the site's top level, so they form
# their own separate sidebar section. The umbrella repo (jme) and the org
# profile repo (.github) are always skipped (JME_STRUCTURAL_SKIP); an empty
# repo (no commits at all) is skipped too since there is nothing to clone.
# ---------------------------------------------------------------------------
if [ "$AUTODISCOVER_JME" = "true" ]; then
  if ! command -v gh >/dev/null; then
    warn "AUTODISCOVER_JME=true but the gh CLI is not available — skipping JME auto-discovery"
  else
    log "Auto-discovering repos in org '$JME_ORG' (README-only accepted)"
    mkdir -p "$DOCS_DEST/$JME_DIR"

    discovered_jme="$(gh repo list "$JME_ORG" --limit 300 \
      --json name,isEmpty,defaultBranchRef \
      --jq '.[] | select(.isEmpty == false) | select(.defaultBranchRef.name == "main") | .name' \
      | tr -d '\r')"

    while IFS= read -r name; do
      [ -n "$name" ] || continue
      case " $JME_STRUCTURAL_SKIP " in *" $name "*) continue ;; esac
      case " $EXCLUDE_JME_REPOS " in *" $name "*) log "Skipping $name (in EXCLUDE_JME_REPOS)"; continue ;; esac
      aggregate_nested_repo "$name" "$JME_REPO_BASE_URL" "$DOCS_DEST/$JME_DIR" false
    done <<EOF
$discovered_jme
EOF
  fi
else
  log "AUTODISCOVER_JME=false — skipping JME examples"
fi

count="$(find "$DOCS_DEST" -name '*.md' | wc -l | tr -d ' ')"
log "Clone step complete: $count markdown file(s) assembled in $DOCS_DEST"
log "Next: run scripts/prepare-docs.sh to transform the content for GitHub Pages."
