#!/usr/bin/env bash
#
# Sidebar structure produced by scripts/prepare-docs.sh: the _order manifest,
# the _categories routing manifest, the getting-started pin, and idempotency.
#
# The ordering lives in manifests shipped by the umbrella repo, so the site
# build is the only thing that reads them — a malformed entry or an off-by-one
# position is invisible until the sidebar renders wrong. These tests assert the
# metadata the script writes, straight from fixture manifests.
#
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# The curated umbrella content: an _order manifest plus the pages it names.
umbrella_fixture() {
  doc _order <<'MD'
# A comment line, ignored.

what-is-jeap
using-jeap
building-blocks | App Building Blocks
MD
  doc what-is-jeap.md  <<<'# What is jEAP'
  doc using-jeap.md    <<<'# Using jEAP'
  doc building-blocks/index.md <<<'# App Building Blocks'
}

# ---------------------------------------------------------------------------
# _order — the umbrella's top-level sidebar manifest
# ---------------------------------------------------------------------------
test_order_manifest_positions_files_and_folders() {
  umbrella_fixture
  run_prepare

  assert_contains "$(docs_dest)/what-is-jeap.md" 'sidebar_position: 1' 'first entry'
  assert_contains "$(docs_dest)/using-jeap.md"   'sidebar_position: 2' 'second entry'

  local cat; cat="$(docs_dest)/building-blocks/_category_.json"
  assert_json_field "$cat" label    'App Building Blocks'
  assert_json_field "$cat" position 3
  # Top-level categories render expanded.
  assert_json_field "$cat" collapsed false
}

test_order_manifest_ignores_comments_blanks_and_md_suffix() {
  doc _order <<'MD'
# leading comment

  what-is-jeap
using-jeap.md      # trailing comment

MD
  doc what-is-jeap.md <<<'# What is jEAP'
  doc using-jeap.md   <<<'# Using jEAP'

  run_prepare

  # Comment-only and blank lines must not consume a position.
  assert_contains "$(docs_dest)/what-is-jeap.md" 'sidebar_position: 1' 'surrounding whitespace trimmed'
  assert_contains "$(docs_dest)/using-jeap.md"   'sidebar_position: 2' 'a .md suffix is tolerated'
}

test_order_manifest_derives_a_folder_label_when_none_is_given() {
  doc _order <<<'app_building-blocks'
  doc app_building-blocks/index.md <<<'# Section'

  run_prepare

  assert_json_field "$(docs_dest)/app_building-blocks/_category_.json" label 'App Building Blocks'
}

test_source_front_matter_wins_over_the_order_manifest() {
  doc _order <<<'what-is-jeap'
  doc what-is-jeap.md <<'MD'
---
sidebar_position: 42
title: Kept
---

# What is jEAP
MD

  run_prepare

  local page; page="$(docs_dest)/what-is-jeap.md"
  assert_contains "$page" 'sidebar_position: 42' 'source front matter must be left alone'
  assert_not_contains "$page" 'sidebar_position: 1'
}

test_a_missing_manifest_entry_warns_instead_of_failing() {
  doc _order <<'MD'
what-is-jeap
does-not-exist
MD
  doc what-is-jeap.md <<<'# What is jEAP'

  run_prepare

  assert_output "manifest entry 'does-not-exist' not found"
  assert_contains "$(docs_dest)/what-is-jeap.md" 'sidebar_position: 1' 'other entries still applied'
}

test_a_missing_manifest_warns_and_leaves_the_tree_alone() {
  doc what-is-jeap.md <<<'# What is jEAP'

  run_prepare

  assert_output 'no manifest at'
  assert_not_contains "$(docs_dest)/what-is-jeap.md" 'sidebar_position'
}

test_manifest_folders_are_not_treated_as_repo_sections() {
  doc _order <<<'using-jeap'
  doc using-jeap/index.md <<'MD'
# Using jEAP

## License

Curated content keeps its own License section.
MD

  run_prepare

  local index; index="$(docs_dest)/using-jeap/index.md"
  assert_contains "$index" '## License' 'curated sections must not get the README truncation'
  assert_json_field "$(docs_dest)/using-jeap/_category_.json" label 'Using Jeap'
}

