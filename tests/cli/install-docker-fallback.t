install.sh --help documents --docker-fallback as the
fallback channel when native install fails and docker is
on PATH. Default off; preserves the existing UX.

  $ install_sh="$DUNE_SOURCEROOT/scripts/install-tooling/install.sh"
  $ "$install_sh" --help
  error: getting status of '$TESTCASE_ROOT/github:...': No such file or directory
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

  $ "$install_sh" --no-cosign-verify --docker-fallback --version=0.0.0-nonexistent; echo "exit=$?"
  install.sh: curl failed for https://github.com/11111000000/math-coding/releases/download/v0.0.0-nonexistent/SHA256SUMS
  diagnostic: MC-INSTALL-NETWORK
  native install failed; Docker fallback available:
  
  docker pull ghcr.io/11111000000/mathc:0.0.0-nonexistent
  docker run --rm -v "$(pwd):/repo" ghcr.io/11111000000/mathc:0.0.0-nonexistent --help
  
  install.sh: --docker-fallback printed; nothing was installed
  exit=0

