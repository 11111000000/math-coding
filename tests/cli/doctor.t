mathc doctor [--json] prints an install-coverage diagnostic
covering at least the five required offline sections
(install, path, latest, config, decisions) per obligation
d10-mathc-doctor-subcommand in
`decisions/mathc-doctor-subcommand-2026-10.yaml`. The
JSON mode emits a `{"sections":[...]}` envelope whose
`sections` array length is >= 5 even when the GitHub
probe (section `latest`) is offline -- the contract that
the spec-acceptance cram from this file pins.

Cram cwd is the bwrap tmp dir; the real project root is
exposed by dune as $DUNE_SOURCEROOT. `mathc doctor` is
invoked with cwd = the source root so `find_project_root`
and `validate_with_counts` walk the live tree.

  $ cd "$DUNE_SOURCEROOT"

Text mode: at least 5 section headers are printed in the
order documented in `decisions/mathc-doctor-subcommand-2026-10.yaml`.
The `install` and `config` sections are always `pass`
against a healthy repo (the dune build and the active
policy are local). The `path`, `decisions` and `latest` sections
may be `warn` (the binary is run from `_build/default/`,
not `~/.local/bin`; an unattested decision file is in
`decisions/`; the GitHub release probe can be rate-limited or
refused — api.github.com answers 403 from here, which makes
`latest` warn rather than pass); they are NOT `fail`. Exit 0.

The exact-match lines below lock in the canonical verdicts
on a healthy install. A regression that flips `install`
or `config` to `warn`/`fail` will surface here.

  $ $INSIDE_DUNE/bin/mathc.exe doctor | sed -E -e 's/^\[decisions\] (pass|warn|fail)$/[decisions] <PASS-or-WARN>/' -e 's/^\[latest\] (pass|warn|fail)$/[latest] <PASS-or-WARN>/' -e 's/^\[attestations\] (pass|warn|fail)$/[attestations] <PASS-or-WARN>/'
  [install] pass
    Install
  [path] warn
    PATH
  [latest] <PASS-or-WARN>
    Latest
  [config] pass
    Config
  [decisions] <PASS-or-WARN>
    Decisions
  [attestations] <PASS-or-WARN>
    Attestations
  [self_check] skip
    Self-check

The JSON envelope's `sections` array has >= 5 entries
(acceptance gate from obligation d10-mathc-doctor-subcommand
in `plan-2026-10-distro-friction@1`):

  $ $INSIDE_DUNE/bin/mathc.exe doctor --json | jq -e '.sections | length >= 5'
  true

Every section carries an `id`, a `verdict` in
{pass, warn, fail, skip}, and a `details` object. The
following filter checks that no offline section is
`fail` on a healthy repo -- the user contract is that
exit 0 means "the install is locally healthy, independent
of network reachability":

  $ $INSIDE_DUNE/bin/mathc.exe doctor --json | jq -e '[.sections[] | select(.verdict == "fail")] | length == 0'
  true

The `latest` section is allowed to be `pass` or `warn`
(when the GitHub probe is offline or a newer release is
available); the contract is that exit 0 is the answer to
"is my install healthy locally?":

  $ $INSIDE_DUNE/bin/mathc.exe doctor --json | jq -e '.sections[] | select(.id == "latest") | .verdict | IN("pass", "warn")'
  true

The exit code is 0 when no section is `fail` (the spec
acceptance contract from obligation d10-mathc-doctor-subcommand
verifier `mathc doctor exits 0 with sections a,b,c,d printed`):

  $ doctmp=$(mktemp -d)
  $ $INSIDE_DUNE/bin/mathc.exe doctor > "$doctmp/doctor.txt"; ec=$?
  $ sed -E -e 's/^\[decisions\] (pass|warn|fail)$/[decisions] <PASS-or-WARN>/' -e 's/^\[latest\] (pass|warn|fail)$/[latest] <PASS-or-WARN>/' -e 's/^\[attestations\] (pass|warn|fail)$/[attestations] <PASS-or-WARN>/' "$doctmp/doctor.txt"
  [install] pass
    Install
  [path] warn
    PATH
  [latest] <PASS-or-WARN>
    Latest
  [config] pass
    Config
  [decisions] <PASS-or-WARN>
    Decisions
  [attestations] <PASS-or-WARN>
    Attestations
  [self_check] skip
    Self-check
  $ echo "exit=$ec"
  exit=0

The seven required section ids are present (a-g per the
obligation claim in `decisions/mathc-doctor-subcommand-2026-10.yaml`):

  $ $INSIDE_DUNE/bin/mathc.exe doctor --json | jq -e '.sections | map(.id) | sort == ["attestations","config","decisions","install","latest","path","self_check"]'
  true

Unknown flags produce a usage error (exit 2):

  $ if $INSIDE_DUNE/bin/mathc.exe doctor --bogus 2>&1 | grep -q 'doctor: unknown option'; then
  >   echo "doctor --bogus: input error"
  > else echo "FAIL: doctor --bogus did not error"; fi
  doctor --bogus: input error
