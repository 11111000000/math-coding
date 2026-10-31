The scaffold `mathc new-decision` writes must be a document a strict
parser can read, and the risk block must be where the schema expects
it.

TWO DEFECTS, both measured on the file the kernel wrote on 2026-10-31:

1. The verifier placeholder was unquoted:
`- verifier: <TODO: fixture-path-or-kernel-verifier>` carries a
colon-space inside a plain scalar, and a strict parser answers
"mapping values are not allowed here". The scaffold was not YAML, so
it could not be filled in by a tool and could not be read back by
anything but the kernel's own forgiving reader.

2. The risk block sat INSIDE the counterexample scalar, indented
under it. A parser reads the owner and the declared triggers as part
of the counterexample's TEXT: the parsed decision had no risk at all.
The kernel then filled the gap with its own default
(`owner: human:maintainer`), and the triggers the author wrote were
gone - silently, in a file that looked complete.

The second defect is the worse one: a scaffold that does not parse is
a mistake the author sees, and a scaffold whose risk disappears is a
promise the kernel keeps on the author's behalf without asking.

PyYAML is the strict reader here, and it is in the test environment
(`nix develop .#test`). The check is written once and used twice: on
the scaffold the kernel writes, and on the two shapes it used to
write.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ touch dune-project
  $ cat > check.py <<'PY'
  > import sys, yaml
  > try:
  >     d = yaml.safe_load(open(sys.argv[1]))
  > except Exception as e:
  >     print("rejected: not YAML (%s)" % type(e).__name__)
  >     raise SystemExit(0)
  > risk = d.get("risk") if isinstance(d, dict) else None
  > if not isinstance(risk, dict) or "owner" not in risk or "declared_triggers" not in risk:
  >     print("rejected: the decision has no risk")
  >     raise SystemExit(0)
  > print("accepted: risk.owner=%s triggers=%d" % (risk["owner"], len(risk["declared_triggers"])))
  > PY

The scaffold the kernel writes parses, and its risk is a MAP with the
two keys the schema declares - not text inside another field.

  $ $INSIDE_DUNE/bin/mathc.exe new-decision scaffold-probe > scaffold.yaml
  $ python3 check.py scaffold.yaml
  accepted: risk.owner=<human:role or human:name> triggers=1

The verifier placeholder survives as a STRING, so the author sees it
and the parser does not trip over it.

  $ python3 -c "import yaml;d=yaml.safe_load(open('scaffold.yaml'));print(d['obligations'][0]['acceptance']['all'][0]['verifier'])"
  <TODO: fixture-path-or-kernel-verifier>

The first control: the old shape, with the placeholder unquoted. It
is not YAML, and the check says so.

  $ cat > old-unquoted.yaml <<'YAML'
  > ---
  > schema: math-coding/3.3
  > id: old-unquoted
  > obligations:
  >   - id: o1
  >     claim: |
  >       x
  >     acceptance:
  >       all:
  >         - verifier: <TODO: fixture-path-or-kernel-verifier>
  > YAML
  $ python3 check.py old-unquoted.yaml
  rejected: not YAML (ScannerError)

The second control: the old shape with the risk under the
counterexample. This one IS valid YAML - which is why the defect
survived - and it has no risk, so the check rejects it for the second
reason.

  $ cat > old-swallowed-risk.yaml <<'YAML'
  > ---
  > schema: math-coding/3.3
  > id: old-swallowed-risk
  > counterexample: |
  >   TODO: the strongest practical objection to this decision.
  >     risk:
  >     declared_triggers:
  >     - <TODO: what-could-go-wrong>
  >   owner: <human:role or human:name>
  > YAML
  $ python3 check.py old-swallowed-risk.yaml
  rejected: the decision has no risk

The kernel reads the scaffold too, and it reads the risk it now has.

  $ $INSIDE_DUNE/bin/mathc.exe validate scaffold.yaml 2>&1 | grep -o 'verifier scheme "[^"]*" is not in the canonical list'
  verifier scheme "<TODO:" is not in the canonical list
