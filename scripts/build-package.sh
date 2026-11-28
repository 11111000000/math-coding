#!/bin/sh
# The packages of this repository, built the way the runner can build them.
#
# The compiler of OCaml 5 reserves the stack for its signal handlers, and the
# runtime of the runner cannot always reserve it: the build dies with
# "Failed to allocate signal stack for domain 0" before it reads a file. The
# failure is in the environment of the runner and not in the tree, and the
# same revision passes on the next try.
#
# The build is therefore tried a few times, and once without the sandbox: the
# sandbox of the runner is what breaks the runtime of the compiler, and the
# build outside it has the stack of the runner.
#
# The runner runs a step of a workflow with "bash -e", and the first failure
# of a command would end the step before the first try. The rule therefore
# lives in this script, which the step calls: the script decides itself when
# a failure is expected.
#
# Usage:
#   sh scripts/build-package.sh default    # the program and the measurer
#   sh scripts/build-package.sh portable   # the static program and measurer
set -u

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

mode=${1:-}
case "$mode" in
  default) targets=".#default .#stand" ;;
  portable) targets=".#portable" ;;
  *)
    printf 'usage: sh scripts/build-package.sh default|portable\n' >&2
    exit 2
    ;;
esac

# The static build of OCaml 5 reserves the stack for its signal handlers, and
# the default limit of the runner is too small: the binary dies before it
# starts. A bigger stack is the fix; the retries stay for the build itself,
# which is slow and cold.
ulimit -s 65536 || true

attempts=3
attempt=1
while [ "$attempt" -le "$attempts" ]; do
  log=$(mktemp)
  # The targets are several, and the word splitting is what tells them apart.
  # shellcheck disable=SC2086
  nix build $targets --no-link >"$log" 2>&1
  status=$?
  cat "$log"
  if [ "$status" -eq 0 ]; then
    rm -f "$log"
    exit 0
  fi
  if ! grep -q "Failed to allocate signal stack" "$log"; then
    rm -f "$log"
    exit "$status"
  fi
  rm -f "$log"
  printf 'build attempt %s failed with the signal stack error\n' "$attempt" >&2
  attempt=$((attempt + 1))
done

printf 'the build failed %s times with the signal stack error\n' "$attempts" >&2
printf 'the build is tried once more without the sandbox\n' >&2
# The daemon builds the derivation, and the daemon owns the sandbox: the
# option of the client does not reach it, and the build would be the same
# build again. The daemon is therefore told to leave the sandbox alone. Only
# the runner does this, and the build is the tool of this repository.
if [ -n "${GITHUB_ACTIONS:-}" ] && sudo -n true 2>/dev/null; then
  printf 'sandbox = false\n' | sudo tee -a /etc/nix/nix.conf >/dev/null
  sudo systemctl restart nix-daemon.service
fi
ulimit -s unlimited || true
# shellcheck disable=SC2086
if nix build $targets --no-link --option sandbox false; then
  exit 0
fi
printf 'the build failed with and without the sandbox\n' >&2
exit 1
