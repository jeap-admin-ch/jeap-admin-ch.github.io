#!/usr/bin/env bash
#
# harness.sh — the minimal test framework backing tests/scripts/*.test.sh.
#
# A test file sources this, defines functions named `test_<something>`, and ends
# with `run_tests`. Each test runs in its own subshell with a fresh temporary
# DOCS_DEST, so tests cannot leak state into one another and a failing test
# cannot abort the rest of the run.
#
# The tests drive the REAL scripts (scripts/clone-docs.sh, scripts/prepare-docs.sh)
# against fixture trees — the rewrite rules are never copied into the tests, so a
# test can only pass if the script itself behaves as asserted.
#
# Provided by this file:
#   Assertions   assert_eq, assert_contains, assert_not_contains, assert_file,
#                assert_no_file, assert_dir, assert_link, assert_json_field
#   Fixtures     doc (write a file below $DOCS_DEST), repo_section, git_repo
#   Runners      run_prepare, run_clone
#   Utilities    fail, skip, docs_dest, section_dir
#
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$HARNESS_DIR/.." && pwd)"
SITE_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"
SCRIPTS_DIR="$SITE_ROOT/scripts"

# Colours only when stdout is a terminal, so CI logs stay plain.
if [ -t 1 ]; then
  C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
  C_BLUE=$'\033[1;34m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_DIM=""; C_OFF=""
fi

# ---------------------------------------------------------------------------
# Failure reporting
#
# A failing assertion writes its message to the per-test failure file and marks
# the test failed; the test function keeps running so one invocation can report
# every mismatch in a table of cases at once (much easier to debug than
# discovering them one re-run at a time).
# ---------------------------------------------------------------------------
fail() {  # <message...>
  printf '%s\n' "$*" >> "$TEST_FAILURES"
  return 1
}

# Abort the current test without failing the suite (missing optional tooling).
skip() {  # <reason...>
  printf '%s\n' "$*" > "$TEST_SKIPPED"
  exit 0
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------
assert_eq() {  # <expected> <actual> [label]
  local expected="$1" actual="$2" label="${3:-values differ}"
  [ "$expected" = "$actual" ] && return 0
  fail "$label
    expected: $expected
    actual:   $actual"
}

assert_contains() {  # <file> <substring> [label]
  local f="$1" needle="$2" label="${3:-}"
  [ -f "$f" ] || fail "${label:-expected content} — file does not exist: ${f#"$DOCS_DEST"/}" || return 1
  grep -qF -- "$needle" "$f" && return 0
  fail "${label:-missing expected content} in ${f#"$DOCS_DEST"/}
    expected to contain: $needle
    actual content:
$(sed 's/^/      /' "$f")"
}

assert_not_contains() {  # <file> <substring> [label]
  local f="$1" needle="$2" label="${3:-}"
  [ -f "$f" ] || return 0
  grep -qF -- "$needle" "$f" || return 0
  fail "${label:-unexpected content} in ${f#"$DOCS_DEST"/}
    expected NOT to contain: $needle"
}

assert_file() {  # <path> [label]
  [ -f "$1" ] && return 0
  fail "${2:-expected file to exist}: ${1#"$DOCS_DEST"/}"
}

assert_no_file() {  # <path> [label]
  [ ! -f "$1" ] && return 0
  fail "${2:-expected file NOT to exist}: ${1#"$DOCS_DEST"/}"
}

assert_dir() {  # <path> [label]
  [ -d "$1" ] && return 0
  fail "${2:-expected directory to exist}: ${1#"$DOCS_DEST"/}"
}

# Assert that a Markdown link target was rewritten as expected. The file is
# searched for `[<label>](<target>)`, so link tables read one case per line.
assert_link() {  # <file> <link-label> <expected-target>
  local f="$1" name="$2" expected="$3" actual
  actual="$(sed -nE "s/.*\[${name}\]\(([^)]*)\).*/\1/p" "$f" | head -n 1)"
  [ -n "$actual" ] || { fail "link [$name] not found in ${f#"$DOCS_DEST"/}"; return 1; }
  [ "$actual" = "$expected" ] && return 0
  fail "link [$name] in ${f#"$DOCS_DEST"/}
    expected: $expected
    actual:   $actual"
}

# Assert a "key": value pair in a _category_.json (string or number).
assert_json_field() {  # <file> <key> <expected>
  local f="$1" key="$2" expected="$3" actual
  [ -f "$f" ] || { fail "expected JSON file to exist: ${f#"$DOCS_DEST"/}"; return 1; }
  actual="$(sed -nE "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"?([^\",]*)\"?,?[[:space:]]*$/\1/p" "$f" | head -n 1)"
  [ "$actual" = "$expected" ] && return 0
  fail "JSON field \"$key\" in ${f#"$DOCS_DEST"/}
    expected: $expected
    actual:   $actual"
}

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
docs_dest()   { printf '%s' "$DOCS_DEST"; }
section_dir() { printf '%s/%s' "$DOCS_DEST" "$1"; }

