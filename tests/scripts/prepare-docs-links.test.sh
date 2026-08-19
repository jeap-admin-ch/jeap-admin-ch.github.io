#!/usr/bin/env bash
#
# Link rewriting in scripts/prepare-docs.sh.
#
# These rules are the fragile part of the pipeline: a handful of sed/perl
# expressions that must rewrite exactly the links which would break the
# Docusaurus build (onBrokenLinks: 'throw') and leave every other link alone.
# Both directions are asserted — rewritten shapes AND the near-misses that must
# survive untouched, since over-eager matching is the failure mode that reaches
# production silently.
#
# The tests run the real script, so they fail if a rule changes behaviour.
#
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# A repo section as clone-docs.sh assembles it: index.md from the repo README,
# the repo's docs/ flattened alongside it, docs/index.md demoted to modules.md.
fixture_section() {  # <repo>  (index.md body on stdin)
  local repo="$1"
  repo_section "$repo"
  doc "$repo/policy.md"      <<<'# Policy'
  doc "$repo/modules.md"     <<<'# Modules'
  doc "$repo/a-b_c.1.md"     <<<'# Odd name'
  doc "$repo/sub/dir/page.md" <<<'# Nested page'
  doc "$repo/images/x.png"   <<<'not really a png'
}

# ---------------------------------------------------------------------------
# Rule 2b — README links into the repo's own docs/, which is flattened into the
# section during assembly.
# ---------------------------------------------------------------------------
test_readme_docs_links_are_rewritten_to_sibling_pages() {
  fixture_section demo <<'MD'
# Demo

- [plain](docs/policy.md)
- [dotslash](./docs/policy.md)
- [nested](docs/sub/dir/page.md)
- [dotted](docs/a-b_c.1.md)
- [demoted-index](docs/index.md)
- [image](docs/images/x.png)
MD

  run_prepare

  local index; index="$(section_dir demo)/index.md"
  assert_link "$index" plain         './policy.md'
  assert_link "$index" dotslash      './policy.md'
  assert_link "$index" nested        './sub/dir/page.md'
  assert_link "$index" dotted        './a-b_c.1.md'
  assert_link "$index" demoted-index './modules.md'
  assert_link "$index" image         'images/x.png'
  assert_not_contains "$index" '](docs/' 'no docs/ prefix may survive'
}

