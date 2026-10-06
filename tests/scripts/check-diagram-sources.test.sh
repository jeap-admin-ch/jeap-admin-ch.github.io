#!/usr/bin/env bash
#
# The diagram source/image pairing enforced by scripts/check-diagram-sources.sh.
#
# A jEAP diagram is two committed files: the editable source (images/x.drawio)
# and the image exported from it by hand (images/x.svg). Two things can go wrong
# and both are silent, which is why they are tested here rather than left to the
# site build: the author forgets to re-export, so the published page keeps the
# old picture; or the source file is published alongside the image, which nobody
# can open in a browser.
#
# The git cases build real repositories with real commits — the dating logic is
# the part that is easy to get wrong (and easy to get wrong in a way that always
# passes), so none of it is stubbed.
#
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

command -v git >/dev/null || skip "git not available"

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

# Write a file below <dir>, creating parent directories.
put() {  # <dir> <relative-path> <content>
  mkdir -p "$1/$(dirname "$2")"
  printf '%s\n' "$3" > "$1/$2"
}

# Commit everything in <repo>.
commit() {  # <repo> <message>
  git -C "$1" add -A
  git -C "$1" -c user.email=t@example.org -c user.name=Test commit -qm "$2"
}

# A repo whose docs/ holds one diagram, source and image committed together.
diagram_repo() {  # <dir>
  local dir="$1"
  put "$dir" README.md '# Diagram repo'
  put "$dir" docs/architecture.md '# Architecture
![Overview](images/overview.svg)'
  put "$dir" docs/images/overview.drawio '<mxfile><diagram>v1</diagram></mxfile>'
  put "$dir" docs/images/overview.svg '<svg>v1</svg>'
  git -C "$dir" init -q -b main
  commit "$dir" 'the diagram and its export'
}

# Edit the diagram source and commit it alone — the mistake the check exists for.
edit_source_only() {  # <repo>
  put "$1" docs/images/overview.drawio '<mxfile><diagram>v2</diagram></mxfile>'
  commit "$1" 'reworked the diagram'
}

# Add <n> unrelated commits, so the diagram ends up beyond a depth-1 clone.
add_history() {  # <repo> <n>
  local i
  for i in $(seq 1 "$2"); do
    put "$1" docs/changelog.md "# Changelog
entry $i"
    commit "$1" "entry $i"
  done
}

# ---------------------------------------------------------------------------
# The pairing rule (`sources` / `pairs`) — pure name analysis, no git
# ---------------------------------------------------------------------------

test_a_file_extending_an_image_name_is_the_images_source() {
  local tree="$TMP_DIR/tree"
  put "$tree" images/overview.drawio 'source'
  put "$tree" images/overview.svg '<svg/>'

  run_check sources "$tree"

  assert_status 0
  assert_eq 'images/overview.drawio' "$LAST_OUTPUT" 'the .drawio next to the .svg is the source'
}

test_a_source_with_a_double_extension_is_paired_with_its_image() {
  local tree="$TMP_DIR/tree"
  # The shape of the diagrams migrated from the Confluence draw.io plugin.
  put "$tree" images/flow.drawio.xml 'source'
  put "$tree" images/flow.png 'PNG'

  run_check pairs "$tree"

  assert_status 0
  assert_eq 'images/flow.drawio.xml images/flow.png' "$LAST_OUTPUT" \
    'the stem of flow.png is extended by flow.drawio.xml'
}

test_a_published_asset_next_to_an_image_is_not_treated_as_a_source() {
  local tree="$TMP_DIR/tree"
  # Both of these are extensions the doc service publishes, so neither is
  # somebody's unopenable editor file — dropping one would lose a real asset.
  put "$tree" images/report.pdf 'PDF'
  put "$tree" images/report.svg '<svg/>'
  put "$tree" images/logo.png 'PNG'
  put "$tree" images/logo.svg '<svg/>'

  run_check sources "$tree"

  assert_status 0
  assert_eq '' "$LAST_OUTPUT" 'a .pdf and a second image are assets of their own'
}

test_the_most_specific_image_claims_a_source() {
  local tree="$TMP_DIR/tree"
  put "$tree" images/flow.svg '<svg/>'
  put "$tree" images/flow.detail.svg '<svg/>'
  put "$tree" images/flow.detail.drawio 'source'

  run_check pairs "$tree"

  assert_status 0
  assert_eq 'images/flow.detail.drawio images/flow.detail.svg' "$LAST_OUTPUT" \
    'flow.detail.drawio belongs to flow.detail.svg, not to flow.svg'
}

