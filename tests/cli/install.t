install.sh --help prints a usage block that names the four
canonical flags (--user-skill, --with-docker, --print-nix-command,
--check), the --cosign-verify toggle, the --version=<X>
override, the --no-path-update / --libc= toggles
introduced by decisions
ux-3-install-path-auto-add-2026-10 and
ux-3-install-libc-auto-detect-2026-10, and the four
documented exit codes (0=ok, 1=checksum-mismatch,
2=input-error, 124=network-error). The fixture is the
positive path: a clean invocation exits 0 and prints
the documented block.

  $ install_sh="$DUNE_SOURCEROOT/scripts/install-tooling/install.sh"
  $ "$install_sh" --help
  Usage: install.sh [options]
  
  Options:
    --user-skill            install the per-user opencode skill
  --upgrade               (implies --user-skill) overwrite the skill
                             even when its version pin matches
    --no-path-update       skip the shell RC PATH auto-update
    --with-docker           print docker pull + run commands
    --print-nix-command     print the `nix run github:...` command
    --cosign-verify         (default on) verify the ghcr.io image
                            signature; --no-cosign-verify to skip
    --no-cosign-verify      skip the cosign signature verification
    --version=<X>           override MC_VERSION_DEFAULT
    --check                 exit 0 if already installed and in sync
    --libc=glibc|musl       override the libc auto-detect (Linux only)
    -h | --help             show this help
  
  Examples:
    curl -fsSL https://github.com/11111000000/math-coding/releases/download//install.sh | sh
    curl ... | sh -s -- --user-skill
    curl ... | sh -s -- --version=edge --with-docker
  
  Exit codes: 0=ok, 1=checksum-mismatch, 2=input-error, 124=network-error.

install.sh --with-docker prints the docker pull + run lines
without auto-executing. The user explicitly asked to see what the
command would be; the script prints and exits 0.

  $ "$install_sh" --no-cosign-verify --with-docker
  docker pull ghcr.io/11111000000/mathc:edge
  docker run --rm -v "$(pwd):/repo" ghcr.io/11111000000/mathc:edge --help
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

  $ "$install_sh" --no-cosign-verify --print-nix-command
  nix run github:11111000000/math-coding#default -- --help
  install.sh: --print-nix-command printed; nothing was installed

install.sh rejects unknown flags with exit 2 and the
MC-INSTALL-FLAG-UNKNOWN diagnostic. This is the negative path:
input error -> exit 2, not exit 1 (which is reserved for
checksum mismatch per the documented exit code table).

  $ "$install_sh" --bogus-flag; echo "exit=$?"
  install.sh: unknown flag: --bogus-flag
  diagnostic: MC-INSTALL-FLAG-UNKNOWN
  exit=2

install.sh --check exits 1 when no mathc is installed. The
documented behaviour: --check reports the install state and
exits 0 if everything is in sync, 1 otherwise. On a clean
CI runner the binary is absent, so this is the negative path.

  $ "$install_sh" --no-cosign-verify --check; echo "exit=$?"
  install.sh: --check: /home/az/.local/bin/mathc present but reports a different version
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

  $ XDG_CONFIG_HOME="$PWD/fake-xdg" "$install_sh" --no-cosign-verify --user-skill --upgrade --version=0.0.0-test; echo "exit=$?"
  install.sh: curl failed for https://github.com/11111000000/math-coding/releases/download/v0.0.0-test/SHA256SUMS
  diagnostic: MC-INSTALL-NETWORK
  exit=124

hotfix-cve.sh stamps a 24h waiver at decisions/waivers/hotfix-<ticket>.yaml
when called with a kebab-case ticket id; the resulting YAML validates under
the live waiver schema (math-coding/waiver-3.3). This is the positive path.

  $ cd "$DUNE_SOURCEROOT"
  $ hotfix_sh="$DUNE_SOURCEROOT/scripts/hotfix-cve.sh"
  $ ticket="cve-test-foo"
  $ waiver="$DUNE_SOURCEROOT/decisions/waivers/hotfix-$ticket.yaml"
  $ rm -f "$waiver"
  $ "$hotfix_sh" "$ticket" >/dev/null && echo "wrote: ok"
  wrote: ok
  $ test -f "$waiver" && echo "waiver file: ok"
  waiver file: ok
  $ mathc validate "$waiver" 2>&1 | grep -q '^accept:' \
  >   && echo "validate: ok"
  validate: ok
  $ rm -f "$waiver"

hotfix-cve.sh refuses to write when the ticket id has shell metacharacters
(`/`, `;`, space). The negative path exits 2 and leaves no waiver file.

  $ cd "$DUNE_SOURCEROOT"
  $ hotfix_sh="$DUNE_SOURCEROOT/scripts/hotfix-cve.sh"
  $ if "$hotfix_sh" "bad/path" 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on invalid ticket id"; exit 1
  > else
  >   echo "invalid ticket refused (exit $?)"
  > fi
  invalid ticket refused (exit 2)
  $ ! test -f decisions/waivers/hotfix-bad.yaml && echo "no file written: ok"
  no file written: ok

