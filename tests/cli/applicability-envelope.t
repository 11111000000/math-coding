Applicability envelope decision tree (kernel contract §28):
the formula applicability(P, 𝒫) = value(P, 𝒫) - friction_user(P, 𝒫)
drives Path A (full 3.2) vs Path C (no math-coding) choice.

This fixture encodes the decision question from USAGE.md:
"Does your project coordinate ≥2 AI agents, require regulatory audit,
or will it live ≥5 years with 3+ contributors?"

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

The algebra file exists and is normative (kernel contract §28):
  $ test -f "$DUNE_SOURCEROOT/spec/kernel-contract.md" && echo "spec present" || echo "spec missing"
  spec present

The decision file exists (bootstrap of applicability):
  $ test -f decisions/algebra-3.2.yaml && echo "decision present" || echo "decision missing"
  decision present

Applicability envelope is functional when:
1. spec/kernel-contract.md published (passed above)
2. decisions/algebra-3.2.yaml accepted (passed above)
3. the ROADMAP makes no open promise about it. The ROADMAP used to
count three "Tier 3.5" mentions; the census collapsed the closed
tiers into a paragraph of history, so the count is zero -- and zero
is the point: an open tier in the priority document is an obligation
nobody is holding.
  $ grep -c 'Tier 3.5' ROADMAP.md || true
  0