test_an_image_in_another_folder_does_not_claim_a_source() {
  local tree="$TMP_DIR/tree"
  put "$tree" images/overview.svg '<svg/>'
  put "$tree" sources/overview.drawio 'source'

  run_check sources "$tree"

  assert_status 0
  assert_eq '' "$LAST_OUTPUT" 'the pairing is per folder — the author put them apart on purpose'
}

test_a_file_without_an_extension_is_never_a_source() {
  local tree="$TMP_DIR/tree"
  put "$tree" images/overview.svg '<svg/>'
  put "$tree" images/overview 'no extension'

  run_check sources "$tree"

  assert_status 0
  assert_eq '' "$LAST_OUTPUT" 'the name has to EXTEND the image stem'
}

# ---------------------------------------------------------------------------
# prune — what reaches the published site
# ---------------------------------------------------------------------------

test_prune_removes_the_sources_and_keeps_the_images() {
  local tree="$TMP_DIR/tree"
  put "$tree" images/overview.drawio 'source'
  put "$tree" images/overview.svg '<svg/>'
  put "$tree" images/flow.drawio.xml 'source'
  put "$tree" images/flow.png 'PNG'
  put "$tree" images/report.pdf 'PDF'
  put "$tree" architecture.md '# Architecture'

  run_check prune "$tree"

  assert_status 0
  assert_no_file "$tree/images/overview.drawio" 'the editor file is not publishable content'
  assert_no_file "$tree/images/flow.drawio.xml"
  assert_file "$tree/images/overview.svg" 'the exported picture is what the page shows'
  assert_file "$tree/images/flow.png"
  assert_file "$tree/images/report.pdf" 'a published asset is left alone'
  assert_file "$tree/architecture.md"
  assert_output 'Pruned 2 diagram source(s)'
}

test_prune_on_a_tree_without_diagrams_changes_nothing() {
  local tree="$TMP_DIR/tree"
  put "$tree" architecture.md '# Architecture'
  put "$tree" images/logo.png 'PNG'

  run_check prune "$tree"

  assert_status 0
  assert_file "$tree/images/logo.png"
  assert_eq '' "$LAST_OUTPUT" 'nothing to report when there is nothing to prune'
}

# ---------------------------------------------------------------------------
# check — the commit dates
# ---------------------------------------------------------------------------

test_a_diagram_committed_together_with_its_export_passes() {
  diagram_repo "$TMP_DIR/repo"

  run_check check "$TMP_DIR/repo"

  assert_status 0
  assert_output 'All 1 diagram(s) are exported up to date'
}

test_a_source_committed_after_its_image_fails_the_check() {
  diagram_repo "$TMP_DIR/repo"
  edit_source_only "$TMP_DIR/repo"

  run_check check "$TMP_DIR/repo"

  assert_status 1
  assert_output 'STALE: images/overview.drawio was changed after images/overview.svg was exported'
  assert_output 'export it over the image next to it'
}

test_re_exporting_the_image_makes_the_check_pass_again() {
  diagram_repo "$TMP_DIR/repo"
  edit_source_only "$TMP_DIR/repo"
  put "$TMP_DIR/repo" docs/images/overview.svg '<svg>v2</svg>'
  commit "$TMP_DIR/repo" 'exported the reworked diagram'

  run_check check "$TMP_DIR/repo"

  assert_status 0
  assert_output 'All 1 diagram(s) are exported up to date'
}

test_a_repo_without_diagrams_is_passed_without_a_word() {
  local repo="$TMP_DIR/repo"
  put "$repo" README.md '# Plain repo'
  put "$repo" docs/usage.md '# Usage'
  put "$repo" docs/images/logo.png 'PNG'
  git -C "$repo" init -q -b main
  commit "$repo" 'docs'

  run_check check "$repo"

  assert_status 0
  assert_eq '' "$LAST_OUTPUT" 'no pair, nothing to say — and no git work done'
}

test_an_uncommitted_pair_is_reported_and_skipped() {
  local repo="$TMP_DIR/repo"
  put "$repo" README.md '# Repo'
  put "$repo" docs/usage.md '# Usage'
  git -C "$repo" init -q -b main
  commit "$repo" 'docs'
  # A diagram being added right now: there is nothing to compare yet, and
  # refusing it would make the check impossible to work with locally.
  put "$repo" docs/images/new.drawio 'source'
  put "$repo" docs/images/new.svg '<svg/>'

  run_check check "$repo"

  assert_status 0
  assert_output 'is not committed yet'
}

test_a_tree_with_a_pair_outside_a_git_repository_is_refused() {
  local tree="$TMP_DIR/plain"
  put "$tree" docs/images/overview.drawio 'source'
  put "$tree" docs/images/overview.svg '<svg/>'

  run_check check "$tree"

  assert_status 1
  assert_output 'is not a git repository, so the export cannot be verified'
}