# The regression this suite exists for: a README deep-linking into its own docs
# used to leave the link unrewritten, which failed the build (JEAP-7398).
test_fragments_are_carried_across_the_rewrite() {
  fixture_section demo <<'MD'
# Demo

- [anchored](docs/policy.md#incomplete-scans)
- [nested-anchored](docs/sub/dir/page.md#frag)
- [dotted-anchored](docs/a-b_c.1.md#a-b)
- [index-anchored](docs/index.md#top)
- [dotslash-anchored](./docs/policy.md#incomplete-scans)
MD

  run_prepare

  local index; index="$(section_dir demo)/index.md"
  assert_link "$index" anchored          './policy.md#incomplete-scans'
  assert_link "$index" nested-anchored    './sub/dir/page.md#frag'
  assert_link "$index" dotted-anchored    './a-b_c.1.md#a-b'
  assert_link "$index" index-anchored     './modules.md#top'
  assert_link "$index" dotslash-anchored  './policy.md#incomplete-scans'
}

# The over-matching guard: a URL that merely CONTAINS /docs/ must not be touched.
test_absolute_urls_containing_docs_are_left_alone() {
  fixture_section demo <<'MD'
# Demo

- [external](https://example.org/docs/policy.md)
- [external-anchored](https://example.org/docs/policy.md#x)
- [external-index](https://example.org/docs/index.md)
- [protocol-relative](//example.org/docs/policy.md)
MD

  run_prepare

  local index; index="$(section_dir demo)/index.md"
  assert_link "$index" external           'https://example.org/docs/policy.md'
  assert_link "$index" external-anchored  'https://example.org/docs/policy.md#x'
  assert_link "$index" external-index     'https://example.org/docs/index.md'
  assert_link "$index" protocol-relative  '//example.org/docs/policy.md'
}

# ---------------------------------------------------------------------------
# Rule 2a-bis — links to source-repo files that are NOT published as doc pages
# become links to the file on GitHub, with the path resolved back to its
# location in the source repo.
# ---------------------------------------------------------------------------
test_readme_links_to_unpublished_repo_files_point_at_github() {
  local gh='https://github.com/jeap-admin-ch/demo/blob/main'
  fixture_section demo <<'MD'
# Demo

- [script](scripts/build.sh)
- [sibling](CONTRIBUTING.md)
- [folder](src/main)
- [anchored](scripts/build.sh#L3)
MD

  run_prepare

  local index; index="$(section_dir demo)/index.md"
  assert_link "$index" script   "$gh/scripts/build.sh"
  assert_link "$index" sibling  "$gh/CONTRIBUTING.md"
  assert_link "$index" folder   "$gh/src/main"
  assert_link "$index" anchored "$gh/scripts/build.sh#L3"
}

# A subpage came from the repo's docs/, so its relative links resolve against
# docs/ — `../x` escapes to the repo root and has no doc page.
test_subpage_links_escaping_docs_point_at_github() {
  repo_section demo <<<'# Demo'
  doc demo/other.md <<<'# Other'
  doc demo/guide.md <<'MD'
# Guide

- [escape](../pom.xml)
- [escape-anchored](../pom.xml#L10)
- [deep-escape](../../elsewhere/file.txt)
- [peer](other.md)
- [peer-anchored](other.md#heading)
MD

  run_prepare

  local guide; guide="$(section_dir demo)/guide.md"
  assert_link "$guide" escape          'https://github.com/jeap-admin-ch/demo/blob/main/pom.xml'
  assert_link "$guide" escape-anchored 'https://github.com/jeap-admin-ch/demo/blob/main/pom.xml#L10'
  assert_link "$guide" peer            'other.md'
  assert_link "$guide" peer-anchored   'other.md#heading'
  # Escaping above the repo root cannot be expressed as a repo file link.
  assert_link "$guide" deep-escape     '../../elsewhere/file.txt'
}

test_non_relative_links_are_never_turned_into_repo_links() {
  repo_section demo <<'MD'
# Demo

- [https](https://example.org/x)
- [mail](mailto:jeap@example.org)
- [site-root](/docs/other-repo/page)
- [anchor](#section)
MD

  run_prepare

  local index; index="$(section_dir demo)/index.md"
  assert_link "$index" https     'https://example.org/x'
  assert_link "$index" mail      'mailto:jeap@example.org'
  assert_link "$index" site-root '/docs/other-repo/page'
  assert_link "$index" anchor    '#section'
}

test_repo_web_base_url_is_configurable() {
  repo_section demo <<'MD'
# Demo

- [script](scripts/build.sh)
MD

  run_prepare REPO_WEB_BASE_URL=https://git.example.org/team

  assert_link "$(section_dir demo)/index.md" script \
    'https://git.example.org/team/demo/blob/main/scripts/build.sh'
}

# ---------------------------------------------------------------------------
# Rule 3 — applied tree-wide, including the curated umbrella content at the top
# level (which the repo-section transforms never touch).
# ---------------------------------------------------------------------------
test_parent_readme_links_point_at_the_umbrella_repo() {
  doc using-jeap.md <<'MD'
# Using jEAP

- [up-one](../README.md)
- [up-two](../../README.md)
- [other-parent-file](../CHANGELOG.md)
- [own-readme](README.md)
MD

  run_prepare

  local page; page="$(docs_dest)/using-jeap.md"
  assert_link "$page" up-one 'https://github.com/jeap-admin-ch/jeap#readme'
  assert_link "$page" up-two 'https://github.com/jeap-admin-ch/jeap#readme'
  # Only ../README.md is redirected; other parent links are the source's business.
  assert_link "$page" other-parent-file '../CHANGELOG.md'
  assert_link "$page" own-readme        'README.md'
}

test_absolute_site_urls_are_folded_to_internal_links() {
  doc using-jeap.md <<'MD'
# Using jEAP

- [internal](https://jeap-admin-ch.github.io/jeap-messaging/x)
- [internal-root](https://jeap-admin-ch.github.io/)
- [foreign](https://jeap-admin-ch.github.com/jeap-messaging/x)
- [other-host](https://example.github.io/jeap-messaging/x)
MD

  run_prepare

  local page; page="$(docs_dest)/using-jeap.md"
  assert_link "$page" internal      '/jeap-messaging/x'
  assert_link "$page" internal-root '/'
  # The '.' in the site URL is escaped, so a look-alike host must not match.
  assert_link "$page" foreign    'https://jeap-admin-ch.github.com/jeap-messaging/x'
  assert_link "$page" other-host 'https://example.github.io/jeap-messaging/x'
}

test_umbrella_and_site_urls_are_configurable() {
  doc using-jeap.md <<'MD'
# Using jEAP

- [up](../README.md)
- [internal](https://docs.example.org/section/page)
MD

  run_prepare UMBRELLA_REPO_URL=https://git.example.org/team/umbrella \
              SITE_BASE_URL=https://docs.example.org

  local page; page="$(docs_dest)/using-jeap.md"
  assert_link "$page" up       'https://git.example.org/team/umbrella#readme'
  assert_link "$page" internal '/section/page'
}

# ---------------------------------------------------------------------------
# Rule 2a — the README landing page is truncated at its trailing boilerplate,
# whose ./CHANGELOG.md and ./LICENSE links have no doc page.
# ---------------------------------------------------------------------------
test_readme_boilerplate_sections_are_truncated() {
  local heading
  for heading in 'Changelog' 'Change Log' 'Changes' 'Change' 'Note' 'Notes' 'License' 'Licence' 'Notes on releases'; do
    rm -rf "$DOCS_DEST"; mkdir -p "$DOCS_DEST"
    repo_section demo <<MD
# Demo

Kept content.

## $heading

- [changelog](./CHANGELOG.md)
MD
    run_prepare
    local index; index="$(section_dir demo)/index.md"
    assert_contains "$index" 'Kept content.' "content above '## $heading' must survive"
    assert_not_contains "$index" "## $heading" "'## $heading' must be truncated"
    assert_not_contains "$index" 'CHANGELOG.md' "links below '## $heading' must be gone"
  done
}

test_truncation_only_matches_second_level_headings() {
  repo_section demo <<'MD'
# Demo

## Licensing model

Kept: this is a real section, not the boilerplate.

### License

Kept: deeper heading.

## Getting started with Changes

Kept: heading does not start with the boilerplate word.
MD

  run_prepare

  local index; index="$(section_dir demo)/index.md"
  assert_contains "$index" '## Licensing model' 'a longer word must not match'
  assert_contains "$index" '### License'        'only ## headings are boilerplate'
  assert_contains "$index" '## Getting started with Changes' 'the word must lead the heading'
}

run_tests
