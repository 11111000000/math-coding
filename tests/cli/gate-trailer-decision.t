A COMMIT THAT CITES THE DECISION IT IMPLEMENTS NEEDS NO SECOND
DECISION FILE.

Kernel contract §5 and §20 give a change to a protected path
(`lib/**`, `bin/Mathc.ml`, `spec/**`, `schemas/**`, `axioms/**`) two
ways to name the commitment it implements:

a decision committed WITH the change (a sibling `decisions/*.yaml`);
OR a trailer that cites a decision the corpus holds
(`Refs: decision:<id>@<rev>`).

The implementation had only the first way, and that is what made the
corpus grow: a change that implemented an existing commitment wrote
a SECOND decision saying so. Those files exist -- 26 of them carried
`change_kind: implementation` -- and KERNEL_AGENTS.md §Decisions says
not to write them: "Do not create a decision for ... implementation of
an existing decision".

THE CITATION HAS TO RESOLVE. A trailer that names a decision the
corpus does not hold is not a citation; it is a string. The rule the
kernel applies is the spec's: `resolve(ref, parent(c)) != empty`.

AND THE CITED DECISION IS CHECKED. A citation that stood in for a
committed decision file, and then had none of that decision's
obligations evaluated, would be a way to skip the evidence. So the
cited decisions join the set the gate evaluates, whatever their scope
says: the citation is worth something only if the commitment it names
is verified.

The fixture pins all three readings:

a resolving citation   the change is not blocked for having no
decision file of its own;
no citation             the change IS blocked;
a dangling citation     the change IS blocked -- a string is not a
citation.

MATH_CODING_ROOT is pinned so the kernel reads the fixture's own
decisions directory; the obligation carries a verifier that is not
executed here, so the verdict is `unknown` (the evidence is missing)
rather than `pass`. What the fixture asserts is the RULE: block or
not block.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ touch dune-project
  $ mkdir -p lib decisions
  $ cat > decisions/existing.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: existing-commitment
  > revision: 1
  > state: active
  > intent: |
  >   The kernel keeps a rule about the shape of a decision.
  > commitment: |
  >   A decision document parses.
  > outcomes:
  >   - id: parses
  >     statement: |
  >       The document parses.
  > scope:
  >   paths:
  >     - "decisions/**"
  > obligations:
  >   - id: parses
  >     claim: |
  >       The document parses.
  >     acceptance:
  >       all:
  >         - verifier: "file-exists decisions/existing.yaml"
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  > counterexample: |
  >   None yet.
  > YAML
  $ printf 'x\n' > lib/a.ml
  $ git add -A && git commit -q -m initial
  $ printf 'y\n' > lib/a.ml
  $ git add -A && git commit -q -m "change the kernel" -m "Refs: decision:existing-commitment@1"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_DECISIONS_DIR="decisions" $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD | jq -c '{verdict, obligations}'
  {"verdict":"unknown","obligations":1}

The citation made the cited decision's obligation part of the
evaluation -- one obligation, the one the cited decision carries --
so the change is measured against the commitment it names.

Without a citation the protected-path rule blocks the change.

  $ printf 'z\n' > lib/a.ml
  $ git add -A && git commit -q -m "change the kernel, no citation"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_DECISIONS_DIR="decisions" $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD | jq -c '{verdict}'
  {"verdict":"block"}

A citation that names a decision the corpus does not hold resolves to
nothing, and a string is not a citation.

  $ printf 'w\n' > lib/a.ml
  $ git add -A && git commit -q -m "change the kernel, dangling citation" -m "Refs: decision:does-not-exist@1"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_DECISIONS_DIR="decisions" $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD | jq -c '{verdict}'
  {"verdict":"block"}
  $ cd /
  $ rm -rf "$tmp"
