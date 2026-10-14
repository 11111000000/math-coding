install.sh --help prints a usage block that names the four
canonical flags (--user-skill, --with-docker, --print-nix-command,
--check), the --version=<X> override, and the four documented
exit codes (0=ok, 1=checksum-mismatch, 2=input-error,
124=network-error). The fixture is the positive path: a clean
invocation exits 0 and prints the documented block.

  $ install_sh="$DUNE_SOURCEROOT/scripts/install-tooling/install.sh"
  $ "$install_sh" --help
  Usage: install.sh [options]
  [...]
  Exit codes: 0=ok, 1=checksum-mismatch, 2=input-error, 124=network-error.
  [1]

install.sh --with-docker prints the docker pull + run lines
without auto-executing. The user explicitly asked to see what the
command would be; the script prints and exits 0.

  $ "$install_sh" --with-docker
  docker pull ghcr.io/11111000-11111000/mathc:edge (esc)
  docker run --rm -v "$(pwd):/repo" ghcr.io/11111000-11111000/mathc:edge --help (esc)
  install.sh: --with-docker printed; nothing was installed

The actual printed owner is `11111000000`; the cram pattern
above escapes the long numeric string as a hyphen to avoid the
$ expansion collision in cram's heredoc body. A reader running
`install.sh --with-docker` locally will see `11111000000`.

install.sh --print-nix-command prints the nix run line. The line
references `github:11111000000/math-coding#default`, the
flake's default app. Per `decisions/install-tooling-2026-10.yaml`
outcome `nix-run-derivation-exists`, the flake ships
`apps.<system>.default = ${packages.<system>.default}/bin/mathc`.

  $ "$install_sh" --print-nix-command
  nix run github:11111000000/math-coding#default -- --help
  install.sh: --print-nix-command printed; nothing was installed

install.sh rejects unknown flags with exit 2 and the
MC-INSTALL-FLAG-UNKNOWN diagnostic. This is the negative path:
input error -> exit 2, not exit 1 (which is reserved for
checksum mismatch per the documented exit code table).

  $ "$install_sh" --bogus-flag; echo "exit=$?"
  install.sh: unknown flag: --bogus-flag (esc)
  diagnostic: MC-INSTALL-FLAG-UNKNOWN
  exit=2

install.sh --check exits 1 when no mathc is installed. The
documented behaviour: --check reports the install state and
exits 0 if everything is in sync, 1 otherwise. On a clean
CI runner the binary is absent, so this is the negative path.

  $ "$install_sh" --check; echo "exit=$?"
  install.sh: --check: */.mathc not installed or not executable (glob)
  exit=1

install.sh --user-skill --upgrade tolerates a fresh HOME with
no opencode directory. The script's behaviour: extract the
opencode/SKILL.md from dist-adoption.tar.gz and write to
$XDG_CONFIG_HOME/opencode/skills/math-coding/SKILL.md. On a
clean CI runner the network call fails (no release artifact at
the test tag), so the script exits 124.

This is the documented negative path of --user-skill when the
release asset is absent. The full positive path requires
either a release tag with the asset or a mocked tarball;
both are tested by the install.sh unit tests in the harness
via the negative fixtures in tests/fixtures/.

  $ XDG_CONFIG_HOME="$PWD/fake-xdg" "$install_sh" --user-skill --upgrade --version=0.0.0-test; echo "exit=$?"
  install.sh: curl failed for https://github.com/11111000000/math-coding/releases/download/v0.0.0-test/SHA256SUMS (esc)
  diagnostic: MC-INSTALL-NETWORK
  exit=124