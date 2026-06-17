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
# The script assembles content from two sources:
#   1. The static REPOS manifest (the umbrella general doc, placed at root).
#   2. Auto-discovery: every repo in the GitHub org that ships a top-level docs/
#      directory on its main branch is pulled in as its own nested section
#      (docs/<repo>/), with the repo's README.md as the section landing page.
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
#                  Default: "jeap-governance-service jeap-python-pipeline-lib"
#
# Examples:
#   # Production: umbrella doc + all auto-discovered repos from GitHub (main):
#   bash scripts/clone-docs.sh
#
#   # Local test: clone the umbrella doc from a local checkout on a feature branch,
#   # without auto-discovery. The umbrella repo's directory there is named
#   # "jeap-admin-ch", so override REPOS:
#   REPO_BASE_URL="file:///home/dev/IdeaProjects" \
#   BRANCH="feature/JEAP-7069" \
#   REPOS="jeap-admin-ch:root" \
#   AUTODISCOVER=false \
#     bash scripts/clone-docs.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_BASE_URL="${REPO_BASE_URL:-https://github.com/jeap-admin-ch}"
BRANCH="${BRANCH:-main}"
REPOS="${REPOS:-jeap:root}"
DOCS_DEST="${DOCS_DEST:-$SITE_ROOT/docs}"
ORG="${ORG:-jeap-admin-ch}"
AUTODISCOVER="${AUTODISCOVER:-true}"
EXCLUDE_REPOS="${EXCLUDE_REPOS:-jeap-governance-service jeap-python-pipeline-lib}"

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

# Auto-discovered repos are always cloned from main and placed as their own
# nested section (docs/<repo>/). The repo's README.md becomes the section
# landing page (index.md); the repo's docs/ contents become the subpages. A
# repo that ships its own docs/index.md would collide with the README-derived
# index.md, so the former is demoted to modules.md.
aggregate_nested_repo() {
  local name="$1"
  local url="$REPO_BASE_URL/$name"
  local checkout="$WORK_DIR/$name"
  local dest="$DOCS_DEST/$name"

  log "Cloning $name (main) from $url"
  git clone --depth 1 --branch main "$url" "$checkout" \
    || die "git clone failed for '$name' @ 'main' from $url"

  if [ ! -d "$checkout/docs" ]; then
    warn "$name has no docs/ directory — skipping"
    return 0
  fi

  log "Placing $name docs/ under $dest/ (README as landing page)"
  mkdir -p "$dest"
  cp -R "$checkout/docs/." "$dest/"

  # README always wins the index.md slot; demote a repo-provided docs/index.md.
  if [ -f "$dest/index.md" ]; then
    mv "$dest/index.md" "$dest/modules.md"
  fi
  if [ -f "$checkout/README.md" ]; then
    cp "$checkout/README.md" "$dest/index.md"
  else
    warn "$name has no README.md — section will have no landing page"
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

for entry in $REPOS; do
  name="${entry%%:*}"
  placement="${entry##*:}"
  [ -n "$name" ] || continue
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

count="$(find "$DOCS_DEST" -name '*.md' | wc -l | tr -d ' ')"
log "Clone step complete: $count markdown file(s) assembled in $DOCS_DEST"
log "Next: run scripts/prepare-docs.sh to transform the content for GitHub Pages."