# ---------------------------------------------------------------------------
# Repo sections without a _categories manifest — flat, positions 100+
# ---------------------------------------------------------------------------
test_repo_sections_sort_after_the_curated_content() {
  umbrella_fixture
  repo_section zeta-repo  <<<'# Zeta'
  repo_section alpha-repo <<<'# Alpha'

  run_prepare

  # Alphabetical, stepping by 10, starting after the manifest positions.
  assert_json_field "$(section_dir alpha-repo)/_category_.json" position 100
  assert_json_field "$(section_dir zeta-repo)/_category_.json"  position 110
  assert_json_field "$(section_dir alpha-repo)/_category_.json" label 'alpha-repo'
}

test_a_folder_without_an_index_is_not_a_repo_section() {
  doc loose/page.md <<<'# Just a page'

  run_prepare

  assert_no_file "$(docs_dest)/loose/_category_.json" 'no index.md means no repo section'
}

# ---------------------------------------------------------------------------
# _categories — routing repo sections into App Building Blocks subcategories
# ---------------------------------------------------------------------------
categories_fixture() {
  umbrella_fixture
  doc _categories <<'MD'
# Subcategories, in sidebar order:
libraries              | Libraries
spring-boot-starters   | Spring Boot Starters
tooling                | Tooling & Registries

jeap-audit         = library
jeap-cli           = tool
jeap-explicit-name = spring-boot-starters
MD
}

test_categories_manifest_defines_subcategories_in_order() {
  categories_fixture
  run_prepare

  local bb; bb="$(docs_dest)/building-blocks"
  assert_json_field "$bb/libraries/_category_.json"            label    'Libraries'
  assert_json_field "$bb/libraries/_category_.json"            position 1
  assert_json_field "$bb/spring-boot-starters/_category_.json" position 2
  assert_json_field "$bb/tooling/_category_.json"              label    'Tooling & Registries'
  assert_json_field "$bb/tooling/_category_.json"              position 3
  # A declared subcategory with no folder gets a stub landing page.
  assert_file "$bb/tooling/index.md" 'declared subcategory needs a landing page'
}

test_routing_lines_move_repo_sections_into_their_subcategory() {
  categories_fixture
  repo_section jeap-audit <<<'# Audit'
  repo_section jeap-cli   <<<'# CLI'
  repo_section jeap-explicit-name <<<'# Explicit'

  run_prepare

  local bb; bb="$(docs_dest)/building-blocks"
  assert_dir "$bb/libraries/jeap-audit"                 'library alias routes to libraries'
  assert_dir "$bb/tooling/jeap-cli"                     'tool alias routes to tooling'
  assert_dir "$bb/spring-boot-starters/jeap-explicit-name" 'a folder name may be used directly'
  assert_no_file "$(section_dir jeap-audit)/index.md"   'the section must be moved, not copied'
}

test_unrouted_repos_fall_back_to_the_name_based_default() {
  categories_fixture
  repo_section jeap-something-starter <<<'# Starter'
  repo_section jeap-something-else    <<<'# Other'

  run_prepare

  local bb; bb="$(docs_dest)/building-blocks"
  assert_dir "$bb/spring-boot-starters/jeap-something-starter" 'a *starter* name defaults to starters'
  assert_dir "$bb/libraries/jeap-something-else"               'anything else defaults to libraries'
}

test_repos_are_numbered_per_subcategory() {
  categories_fixture
  repo_section jeap-audit <<<'# Audit'
  repo_section jeap-cli   <<<'# CLI'
  repo_section jeap-zzz   <<<'# Another library'

  run_prepare

  local bb; bb="$(docs_dest)/building-blocks"
  # Each subcategory counts from 100 independently.
  assert_json_field "$bb/libraries/jeap-audit/_category_.json" position 100
  assert_json_field "$bb/libraries/jeap-zzz/_category_.json"   position 110
  assert_json_field "$bb/tooling/jeap-cli/_category_.json"     position 100
}

test_a_route_to_an_undeclared_subcategory_is_created_and_labelled() {
  umbrella_fixture
  doc _categories <<'MD'
libraries | Libraries

jeap-audit = brand-new-bucket
MD
  repo_section jeap-audit <<<'# Audit'

  run_prepare

  local cat; cat="$(docs_dest)/building-blocks/brand-new-bucket/_category_.json"
  assert_json_field "$cat" label    'Brand New Bucket'
  assert_json_field "$cat" position 90
  assert_file "$(docs_dest)/building-blocks/brand-new-bucket/index.md"
  assert_dir  "$(docs_dest)/building-blocks/brand-new-bucket/jeap-audit"
}

test_unrecognized_category_lines_are_reported() {
  umbrella_fixture
  doc _categories <<'MD'
libraries | Libraries
this line has neither separator
MD

  run_prepare

  assert_output 'ignoring unrecognized line'
}

