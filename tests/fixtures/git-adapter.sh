#!/usr/bin/env bash
# adapters: git-changed-files-adapter fixture
#
# Asserts that `mc assess BASE HEAD` runs `git diff --name-only
# BASE..HEAD` via lib/git/git_diff.changed_files and emits a JSON
# array of the changed file paths on stdout. This is the acceptance
# gate for obligation git-changed-files-adapter declared in
# bootstrap/adapters.md.
#
# Negative run (before this commit):
#   bin/mathc.exe has no `assess` subcommand; the dispatcher
#   prints "mc: unknown command: assess" to stderr and exits 2.
#   The fixture fails because INNER_EC is 2 (not 0) and no JSON
#   array appears on stdout.
#
# Positive run (after this commit):
#   The fixture creates a temp git repo with a known two-commit
#   history (HEAD~1 -> HEAD adds two files), runs
#   `_build/default/bin/mathc.exe assess HEAD~1 HEAD` from inside
#   the temp repo, asserts exit 0, and asserts that stdout is a
#   JSON array containing both file paths.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "git-changed-files-adapter:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Set up a temp git repo with a known commit history. Two commits:
#   - HEAD~1: empty tree (the bootstrap commit)
#   - HEAD:   adds file_a.txt and file_b.txt
tmp_repo=$(mktemp -d)
trap 'rm -rf "$tmp_repo"; rm -f "$log"' EXIT

git -C "$tmp_repo" init -q
git -C "$tmp_repo" \
  -c user.email=test@test.local \
  -c user.name="adapter-fixture" \
  commit -q --allow-empty -m "first commit"
printf 'hello world\n' > "$tmp_repo/file_a.txt"
printf 'second file\n' > "$tmp_repo/file_b.txt"
git -C "$tmp_repo" add file_a.txt file_b.txt
git -C "$tmp_repo" \
  -c user.email=test@test.local \
  -c user.name="adapter-fixture" \
  commit -q -m "second commit"

# Build mathc.exe in the project root, then cd into the temp repo
# and call the binary by its absolute path. The cwd mathc.exe sees
# is the temp repo, which is exactly the cwd the adapter must pass
# to `git -C <cwd>`. We capture the project root before cd so the
# absolute binary path resolves correctly after cd.
if ! nix develop .#test --command bash -c "
  proj_root=\$(pwd)
  dune build --root . bin/mathc.exe || exit 99
  cd '$tmp_repo'
  \"\$proj_root/_build/default/bin/mathc.exe\" assess HEAD~1 HEAD
  echo INNER_EC=\$?
" >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero (build or runtime)" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ -z "$inner_ec" ]; then
  echo "  FAIL no INNER_EC marker in wrapper output" >&2
  cat "$log" >&2
  exit 1
fi

if [ "$inner_ec" != "0" ]; then
  echo "  FAIL mc assess exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

# Extract stdout body (everything before the INNER_EC marker).
body=$(sed -n '/^INNER_EC=/!p' "$log")

# Body must be a JSON array: starts with [ and ends with ].
if ! printf '%s' "$body" | grep -q '^\['; then
  echo "  FAIL stdout did not start with '['" >&2
  cat "$log" >&2
  exit 1
fi
if ! printf '%s' "$body" | grep -q '\]'; then
  echo "  FAIL stdout JSON array not closed with ']'" >&2
  cat "$log" >&2
  exit 1
fi

# Body must contain both expected file paths as JSON strings.
for path in file_a.txt file_b.txt; do
  if ! printf '%s' "$body" | grep -qF "\"$path\""; then
    echo "  FAIL JSON array missing expected path \"$path\"" >&2
    cat "$log" >&2
    exit 1
  fi
done

echo "  ok   mc assess HEAD~1 HEAD returned JSON array with file_a.txt and file_b.txt"
exit 0
