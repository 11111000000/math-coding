#!/bin/sh
# The report of the bilingual console must be in step with the work it
# describes.
#
# The report is the written account of the two-language console: it says which
# sections it holds, which languages the console ships and how many claims
# cover the project. A report that lags the work misleads the reader, and a
# reader of the report has no way to tell that it lags. These checks compare
# the report with the tree it describes.
#
# Exit 0 - the report is in step with the work.
# Exit 1 - the report states a fact the project does not have.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT="$ROOT/docs/PLUGIN-I18N-REPORT-AND-PLAN.md"
PLUGIN="$ROOT/plugin/math-coding-console"
failures=0

fail() {
  printf 'i18n-report: %s\n' "$1" >&2
  failures=$((failures + 1))
}

if [ ! -f "$REPORT" ]; then
  printf 'i18n-report: the report is missing\n' >&2
  exit 1
fi

# --- the report carries its title and its status ----------------------------

grep -q '^# Русский и английский в плагине Math Coding' "$REPORT" ||
  fail "the report has no title"
grep -q 'Статус:' "$REPORT" ||
  fail "the report states no status"

# --- the report keeps the ten sections it promises ---------------------------

sections=$(grep -cE '^## [0-9]+\.' "$REPORT" || true)
if [ "$sections" -ne 10 ]; then
  fail "the report holds $sections numbered sections, not the ten it promises"
fi
for number in 1 2 3 4 5 6 7 8 9 10; do
  grep -qE "^## $number\." "$REPORT" ||
    fail "the report has no section $number"
done

# --- the report names the catalogue of every language the console ships ------

locales=$(sed -n 's/.*SUPPORTED_LOCALES = \[\([^]]*\)\].*/\1/p' \
  "$PLUGIN/client/i18n/locale.ts" | tr -d '"' | tr ',' ' ')
if [ -z "$locales" ]; then
  fail "the console does not declare the languages it ships"
fi
for locale in $locales; do
  catalogue="shared/locales/$locale.ts"
  if [ ! -f "$PLUGIN/$catalogue" ]; then
    fail "the console ships the language $locale but has no catalogue for it"
    continue
  fi
  grep -q "$catalogue" "$REPORT" ||
    fail "the report does not name the catalogue of the language $locale"
done

# --- the number the report states is the number of claims of the project -----

claims=$(grep -c '"id":' "$ROOT/spec.json" || true)
stated=$(grep -oE '[0-9]+ утверждени[^ ]*' "$REPORT" | grep -oE '^[0-9]+' | sort -u || true)
if [ -z "$stated" ]; then
  fail "the report states no number of claims"
fi
for number in $stated; do
  if [ "$number" -ne "$claims" ]; then
    fail "the report says $number claims, the specification holds $claims"
  fi
done

if [ "$failures" -gt 0 ]; then
  printf 'i18n-report: %d defect(s) in the report\n' "$failures" >&2
  exit 1
fi

printf 'i18n-report: the report is in step with the work\n'
