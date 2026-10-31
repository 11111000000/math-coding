Applicability envelope decision tree (kernel contract §28): the rule
is default-on, and the kernel prints the envelope it assumed at deploy
time instead of guessing a path.

This fixture encodes the decision question from USAGE.md:
"Does your project coordinate ≥2 AI agents, require regulatory audit,
or will it live ≥5 years with 3+ contributors?"

WHAT IS NOT PINNED HERE, AND WHY. This fixture used to assert that
`decisions/algebra-3.2.yaml` exists — the decision that carried the
envelope before the contract's shrink. That is the mirror the shrink
removes: a fixture that names a decision breaks the moment the
decision is superseded, and this one was. What is pinned now is the
OWNER of the rule (a decision whose id is stable), the rule's home
(the contract is published), and the KERNEL's own answer (the envelope
the CLI prints, and the section it names).

Test that math-coding repo itself satisfies the applicability test:
  $ cd "$DUNE_SOURCEROOT"

This repo coordinates multiple agents (ci-bot, security-scanner,
review, harness):
  $ ls .githooks/ | head -3
  pre-commit

The repo has constitutional structure (axioms, 14 invariants):
  $ ls axioms/ | grep -E '^index|^separation' | head -2
  index.md
  separation.md

The rule's home is published (the contract is at its path, and it is
the document the kernel's own envelope message points at):
  $ test -f "$DUNE_SOURCEROOT/spec/kernel-contract.md" && echo "spec present" || echo "spec missing"
  spec present

The decision that OWNS the default-on rule is present and active. The
id is the corpus's and does not change with the contract:
  $ grep -m1 '^id:' decisions/solo-default-on-2026-10.yaml
  id: solo-default-on-2026-10
  $ grep -m1 '^state:' decisions/solo-default-on-2026-10.yaml
  state: active

And the kernel prints the envelope, naming the section of the contract
the rule lives in. The message is the code's own string
(`lib/init/init.ml::print_applicability_envelope`), and the full text
is asserted by `tests/cli/init.t`; here the claim is that the section
the message names is a section the document has:
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"
  $ $INSIDE_DUNE/bin/mathc.exe init . --no-install | grep -o 'kernel-contract.md §28'
  kernel-contract.md §28
  $ cd / && rm -rf "$tmpdir"

Applicability envelope is functional when:
1. the contract is published (passed above)
2. the owning decision is active (passed above)
3. the ROADMAP makes no open promise about it. The ROADMAP used to
count three "Tier 3.5" mentions; the census collapsed the closed
tiers into a paragraph of history, so the count is zero -- and zero
is the point: an open tier in the priority document is an obligation
nobody is holding.
  $ cd "$DUNE_SOURCEROOT"
  $ grep -c 'Tier 3.5' ROADMAP.md || true
  0
