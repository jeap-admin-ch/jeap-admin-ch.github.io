#!/usr/bin/env bash
#
# Assembly performed by scripts/clone-docs.sh.
#
# The script normally clones the jEAP org from GitHub, which no test should
# depend on. Instead it is pointed at throwaway local git repositories via
# REPO_BASE_URL="file://…" with AUTODISCOVER=false, so the real clone/copy/
# placement logic runs offline and without the gh CLI.
#
# What matters here is placement: which repo lands at the docs root, which
# becomes its own nested section, and how the README/index.md collision is
# resolved — get that wrong and prepare-docs.sh transforms the wrong tree.
#
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

command -v git >/dev/null || skip "git not available"

# An umbrella repo: docs/ with an _order manifest, copied to the docs root.
make_umbrella() {  # <dir>
  git_repo "$1" \
    'README.md=# Umbrella' \
    'docs/_order=what-is-jeap' \
    'docs/what-is-jeap.md=# What is jEAP' \
    'docs/building-blocks/index.md=# Building Blocks'
}

# A regular repo: README as landing page, docs/ as the subpages.
make_repo() {  # <dir>
  git_repo "$1" \
    'README.md=# Demo repo' \
    'docs/usage.md=# Usage' \
    'docs/deep/page.md=# Deep page'
}

test_a_root_placement_copies_the_repo_docs_to_the_docs_root() {
  make_umbrella "$TMP_DIR/src/umbrella"

  run_clone REPO_BASE_URL="file://$TMP_DIR/src" REPOS="umbrella:root" AUTODISCOVER=false

  assert_file "$(docs_dest)/_order"           'the order manifest lands at the root'
  assert_file "$(docs_dest)/what-is-jeap.md"
  assert_file "$(docs_dest)/building-blocks/index.md" 'subfolders are copied along'
  assert_no_file "$(docs_dest)/docs/what-is-jeap.md"  'no extra docs/ level is nested'
  assert_no_file "$(docs_dest)/README.md"             'only docs/ is copied, not the repo root'
}

test_a_nested_placement_copies_the_repo_docs_into_its_own_folder() {
  make_repo "$TMP_DIR/src/demo"

  run_clone REPO_BASE_URL="file://$TMP_DIR/src" REPOS="demo:nested" AUTODISCOVER=false

  assert_file "$(section_dir demo)/usage.md"
  assert_file "$(section_dir demo)/deep/page.md"
  # `nested` is the raw placement — the README-as-landing-page treatment is
  # auto-discovery's (and LOCAL_REPOS'), not this one's.
  assert_no_file "$(section_dir demo)/index.md"
}

test_the_destination_is_reset_on_every_run() {
  make_umbrella "$TMP_DIR/src/umbrella"
  doc stale/leftover.md <<<'# From a previous run'

  run_clone REPO_BASE_URL="file://$TMP_DIR/src" REPOS="umbrella:root" AUTODISCOVER=false

  assert_no_file "$(docs_dest)/stale/leftover.md" 'docs/ is generated content and must start clean'
  assert_file "$(docs_dest)/what-is-jeap.md"
}

test_an_unknown_placement_is_rejected() {
  make_repo "$TMP_DIR/src/demo"

  LAST_OUTPUT="$(env DOCS_DEST="$DOCS_DEST" REPO_BASE_URL="file://$TMP_DIR/src" \
    REPOS="demo:sideways" AUTODISCOVER=false bash "$SCRIPTS_DIR/clone-docs.sh" 2>&1)"
  local status=$?

  [ "$status" -ne 0 ] || fail "an unknown placement must fail the build, got status 0"
  assert_output "Unknown placement 'sideways'"
}

test_a_failing_clone_aborts_the_run() {
  LAST_OUTPUT="$(env DOCS_DEST="$DOCS_DEST" REPO_BASE_URL="file://$TMP_DIR/nowhere" \
    REPOS="missing:root" AUTODISCOVER=false bash "$SCRIPTS_DIR/clone-docs.sh" 2>&1)"
  local status=$?

  [ "$status" -ne 0 ] || fail "a failed clone must abort, got status 0"
  assert_output "git clone failed for 'missing'"
}

test_a_repo_without_docs_is_skipped_rather_than_failing() {
  git_repo "$TMP_DIR/src/bare" 'README.md=# No docs here'

  run_clone REPO_BASE_URL="file://$TMP_DIR/src" REPOS="bare:nested" AUTODISCOVER=false

  assert_output 'has no docs/ directory'
  assert_dir "$(docs_dest)" 'the run still completes'
}

test_the_branch_applies_to_the_static_manifest() {
  make_umbrella "$TMP_DIR/src/umbrella"
  git -C "$TMP_DIR/src/umbrella" checkout -q -b feature/test
  printf '# Only on the feature branch\n' > "$TMP_DIR/src/umbrella/docs/feature-page.md"
  git -C "$TMP_DIR/src/umbrella" add -A
  git -C "$TMP_DIR/src/umbrella" -c user.email=t@example.org -c user.name=Test commit -qm 'feature'
  git -C "$TMP_DIR/src/umbrella" checkout -q main

  run_clone REPO_BASE_URL="file://$TMP_DIR/src" REPOS="umbrella:root" \
            BRANCH="feature/test" AUTODISCOVER=false

  assert_file "$(docs_dest)/feature-page.md" 'BRANCH selects the branch to clone'
}

