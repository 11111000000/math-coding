`mathc` must resolve the project the OPERATOR is standing in, and it
must enumerate that project's decisions RECURSIVELY and identify each
decision by its ID rather than by the name of the file it sits in.

Two defects, one root cause each, measured on the same corpus.

THE ROOT RESOLUTION ORDER. `find_project_root` climbed from the
executable's own directory BEFORE it climbed from the caller's
directory, because a reader run from anywhere inside the kernel's
checkout should find that checkout. The theory is right; the ORDER is
wrong. With a source build the binary lives under a `dune-project`
ancestor — the KERNEL's own checkout — and that ancestor won the race
against the operator's directory.

MEASURED, on a one-decision adopter project with its own git
repository and no `dune-project`:

installed binary (~/.local/bin/mathc): decisions 1, obligations 1 -- OK
build-tree binary (_build/install/default/bin/mathc): decisions 253, obligations 892 -- WRONG
build-tree binary, mathc self-check: 252 subjects, first one `release-pending-real-staleness-2026-10`, verdict `fail`

An independent run of the same measurement on the same day saw 254
and 893: the corpus grew by one decision between the two runs. The
phenomenon is the same.

The build-tree binary read the KERNEL's corpus and exited 1 because
the KERNEL's corpus is red — not because the adopter's decision was
unmet. The adopter's decision was never looked at. The installed
binary was right only by accident: it has no `dune-project` ancestor,
so the climb from its own directory found nothing and the walk fell
through to the operator's directory.

Underneath the order sat a second defect: the climb looked for a
`dune-project` only. An adopter's project is not a dune project — it
is a repository with `.math-coding/` in it — so even with the order
fixed the climb would have found nothing and fallen back to the
binary's tree again. The climb now recognises the math-coding layout
markers as well.

THE ENUMERATION. The corpus was walked with `Sys.readdir`, which
names the entries of ONE directory. A decision filed in a
sub-directory was in no corpus at all: not in `mathc self-check`, not
in `mathc packages`, not in `mathc counters`. And what counted as a
decision was decided by FILE NAME, so a decision whose id differed
from its file name was reached only by luck.

The fixture below pins all three halves on a synthetic two-decision
project: one decision whose file name differs from its id, one
decision filed in a sub-directory. The project has its own git
repository and NO `dune-project`, so it exercises the layout marker
as well as the order.

Acceptance gate for obligation `the-corpus-is-resolved-by-id` in
`decisions/decision-resolution-2026-10.yaml`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ mkdir -p "$tmp/proj/.math-coding/decisions/nested" "$tmp/proj/.math-coding/attestations" "$tmp/proj/src" "$tmp/bin"
  $ cd "$tmp/proj"
  $ git init -q .
  $ git config user.email t@example
  $ git config user.name t
  $ echo 'print(1)' > src/main.py
  $ git add -A
  $ git -c user.email=t@example -c user.name=t commit -qm init

The first decision: the file name is `probe-file-name.yaml`, the id
is `probe-alpha`. The second: filed in a sub-directory, file name
`probe-nested.yaml`, id `probe-beta-in-subdir`.

  $ cat > "$tmp/proj/.math-coding/decisions/probe-file-name.yaml" <<'EOF'
  > ---
  > schema: math-coding/3.2
  > id: probe-alpha
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  > intent: |
  >   A probe decision whose file name differs from its id.
  > commitment: |
  >   The corpus finds it by id.
  > counterexample: |
  >   A decision whose file name equals its id would not exercise the rule.
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: alpha-outcome
  >     statement: The decision is found.
  > obligations:
  >   - id: alpha-obligation
  >     claim: The decision is in the corpus.
  >     acceptance:
  >       all:
  >         - verifier: file-exists src/main.py
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > EOF
  $ cat > "$tmp/proj/.math-coding/decisions/nested/probe-nested.yaml" <<'EOF'
  > ---
  > schema: math-coding/3.2
  > id: probe-beta-in-subdir
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  > intent: |
  >   A probe decision filed in a sub-directory.
  > commitment: |
  >   The corpus walks sub-directories.
  > counterexample: |
  >   A decision at the top level would not exercise the rule.
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: beta-outcome
  >     statement: The decision is found.
  > obligations:
  >   - id: beta-obligation
  >     claim: The decision is in the corpus.
  >     acceptance:
  >       all:
  >         - verifier: file-exists src/main.py
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe rehash "$tmp/proj/.math-coding/decisions/probe-file-name.yaml" --write > /dev/null
  $ $INSIDE_DUNE/bin/mathc.exe rehash "$tmp/proj/.math-coding/decisions/nested/probe-nested.yaml" --write > /dev/null

