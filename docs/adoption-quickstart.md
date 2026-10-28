# Adoption quickstart

Empty repository to a green `mathc self-check`, in ten minutes. Every
command below is in this tree today; every output block is what the
command prints. Install channels: [README.md](../README.md) and
[QUICKSTART.md](../QUICKSTART.md); the rule for when to apply the
protocol, and the AI-agent skill: [adoption/SKILL.md](../adoption/SKILL.md).
Apply it only when one of that document's signals holds; if none does,
stop here -- the minutes are yours, and the burden of proof is yours.

## 1. Install (1 minute)

```bash
curl -fsSL https://github.com/11111000000/math-coding/releases/download/edge/install.sh \
  | sh -s -- --user-skill
export PATH="$HOME/.local/bin:$PATH"
mathc version
```

## 2. Give the repository a commit (2 minutes -- the evidence names a tree)

```bash
git init
mkdir -p src
echo 'print(1)' > src/main.py
git add -A && git commit -m "initial project"
```

## 3. Bootstrap (10 seconds)

```bash
mathc init . --no-install
```

```
mathc init: created ./.math-coding/decisions, ./.math-coding/attestations
  decision.yaml: schema math-coding/3.2, scope paths editable
  pre-commit hook: skipped (--no-install)
  applicability envelope (spec/algebra-3.2.md §28, default-on):
  ...
```

Three things appear: the active policy `.math-coding/policy.yaml`, an
empty decisions directory, an empty attestation store. Edit the policy:
`scope.paths` and the obligation's `file-exists` verifier must name the
same real path -- one the project has.

## 4. Write your first decision (5 minutes)

```bash
mathc new-decision my-first-decision --write
```

```
deficit/MC-SCOPE-PLACEHOLDER: scope.paths still names the placeholder <path/glob/that/this/decision/touches/**>; a scope that matches no file makes the materials digest a digest of nothing, and an empty digest is the freshness wildcard. Replace it with the paths this decision actually covers.
mathc new-decision: wrote /your/project/.math-coding/decisions/my-first-decision.yaml
```

The scaffold is a blank form, not an argument. Replace every `TODO`
with your own words: intent, commitment, outcome, `scope.paths`, the
obligation's claim and its `verifier` (something the kernel can run:
`file-exists <path>`, `mathc <subcommand>`, a `tests/` or `scripts/`
path), risk trigger, owner, counterexample.

## 5. Hash it, then let the kernel read it (30 seconds)

```bash
mathc rehash --write .math-coding/decisions/my-first-decision.yaml
mathc validate .math-coding/decisions/my-first-decision.yaml
```

```
  STAMP my-first-decision.yaml

rehash: 1 changed, 0 already current, 0 skipped (written)
```

```
parse-ok: .math-coding/decisions/my-first-decision.yaml
  decision: my-first-decision
  revision: 1
  obligations: 1
  assumptions: 0
```

`rehash` computes the digest (`body_sha`, `yaml_sha`), `validate` parses
the file. Run `rehash` again after every edit.

## 6. Evidence, commit, green gate (2 minutes)

```bash
mathc attest-batch --kind=review --producer=human:me
git add -A && git commit -m "first decision"
mathc self-check | jq -c '{verdict, subjects: [.subjects[] | {name, verdict}]}'
```

`attest-batch` writes one JSON per obligation into
`.math-coding/attestations/`; the store admits only files git tracks,
so the attestation has to be in the commit. Then:

```
{"verdict":"pass","subjects":[{"name":"my-first-decision","verdict":"pass"}]}
```

`mathc self-check` exits 0. Commit, then check.

## What `unknown` means

`unknown` is not a failure: it is the kernel saying it has no verdict
yet, and it exits 3. `pass` and `fail` carry a conclusion. A fresh
bootstrap, with no decision yet:

```
{"verdict":"unknown","subjects":[]}
```

A decision with no evidence yet has an `unknown` subject whose cause
names the obligation with no attestation in the store. That obligation
is unproven, not broken: the kernel never promotes `unknown` to `pass`
on its own. One attestation, committed, turns it into `pass`.