# ---------------------------------------------------------------------------
# LOCAL_REPOS — assembled from a working tree, not cloned (what --local backs)
# ---------------------------------------------------------------------------
test_a_local_repo_is_assembled_as_a_nested_section_with_the_readme_as_landing_page() {
  make_repo "$TMP_DIR/src/demo"
  # Uncommitted edits must be visible: that is the point of --local.
  printf '# Uncommitted\n' > "$TMP_DIR/src/demo/docs/scratch.md"

  run_clone LOCAL_REPOS="$TMP_DIR/src/demo" AUTODISCOVER=false REPOS=""

  assert_contains "$(section_dir demo)/index.md" '# Demo repo' 'the README becomes the landing page'
  assert_file "$(section_dir demo)/usage.md"
  assert_file "$(section_dir demo)/scratch.md" 'the working tree is used, uncommitted files included'
}

test_a_local_repo_shipping_its_own_docs_index_has_it_demoted() {
  git_repo "$TMP_DIR/src/demo" \
    'README.md=# Demo repo' \
    'docs/index.md=# Module overview' \
    'docs/usage.md=# Usage'

  run_clone LOCAL_REPOS="$TMP_DIR/src/demo" AUTODISCOVER=false REPOS=""

  # The README wins the index.md slot; the repo's own index is renamed, which is
  # what prepare-docs.sh's docs/index.md -> ./modules.md rewrite relies on.
  assert_contains "$(section_dir demo)/index.md"   '# Demo repo'
  assert_contains "$(section_dir demo)/modules.md" '# Module overview'
}

test_a_local_repo_with_an_order_manifest_is_placed_at_the_root() {
  make_umbrella "$TMP_DIR/src/umbrella"

  run_clone LOCAL_REPOS="$TMP_DIR/src/umbrella" AUTODISCOVER=false REPOS=""

  assert_file "$(docs_dest)/_order"          'an _order manifest selects root placement'
  assert_file "$(docs_dest)/what-is-jeap.md"
  assert_no_file "$(section_dir umbrella)/index.md" 'it must not also become a section'
}

# A local umbrella is the offline `--local <umbrella> --no-autodiscover` case:
# it must replace the static root clone, or the script would still hit GitHub.
test_a_local_umbrella_supersedes_the_static_root_manifest() {
  make_umbrella "$TMP_DIR/src/umbrella"

  run_clone LOCAL_REPOS="$TMP_DIR/src/umbrella" AUTODISCOVER=false \
            REPOS="jeap:root" REPO_BASE_URL="file://$TMP_DIR/nowhere"

  assert_output 'Skipping static manifest'
  assert_file "$(docs_dest)/what-is-jeap.md" 'the local checkout provided the root docs'
}

test_a_local_repo_without_docs_is_rejected() {
  git_repo "$TMP_DIR/src/bare" 'README.md=# No docs here'

  LAST_OUTPUT="$(env DOCS_DEST="$DOCS_DEST" LOCAL_REPOS="$TMP_DIR/src/bare" \
    AUTODISCOVER=false REPOS="" bash "$SCRIPTS_DIR/clone-docs.sh" 2>&1)"
  local status=$?

  [ "$status" -ne 0 ] || fail "a LOCAL_REPOS entry without docs/ must fail, got status 0"
  assert_output 'has no docs/ directory'
}

test_autodiscovery_stays_off_when_disabled() {
  make_umbrella "$TMP_DIR/src/umbrella"

  run_clone REPO_BASE_URL="file://$TMP_DIR/src" REPOS="umbrella:root" AUTODISCOVER=false

  assert_output 'assembling only the static REPOS manifest'
}

# ---------------------------------------------------------------------------
# The two steps together — what the deploy workflow actually runs.
# ---------------------------------------------------------------------------
test_clone_and_prepare_run_end_to_end() {
  make_umbrella "$TMP_DIR/src/umbrella"
  git_repo "$TMP_DIR/src/demo" \
    'README.md=# Demo repo

- [usage](docs/usage.md#setup)
- [build](build.gradle)

## License

Boilerplate.' \
    'docs/usage.md=# Usage' \
    'docs/getting-started.md=# Getting started'

  run_clone LOCAL_REPOS="$TMP_DIR/src/umbrella $TMP_DIR/src/demo" AUTODISCOVER=false REPOS=""
  run_prepare

  assert_contains "$(docs_dest)/what-is-jeap.md" 'sidebar_position: 1' 'umbrella ordering applied'
  local index; index="$(section_dir demo)/index.md"
  assert_link "$index" usage './usage.md#setup'
  assert_link "$index" build 'https://github.com/jeap-admin-ch/demo/blob/main/build.gradle'
  assert_not_contains "$index" '## License' 'README boilerplate truncated'
  assert_contains "$(section_dir demo)/getting-started.md" 'sidebar_position: 0'
  assert_json_field "$(section_dir demo)/_category_.json" label 'demo'
}

run_tests