# Write a file below $DOCS_DEST from stdin, creating parent directories.
#   doc index.md <<'EOF'
#   # Title
#   EOF
doc() {  # <relative-path>  (content on stdin)
  local rel="$1" target="$DOCS_DEST/$1"
  mkdir -p "$(dirname "$target")"
  cat > "$target"
}

# Create the shape clone-docs.sh produces for an auto-discovered repo: a section
# folder whose index.md came from the repo README. Content is read from stdin.
repo_section() {  # <repo-name>  (index.md content on stdin)
  local repo="$1"
  mkdir -p "$DOCS_DEST/$repo"
  cat > "$DOCS_DEST/$repo/index.md"
}

# Create a throwaway git repository with the given files, so clone-docs.sh can
# clone it over file://. Files are passed as "<path>=<content>" arguments.
git_repo() {  # <dir> [<path>=<content> ...]
  local dir="$1"; shift
  local spec path content
  mkdir -p "$dir"
  for spec in "$@"; do
    path="${spec%%=*}"; content="${spec#*=}"
    mkdir -p "$dir/$(dirname "$path")"
    printf '%s\n' "$content" > "$dir/$path"
  done
  git -C "$dir" init -q -b main
  git -C "$dir" -c user.email=t@example.org -c user.name=Test add -A
  git -C "$dir" -c user.email=t@example.org -c user.name=Test commit -qm "fixture"
}

# ---------------------------------------------------------------------------
# Runners — invoke the real scripts. Output is captured into $LAST_OUTPUT and
# only surfaced when the script exits non-zero (or the test fails), keeping a
# passing run quiet.
# ---------------------------------------------------------------------------
run_prepare() {  # [VAR=value ...]
  LAST_OUTPUT="$(env DOCS_DEST="$DOCS_DEST" "$@" bash "$SCRIPTS_DIR/prepare-docs.sh" 2>&1)"
  LAST_STATUS=$?
  [ "$LAST_STATUS" -eq 0 ] || fail "prepare-docs.sh exited with status $LAST_STATUS
$(printf '%s\n' "$LAST_OUTPUT" | sed 's/^/      /')"
  return 0
}

run_clone() {  # [VAR=value ...]
  LAST_OUTPUT="$(env DOCS_DEST="$DOCS_DEST" "$@" bash "$SCRIPTS_DIR/clone-docs.sh" 2>&1)"
  LAST_STATUS=$?
  [ "$LAST_STATUS" -eq 0 ] || fail "clone-docs.sh exited with status $LAST_STATUS
$(printf '%s\n' "$LAST_OUTPUT" | sed 's/^/      /')"
  return 0
}

# Assert that the last runner's combined output contained a substring — used for
# the warning paths, which are the script's only signal for bad input.
assert_output() {  # <substring> [label]
  case "$LAST_OUTPUT" in
    *"$1"*) return 0 ;;
  esac
  fail "${2:-expected script output to contain}: $1
    actual output:
$(printf '%s\n' "$LAST_OUTPUT" | sed 's/^/      /')"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
# Run every test_* function defined by the sourced test file. Each runs in a
# subshell with its own DOCS_DEST so state never leaks between tests.
run_tests() {
  local suite fn status failures skipped tmp
  suite="$(basename "${BASH_SOURCE[1]}" .test.sh)"
  local pass=0 failed=0 skips=0

  printf '%s\n' "${C_BLUE}${suite}${C_OFF}"

  for fn in $(declare -F | sed -n 's/^declare -f \(test_.*\)$/\1/p' | sort); do
    tmp="$(mktemp -d)"
    failures="$tmp/failures"; skipped="$tmp/skipped"
    : > "$failures"

    (
      DOCS_DEST="$tmp/docs"
      TEST_FAILURES="$failures"
      TEST_SKIPPED="$skipped"
      TMP_DIR="$tmp"
      LAST_OUTPUT=""
      LAST_STATUS=0
      mkdir -p "$DOCS_DEST"
      "$fn"
    ) > "$tmp/stdout" 2>&1
    status=$?

    local name="${fn#test_}"; name="${name//_/ }"
    if [ -f "$skipped" ]; then
      skips=$((skips + 1))
      printf '  %s—%s %s %s(%s)%s\n' "$C_YELLOW" "$C_OFF" "$name" "$C_DIM" "$(cat "$skipped")" "$C_OFF"
    elif [ -s "$failures" ] || [ "$status" -ne 0 ]; then
      failed=$((failed + 1))
      printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$name"
      [ -s "$failures" ] && sed 's/^/      /' "$failures"
      if [ "$status" -ne 0 ] && [ ! -s "$failures" ]; then
        printf '      test function exited with status %s\n' "$status"
        [ -s "$tmp/stdout" ] && sed 's/^/      /' "$tmp/stdout"
      fi
    else
      pass=$((pass + 1))
      printf '  %s✓%s %s\n' "$C_GREEN" "$C_OFF" "$name"
    fi
    rm -rf "$tmp"
  done

  printf '  %s%s passed, %s failed, %s skipped%s\n\n' \
    "$C_DIM" "$pass" "$failed" "$skips" "$C_OFF"
  [ "$failed" -eq 0 ]
}