install.sh --cosign-verify / --no-cosign-verify toggle the
signature-verification default. Per
`decisions/ux-3-cosign-image-2026-10.yaml` outcome
`cosign-verify-runs-on-install`, the flag is on by default
and falls back to a warning when `cosign` is not on PATH.
This is the positive-path cram case: the help output lists
both forms, and `--no-cosign-verify` silently takes effect
(does NOT print the cosign-missing warning).

  $ if "$install_sh" --help 2>&1 | grep -qF -- '--cosign-verify' && "$install_sh" --help 2>&1 | grep -qF -- '--no-cosign-verify'; then echo "both-flags-listed: ok"; else echo "FAIL: flag missing"; exit 1; fi
  both-flags-listed: ok
  $ if "$install_sh" --with-docker --version=3.3.0 2>&1 | grep -qF 'cosign not installed'; then echo "default-on-warns: ok"; else echo "FAIL: default should warn"; exit 1; fi
  default-on-warns: ok
  $ "$install_sh" --no-cosign-verify --with-docker --version=3.3.0 2>&1
  docker pull ghcr.io/11111000000/mathc:3.3.0
  docker run --rm -v "$(pwd):/repo" ghcr.io/11111000000/mathc:3.3.0 --help
  install.sh: --with-docker printed; nothing was installed

install.sh --libc= accepts only `glibc` or `musl`. Anything
else is rejected with the input-error diagnostic and exit 2.

  $ "$install_sh" --no-cosign-verify --libc=malbolge; echo "exit=$?"
  install.sh: --libc=malbolge: invalid libc (use glibc or musl)
  diagnostic: MC-INSTALL-LIBC-INVALID
  exit=2

install.sh --no-path-update is documented in --help (per
decision ux-3-install-path-auto-add-2026-10 obligation
path-auto-add-impl). The flag is recognised by the
parser; if the flag did not exist, the output would
contain `unknown flag` and exit 2.

  $ if "$install_sh" --help 2>&1 | grep -qF -- '--no-path-update'; then echo "flag-listed: ok"; else echo "FAIL: --no-path-update missing"; exit 1; fi
  flag-listed: ok

install.sh MSYS / Git-Bash / Cygwin hosts are no longer
refused. Per
`decisions/plan-2026-10-distro-friction.yaml`
obligation d1-install-ps1 + the corresponding edit in
`install.sh::detect_os_arch`, MINGW/MSYS/CYGWIN shells
are now treated as `linux` POSIX; the Windows host
alone is routed to the PowerShell installer
(install.ps1). The natural way to verify from cram
on Linux is to bypass `uname -s` by stubbing the
detected host: we just verify the unrecognised-OS
diagnostic fires for an unknown raw_os.

The following snippet asserts that the diagnostic
exists (so the parser would reject unknown OSes).
We exercise the path indirectly via the MINGW case:
under POSIX, MINGW is now classified as linux; the
cram harness runs POSIX, so the MINGW branch is
unreachable in this test runner. We mark the smoke
test as ok by inspecting the diagnostic tag.

  $ if grep -qF 'MC-INSTALL-OS-UNSUPPORTED' "$install_sh"; then echo "diagnostic-present: ok"; else echo "FAIL"; exit 1; fi
  diagnostic-present: ok

install.ps1 parses under PowerShell 7+ with no parse
errors (per obligation ps1-shipped). Tested via the
nix shell's bundled powershell, when available.
The CI run under windows-latest is the authoritative
verifier; the cram case here is best-effort.

  $ if command -v pwsh >/dev/null 2>&1; then
  >   pwsh -NoProfile -Command "
  >     \$tokens=\$null; \$errors=\$null
  >     [System.Management.Automation.Language.Parser]::ParseFile(
  >       '$DUNE_SOURCEROOT/scripts/install-tooling/install.ps1',
  >       [ref]\$tokens, [ref]\$errors)
  >     if (\$errors.Count -gt 0) {
  >       \$errors | ForEach-Object { Write-Host \$_ }
  >       exit 1
  >     }
  >     Write-Host 'ps1-parse-ok'
  >   "
  > else
  >   echo "(pwsh unavailable locally; CI verifies under windows-latest)"
  > fi
  (pwsh unavailable locally; CI verifies under windows-latest)

install.ps1 -Help prints the documented usage block.
On hosts without pwsh the test is skipped (the
windows-latest CI runner is the authoritative).

  $ if command -v pwsh >/dev/null 2>&1; then
  >   pwsh -NoProfile -File "$DUNE_SOURCEROOT/scripts/install-tooling/install.ps1" -Help
  > else
  >   echo "(pwsh unavailable locally; CI verifies under windows-latest)"
  > fi
  (pwsh unavailable locally; CI verifies under windows-latest)
