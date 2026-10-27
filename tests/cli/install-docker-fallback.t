install.sh --help documents --docker-fallback as the
fallback channel when native install fails and docker is
on PATH. Default off; preserves the existing UX.

install.sh ships mode 644 from the repo checkout (it is not
git-tracked executable). The cram shell invokes it via
`sh "$install_sh"` so the test is hermetic without depending
on the host's `chmod` state. We also `tail -n +2` to drop the
spurious `error: getting status of ...` line that the unquoted
heredoc emits when no `nix` is on PATH (see install.t for the
rationale on the kernel-side backtick evaluation).

  $ install_sh="$DUNE_SOURCEROOT/scripts/install-tooling/install.sh"
  $ sh "$install_sh" --help 2>&1 | tail -n +2
  Usage: install.sh [options]
  
  Options:
    --user-skill            install the per-user opencode skill
    --upgrade               (implies --user-skill) overwrite the skill
                            even when its version pin matches
    --no-path-update       skip the shell RC PATH auto-update
    --with-docker           print docker pull + run commands
    --docker-fallback       on native install failure (exit 1 / 124),
                            if docker is on PATH, print the docker run
                            command and exit 0 (default: off)
    --print-nix-command     print the  command
    --cosign-verify         (default on) verify the ghcr.io image
                            signature; --no-cosign-verify to skip
    --no-cosign-verify      skip the cosign signature verification
    --version=<X>           override MC_VERSION_DEFAULT
    --check                 exit 0 if already installed and in sync
    --libc=glibc|musl       override the libc auto-detect (Linux only)
    -h | --help             show this help
  
  Examples:
    curl -fsSL https://github.com/11111000000/math-coding/releases/latest/download/install.sh | sh
    curl ... | sh -s -- --user-skill
    curl ... | sh -s -- --version=v3.3.0 --with-docker
  
  Exit codes: 0=ok, 1=checksum-mismatch, 2=input-error, 124=network-error.

install.sh --docker-fallback on a network-error exit
prints the docker run line. The behavior: native install
failed (curl cannot reach the release tag), so the script
prints the docker fallback and exits 0.

We must `2>&1` the install.sh output BEFORE piping it into
the EXIT capture, because install.sh writes both the
network-error message AND the docker fallback to stderr;
without the merge the diagnostic stays as a separate
cram-captured line, breaking the expected block.

The expected output below is the block the script prints
WHEN DOCKER IS ON PATH. The CI runner image (ubuntu-22.04)
has no docker binary, and install.sh says so and exits 1
instead -- so the literal expectation could only be
satisfied on a host that happens to have docker, and the
case failed in CI while passing on developer machines that
did.

The case is now written so the EXPECTED output is the same
on both kinds of host. The script's own exit status is
captured into a variable, and the docker-specific lines are
checked against the branch that applies on THIS host --
docker present (fallback printed, exit 0) or docker absent
(the script says so, exit 1). Both branches print the same
line, so the case fails if the contract is violated on
either kind of host, and it does not fail a host for the
absence of a tool it never claimed to provide.

  $ sh "$install_sh" --no-cosign-verify --docker-fallback --version=0.0.0-nonexistent > install.out 2>&1; rc=$?
  $ grep -E 'curl failed|diagnostic: MC-INSTALL-NETWORK' install.out
  install.sh: curl failed for https://github.com/11111000000/math-coding/releases/download/v0.0.0-nonexistent/SHA256SUMS
  diagnostic: MC-INSTALL-NETWORK
  $ if command -v docker >/dev/null 2>&1; then
  >   grep -qE 'Docker fallback available' install.out && grep -qE 'docker pull ghcr.io/11111000000/mathc:0.0.0-nonexistent' install.out && grep -qE 'docker run --rm ' install.out && [ "$rc" -eq 0 ] && echo "docker fallback contract: ok" || echo "docker fallback contract: VIOLATED"
  > else
  >   grep -qE 'docker binary not found on PATH' install.out && [ "$rc" -eq 1 ] && echo "docker fallback contract: ok" || echo "docker fallback contract: VIOLATED"
  > fi
  docker fallback contract: ok

