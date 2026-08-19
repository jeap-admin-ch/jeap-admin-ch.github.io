#!/usr/bin/env bash
#
# run.sh — run the shell-script test suites in tests/scripts.
#
# The docs pipeline (scripts/clone-docs.sh + scripts/prepare-docs.sh) is built
# out of regex rewrite rules that are easy to break by accident and impossible
# to verify from the site build alone — a wrong rule surfaces as a broken link
# in an unrelated repository's section, days later. These suites exercise the
# real scripts against fixture trees in a temporary directory; nothing here
# touches the site's own docs/.
#
# Usage:
#   bash tests/scripts/run.sh              # all suites
#   bash tests/scripts/run.sh prepare      # only suites matching "prepare"
#
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER="${1:-}"

if [ -t 1 ]; then
  C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_OFF=""
fi

failed=0
found=0
for suite in "$TESTS_DIR"/*.test.sh; do
  [ -f "$suite" ] || continue
  case "$(basename "$suite")" in
    *"$FILTER"*) ;;
    *) continue ;;
  esac
  found=$((found + 1))
  bash "$suite" || failed=$((failed + 1))
done

if [ "$found" -eq 0 ]; then
  printf '%sNo test suite matched "%s"%s\n' "$C_RED" "$FILTER" "$C_OFF" >&2
  exit 1
fi

if [ "$failed" -ne 0 ]; then
  printf '%s%s suite(s) failed%s\n' "$C_RED" "$failed" "$C_OFF" >&2
  exit 1
fi

printf '%sAll script tests passed%s\n' "$C_GREEN" "$C_OFF"
