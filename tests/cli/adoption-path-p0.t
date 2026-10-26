mathc init, mathc new-decision, mathc attest-batch and mathc self-check
reach the SAME store, and the scaffold the kernel writes is a file the
kernel accepts.

The defect this pins. `mathc init` scaffolds `.math-coding/attestations`
and `mathc attest-batch` writes there — both resolve through
`Path_config`. But `mathc self-check` and `mathc gate` read the store
through `bin/Mathc.ml::resolve_store_root`, which hard-coded the
pre-3.4 path `attestations/`. So in a project scaffolded by the
kernel's own `mathc init`, the evidence existed and the gate could not
see it: `mathc packages` reported `pass` for the obligation and
`mathc self-check` reported "has no attestations in the store", in the
same directory, with the same binary. The project could never turn its
own gate green.

Three properties are asserted, and each of them fails against the
pre-fix binary. First: the scaffold `mathc new-decision` writes is a
file `mathc validate` ACCEPTS (the pre-fix default template lacked
`axiom_link` and was rejected with MC-AXIOM-LINK-MISSING). Second: the
attestation lands in `.math-coding/attestations` AND the gate reads it
from there (the pre-fix gate read `attestations/`). Third: `mathc
self-check` exits 0 on that project (the pre-fix gate reported
`unknown`, exit 3, for ever).

The producer and the gate must also agree on the MATERIALS DIGEST: the
pre-fix producer anchored its git lookups at the parent of the
decisions directory, which under the forward layout is `.math-coding/`
— a subtree of the project, not the project. `git ls-tree` is
CWD-relative, so the scope `src/**` matched nothing and the producer
wrote the digest of NOTHING, which the gate (anchored at the project
root) never computed. Same quantity, two authorities, two values.

Setup: an isolated project at $tmpdir, a git repository, one source
file under src/.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"
  $ echo '(lang dune 3.0)' > "$tmpdir/dune-project"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ git init -q .
  $ mkdir -p src
  $ echo 'print(1)' > src/main.py
  $ git add -A
  $ git -c user.email=t@example -c user.name=t commit -qm init

`mathc init` creates the forward layout.

  $ mathc init . > /dev/null
  $ ls .math-coding
  attestations
  decisions
  policy.yaml

The scaffold `mathc new-decision` writes is a file the kernel accepts.
The pre-fix default template carried no `axiom_link` and was rejected.

  $ mathc new-decision p0-probe --write 2>&1 | grep -c 'wrote'
  1
  $ mathc validate .math-coding/decisions/p0-probe.yaml 2>&1 | grep -c '^parse-ok'
  1

The scope placeholder is reported rather than shipped silently: a scope
that matches no file makes the materials digest a digest of nothing,
and an empty digest is the freshness wildcard.

  $ mathc new-decision p0-probe-2 --write 2>&1 | grep -c 'MC-SCOPE-PLACEHOLDER'
  1
  $ rm -f .math-coding/decisions/p0-probe-2.yaml

The decision is filled in and re-hashed; the digest is the kernel's own.

  $ sed -i 's|<path/glob/that/this/decision/touches/\*\*>|src/**|' .math-coding/decisions/p0-probe.yaml
  $ sed -i 's|<TODO: fixture-path-or-kernel-verifier>|file-exists src|' .math-coding/decisions/p0-probe.yaml
  $ sed -i 's|<TODO: what-could-go-wrong>|src-changed-without-a-decision|' .math-coding/decisions/p0-probe.yaml
  $ sed -i 's|<human:role or human:name>|human:maintainer|' .math-coding/decisions/p0-probe.yaml
  $ mathc rehash --write .math-coding/decisions/p0-probe.yaml > /dev/null
  $ mathc rehash .math-coding/decisions/p0-probe.yaml | tail -1
  rehash: 0 changed, 1 already current, 0 skipped (dry-run)

The attestation lands in the forward layout — the same place `mathc
init` created and the same place the gate reads.

  $ mathc attest-batch --from=decisions --kind=review --producer=human:t > /dev/null 2>&1
  $ ls .math-coding/attestations
  p0-probe-p0-probe-obligation-1.json
  $ test -d attestations && echo "legacy dir exists" || echo "no legacy dir"
  no legacy dir

The producer and the gate agree on the materials digest: the
attestation carries the digest of the scope's CONTENT. The property is
asserted, not the literal — the digest is a function of the content of
`src/**`, so pinning a hex value would move with every edit. The
property that matters is that it is NOT the digest of nothing: the
empty-scope digest is sha256("") with the "sha256:" prefix, and that
is the wildcard the pre-fix producer wrote.

  $ python3 -c "import json;print(json.load(open('.math-coding/attestations/p0-probe-p0-probe-obligation-1.json'))['subject']['materials_digest'])" | grep -vc 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
  1

The gate reads the store and the subject passes: exit 0.

  $ git add -A
  $ git -c user.email=t@example -c user.name=t commit -qm attested
  $ mathc self-check > /dev/null; echo "exit=$?"
  exit=0
  $ mathc self-check | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['verdict']);print([ (s['name'],s['verdict']) for s in d['subjects']])"
  pass
  [('p0-probe', 'pass')]

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
