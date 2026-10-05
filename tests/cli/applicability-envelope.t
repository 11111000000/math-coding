Applicability envelope decision tree (algebra §28):
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

The algebra file exists and is normative (algebra §28):
  $ test -f spec/algebra-3.2.md && echo "spec present" || echo "spec missing"
  spec present

The decision file exists (bootstrap of applicability):
  $ test -f decisions/algebra-3.2.yaml && echo "decision present" || echo "decision missing"
  decision present

Applicability envelope is functional when:
1. spec/algebra-3.2.md published (passed above)
2. decisions/algebra-3.2.yaml accepted (passed above)
3. Tier 3.5 implementation tracked in ROADMAP.md:
  $ grep -c 'Tier 3.5' ROADMAP.md
  4