HALF ONE — the project the operator stands in. The binary under test
is the build-tree one (`mathc` on PATH), which lives under the
kernel's own `dune-project`. The corpus it reports must be the
operator's two decisions, not the kernel's 268.

  $ $INSIDE_DUNE/bin/mathc.exe counters --format=json | jq -c '{decisions: .decisions.total, decision_count: .obligations.decision_count, obligations: .obligations.total}'
  {"decisions":2,"decision_count":2,"obligations":2}

The same two decisions are the package list, keyed by ID — the
nested one included.

  $ $INSIDE_DUNE/bin/mathc.exe packages --format=json | jq -c '.decisions | map(.decision_id) | sort'
  ["probe-alpha","probe-beta-in-subdir"]

And the same two are the self-check subjects. The verdict is
`unknown` (no attestations yet), which is a verdict about the
operator's project — not the kernel's `fail`.

  $ $INSIDE_DUNE/bin/mathc.exe self-check 2>/dev/null | jq -c '{verdict, subjects: (.subjects | length), names: [.subjects[].name] | sort}'
  {"verdict":"unknown","subjects":2,"names":["probe-alpha","probe-beta-in-subdir"]}

The exit code of the self-check is the operator's corpus verdict, not
the kernel's. `unknown` is non-zero by constitution Invariant 14, and
the number is 3 — not 1, which is what the kernel's own red corpus
produces.

  $ $INSIDE_DUNE/bin/mathc.exe self-check > /dev/null 2>&1; echo "EXIT=$?"
  EXIT=3

HALF TWO — resolution BY ID, not by file name. `mathc find
--obligation=` looks the decision up by the id it declares. The
nested decision is found.

  $ $INSIDE_DUNE/bin/mathc.exe find --obligation=beta-obligation | jq -c '.decisions | map(.decision_id)'
  ["probe-beta-in-subdir"]

The id that differs from the file name is the one that is reported —
the file name never appears.

  $ $INSIDE_DUNE/bin/mathc.exe find --obligation=alpha-obligation | jq -c '.decisions | map(.decision_id)'
  ["probe-alpha"]

HALF THREE — the installed binary. The same binary, copied OUT of the
kernel's tree (so it has no `dune-project` ancestor at all), run in
the same directory, reports the same corpus. The operator's verdict
does not depend on where the binary happens to live.

  $ cp "$INSIDE_DUNE/bin/mathc.exe" "$tmp/bin/mathc"
  $ cd "$tmp/proj"
  $ "$tmp/bin/mathc" counters --format=json | jq -c '{decisions: .decisions.total, obligations: .obligations.total}'
  {"decisions":2,"obligations":2}
  $ "$tmp/bin/mathc" packages --format=json | jq -c '.decisions | map(.decision_id) | sort'
  ["probe-alpha","probe-beta-in-subdir"]

HALF FOUR — a decision in a sub-directory is RESOLVED BY ITS ID, not
guessed at. `mathc attest-batch --run-per-obligation` looks the
decision up by the id the manifest names. The pre-fix index was
built from a FLAT walk of the decisions directory, so a decision
filed in a sub-directory was not in it; the lookup fell through to
the concatenation `<id>.yaml`, the file was not there, and the
verdict was `fail` with the materials digest of NOTHING
(`e3b0c442...` is the sha256 of the empty string). The batch still
wrote the attestation, so the failure was silent: a decision that
was never read was recorded as a decision that failed.

  $ cd "$tmp/proj"
  $ printf 'probe-beta-in-subdir\tbeta-obligation\ttest\tmanual:probe\n' > manifest.tsv
  $ mkdir -p out
  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --manifest=manifest.tsv --out=out --run-per-obligation > /dev/null 2>&1
  $ jq -e '.result == "pass" and .subject.materials_digest != "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"' out/probe-beta-in-subdir-beta-obligation.json
  true

HALF FIVE — the operator's directory wins over the KERNEL's tree,
`DUNE_SOURCEROOT` is dune's build-time anchor; in this repository it
names the kernel's checkout. A caller standing in another project
must not be answered from the kernel's checkout.

  $ cd "$tmp/proj"
  $ DUNE_SOURCEROOT="$DUNE_SOURCEROOT" $INSIDE_DUNE/bin/mathc.exe counters --format=json | jq -c '.decisions.total'
  2

And the sub-directory walk is independent of the root: the decision
filed under `nested/` is in the corpus of the project that holds it,
and it is NOT in the kernel's corpus under a different id (there is
no such decision there — the kernel's corpus is a different corpus).

  $ cd "$tmp/proj"
  $ $INSIDE_DUNE/bin/mathc.exe packages --format=json | jq -c '[.decisions[] | select(.decision_id == "probe-beta-in-subdir")] | length'
  1

Cleanup.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf "$tmp"
