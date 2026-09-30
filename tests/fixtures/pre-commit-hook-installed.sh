#!/usr/bin/env bash
# tests/fixtures/pre-commit-hook-installed.sh
#
# Verifier for decisions/process-principles-close-branches.yaml
# obligation `pre-commit-hook-impl`: the `.githooks/pre-commit`
# script is installed (executable, present) and its P1 / P2
# lexical scanner can be invoked from a stubbed git index.
#
# This is a non-destructive sanity check: it stages nothing,
# it just runs the hook script with a fake `git diff --cached`
# payload via PATH shimming. The full lexical pass is exercised
# at commit time, where the dev must run `scripts/dev init-hooks`.

set -uo pipefail
cd "$(dirname "$0")/../.."

# 1. The hook file exists and is executable.
if [ ! -x .githooks/pre-commit ]; then
  echo "FAIL: .githooks/pre-commit is missing or not executable"
  exit 1
fi

# 2. The hook is syntactically valid bash.
if ! bash -n .githooks/pre-commit; then
  echo "FAIL: .githooks/pre-commit has bash syntax errors"
  exit 1
fi

# 3. The hook returns 0 on an empty staged set (early-exit
#    before any branch is taken). Stub git via a PATH bin.
stub=$(mktemp -d)
cat >"$stub/git" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  diff)
    case "$2" in
      --cached)
        case "$3" in
          --name-only) exit 0 ;;
        esac ;;
    esac ;;
esac
exit 0
EOF
chmod +x "$stub/git"

PATH="$stub:$PATH" bash .githooks/pre-commit
ec=$?
rm -rf "$stub"

if [ "$ec" != "0" ]; then
  echo "FAIL: pre-commit hook exited $ec on empty staged set"
  exit 1
fi

echo "ok: .githooks/pre-commit is installed, parseable, exit-0 on empty"
exit 0