# Inbound links to a routed repo must follow it to its nested path, so curated
# content can keep linking to /docs/<repo> regardless of how it is bucketed.
test_links_to_routed_repos_follow_them_into_the_subcategory() {
  categories_fixture
  repo_section jeap-audit <<<'# Audit'
  doc using-jeap.md <<'MD'
# Using jEAP

- [section](/docs/jeap-audit/)
- [page](/docs/jeap-audit/page)
- [bare](/docs/jeap-audit)
- [absolute](https://jeap-admin-ch.github.io/docs/jeap-audit/page)
- [lookalike](/docs/jeap-audit-extra/page)
MD

  run_prepare

  local page; page="$(docs_dest)/using-jeap.md"
  assert_link "$page" section  '/docs/building-blocks/libraries/jeap-audit/'
  assert_link "$page" page     '/docs/building-blocks/libraries/jeap-audit/page'
  assert_link "$page" bare     '/docs/building-blocks/libraries/jeap-audit'
  # Folded to a site-internal link first (rule 3a), then re-pointed.
  assert_link "$page" absolute '/docs/building-blocks/libraries/jeap-audit/page'
  # A repo whose name merely starts with the routed one must not be caught.
  assert_link "$page" lookalike '/docs/jeap-audit-extra/page'
}

# ---------------------------------------------------------------------------
# getting-started — pinned first inside its own section, tree-wide
# ---------------------------------------------------------------------------
test_getting_started_is_pinned_first_within_its_section() {
  repo_section demo <<<'# Demo'
  doc demo/getting-started.md <<<'# Getting started'
  doc demo/nested/getting-started.md <<<'# Nested getting started'

  run_prepare

  assert_contains "$(section_dir demo)/getting-started.md" 'sidebar_position: 0'
  assert_contains "$(section_dir demo)/nested/getting-started.md" 'sidebar_position: 0' \
    'the pin applies tree-wide, not only at a section root'
}

test_getting_started_pin_overrides_source_front_matter() {
  repo_section demo <<<'# Demo'
  doc demo/getting-started.md <<'MD'
---
sidebar_position: 7
title: Kept title
---

# Getting started
MD

  run_prepare

  local page; page="$(section_dir demo)/getting-started.md"
  assert_contains "$page" 'sidebar_position: 0' 'the pin is forced'
  assert_not_contains "$page" 'sidebar_position: 7'
  assert_contains "$page" 'title: Kept title' 'the rest of the front matter survives'
}

test_getting_started_pin_is_inserted_into_front_matter_that_lacks_it() {
  repo_section demo <<<'# Demo'
  doc demo/getting-started.md <<'MD'
---
title: Kept title
---

# Getting started
MD

  run_prepare

  local page; page="$(section_dir demo)/getting-started.md"
  assert_contains "$page" 'sidebar_position: 0'
  assert_contains "$page" 'title: Kept title'
  assert_eq '2' "$(grep -c -- '^---$' "$page")" 'exactly one front-matter block'
}

test_a_getting_started_folder_is_pinned_as_a_category() {
  repo_section demo <<<'# Demo'
  doc demo/getting-started/index.md <<<'# Getting started'

  run_prepare

  local cat; cat="$(section_dir demo)/getting-started/_category_.json"
  assert_json_field "$cat" label    'Getting Started'
  assert_json_field "$cat" position 0
}

# ---------------------------------------------------------------------------
# Idempotency — the script runs on every build, sometimes over a tree a previous
# run already transformed.
# ---------------------------------------------------------------------------
test_a_second_run_changes_nothing() {
  categories_fixture
  repo_section jeap-audit <<'MD'
# Audit

- [doc](docs/usage.md#setup)
- [script](scripts/build.sh)
- [up](../README.md)

## License

Boilerplate.
MD
  doc jeap-audit/usage.md <<<'# Usage'
  doc jeap-audit/getting-started.md <<<'# Getting started'
  doc using-jeap.md <<<'# Using jEAP

- [section](/docs/jeap-audit/page)'

  run_prepare
  cp -R "$DOCS_DEST" "$TMP_DIR/first-run"
  run_prepare

  local diff_out
  diff_out="$(diff -r "$TMP_DIR/first-run" "$DOCS_DEST" 2>&1)" ||
    fail "re-running prepare-docs.sh changed the tree:
$(printf '%s\n' "$diff_out" | sed 's/^/      /')"
}

run_tests