test_a_subdirectory_other_than_docs_can_be_checked() {
  local repo="$TMP_DIR/repo"
  put "$repo" generated/images/overview.drawio 'source'
  put "$repo" generated/images/overview.svg '<svg/>'
  git -C "$repo" init -q -b main
  commit "$repo" 'generated docs'
  put "$repo" generated/images/overview.drawio 'changed'
  commit "$repo" 'reworked'

  run_check check "$repo" generated

  assert_status 1
  assert_output 'STALE: images/overview.drawio'
}

# ---------------------------------------------------------------------------
# Shallow clones — where a date check silently stops working
# ---------------------------------------------------------------------------

test_a_shallow_clone_holding_a_diagram_is_refused_rather_than_passed() {
  diagram_repo "$TMP_DIR/src/repo"
  edit_source_only "$TMP_DIR/src/repo"
  add_history "$TMP_DIR/src/repo" 3
  git clone -q --depth 1 "file://$TMP_DIR/src/repo" "$TMP_DIR/shallow"

  run_check check "$TMP_DIR/shallow"

  # Without the history every file dates to the boundary commit, so the stale
  # diagram would look as old as its image and sail through.
  assert_status 1
  assert_output 'does not reach back to the commits that last touched'
}

test_deepen_fetches_enough_history_to_catch_a_stale_diagram() {
  diagram_repo "$TMP_DIR/src/repo"
  edit_source_only "$TMP_DIR/src/repo"
  add_history "$TMP_DIR/src/repo" 3
  git clone -q --depth 1 "file://$TMP_DIR/src/repo" "$TMP_DIR/shallow"

  run_check check --deepen "$TMP_DIR/shallow"

  assert_status 1
  assert_output 'Deepening shallow'
  assert_output 'STALE: images/overview.drawio was changed after images/overview.svg was exported'
}

test_deepen_passes_a_shallow_clone_whose_diagram_is_up_to_date() {
  diagram_repo "$TMP_DIR/src/repo"
  add_history "$TMP_DIR/src/repo" 3
  git clone -q --depth 1 "file://$TMP_DIR/src/repo" "$TMP_DIR/shallow"

  run_check check --deepen "$TMP_DIR/shallow"

  assert_status 0
  assert_output 'All 1 diagram(s) are exported up to date'
}

test_deepen_leaves_a_repo_without_diagrams_at_depth_one() {
  local src="$TMP_DIR/src/repo"
  put "$src" README.md '# Plain repo'
  put "$src" docs/usage.md '# Usage'
  git -C "$src" init -q -b main
  commit "$src" 'docs'
  add_history "$src" 5
  git clone -q --depth 1 "file://$src" "$TMP_DIR/shallow"

  run_check check --deepen "$TMP_DIR/shallow"

  assert_status 0
  # The whole point of deepening per repo: the site build clones ~70 repos and
  # must not pay for history it has no question about.
  assert_eq 'true' "$(git -C "$TMP_DIR/shallow" rev-parse --is-shallow-repository)" \
    'a repo without a diagram is never deepened'
  assert_eq '1' "$(git -C "$TMP_DIR/shallow" rev-list --count HEAD)" \
    'and keeps its single commit'
}

test_whitespace_paths_are_checked_and_pruned_without_splitting() {
  local repo="$TMP_DIR/repo" name=$'images with spaces/overview\twith\nwhitespace'
  put "$repo" "$name.drawio" 'original'
  put "$repo" "$name.svg" '<svg/>'
  git -C "$repo" init -q -b main
  GIT_AUTHOR_DATE=2026-01-01T12:00:00Z GIT_COMMITTER_DATE=2026-01-01T12:00:00Z commit "$repo" 'paired'
  run_check check "$repo" .
  assert_status 0
  put "$repo" "$name.drawio" 'changed'
  GIT_AUTHOR_DATE=2026-01-02T12:00:00Z GIT_COMMITTER_DATE=2026-01-02T12:00:00Z commit "$repo" 'stale'
  run_check check "$repo" .
  assert_status 1
  assert_output 'STALE:'
  run_check prune "$repo"
  assert_status 0
  assert_no_file "$repo/$name.drawio"
  assert_file "$repo/$name.svg"
}

test_shallow_linked_worktree_is_deepened() {
  diagram_repo "$TMP_DIR/source"
  edit_source_only "$TMP_DIR/source"
  git clone -q --depth 1 "file://$TMP_DIR/source" "$TMP_DIR/clone"
  git -C "$TMP_DIR/clone" worktree add --detach "$TMP_DIR/linked" HEAD
  run_check check "$TMP_DIR/linked"
  assert_status 1
  assert_output 'does not reach back'
  run_check check --deepen "$TMP_DIR/linked"
  assert_status 1
  assert_output 'STALE:'
}

run_tests
