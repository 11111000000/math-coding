#!/usr/bin/env bash
# Render one tab of the console and let a browser pick it up.
#
#   ./show-tab.sh promises
#
# The console opens on the Verdict tab. To check another tab end-to-end in a
# browser, this puts that tab first, reloads the plugin, and the next page
# load shows it.
set -euo pipefail

TAB="${1:-verdict}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$HERE/client/console.tsx"

case "$TAB" in
  verdict | promises | decisions | review | evidence | actions) ;;
  *) printf 'unknown tab: %s\n' "$TAB" >&2; exit 2 ;;
esac

python3 - "$FILE" "$TAB" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
tab = sys.argv[2]
s = path.read_text()
s, n = re.subn(
    r'useState\(initialTab \?\? "[a-z]+"\)',
    f'useState(initialTab ?? "{tab}")',
    s,
)
if n != 1:
    raise SystemExit(f"expected one default-tab site, found {n}")
path.write_text(s)
PY

paseo plugin reload math-coding-console >/dev/null 2>&1 || true
printf 'the console now opens on the %s tab\n' "$TAB"
