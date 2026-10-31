The gate reads the SAME protected-path list as the pre-commit hook and
the release-pending workflow.

The question "which paths of this repository are protected?" had three
answers in three files, and the three did not agree: the gate said
`lib/`, the pre-commit hook said `lib/*.ml`, and the release-pending
workflow said `lib/*`. Three gates, one repository, three different
ideas of what is protected -- and nothing that could say which list a
gate meant. The list is now ONE file, `scripts/protected-paths.txt`,
and this fixture checks the third consumer against it.

THE COMPARISON IS BETWEEN TWO IMPLEMENTATIONS. The gate matches with
`lib/protected_paths.ml` (OCaml), the shell matcher with
`scripts/protected-paths.sh` (a shell `case`). They implement the same
rule, and this fixture asks both about the same paths and requires
them to agree. The expectation is not written out here: it is
COMPUTED, from the list, by the shell matcher -- so a list that
changes does not need this file to change with it.

THE GATE'S ANSWER IS READ THROUGH ITS OWN BEHAVIOUR: the §20
CoCommitDecision rule fires (`block`) when the change touches a
protected path and neither a sibling decision nor a resolving
`Refs:` trailer is there.

THE POLICY FLOORS ARE PINNED AWAY, and that is deliberate. Two of the
§20 rules can fire on a protected path: the precedence rule (a
change to a path with a `standard` floor needs a decision) and the
co-commit rule (the same, for a protected path). With the policy
floors in place both fire together, and the verdict cannot say WHICH
rule fired -- so the fixture would be measuring the policy, not the
protected-path list. With no policy file every path's mode is `tiny`,
the precedence rule is exempt, and the co-commit rule is the only
rule that can fire. That is the rule under test.

MATH_CODING_DECISIONS_DIR and MATH_CODING_POLICIES are pinned
because this fixture runs from a temp git repo outside the project
root. MATH_CODING_ROOT is pinned to the source root because the
protected-path list is read from the PROJECT, and the project here is
the repository under test.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ export tmp
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial

The probe set: one path per pattern in the list (the pattern's last
star replaced by a file name), plus paths no pattern may match.

  $ sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$DUNE_SOURCEROOT/scripts/protected-paths.txt" | sed -e 's#\*#probe#g' > "$tmp/probes"
  $ printf '%s\n' README.md docs/probe scripts/probe tests/cli/probe >> "$tmp/probes"
  $ cat "$tmp/probes"
  bin/probe
  lib/probe
  spec/probe
  schemas/probe
  axioms/probe
  scripts/install-tooling/probe
  README.md
  docs/probe
  scripts/probe
  tests/cli/probe

The gate and the shell matcher, asked about every probe. `block` means
the CoCommitDecision rule fired, which means the path is protected.

  $ while IFS= read -r p; do
  >   mkdir -p "$(dirname "$p")"
  >   echo x > "$p"
  >   git add -A
  >   git commit -q -m "change $p"
  >   v=$(MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICIES="$tmp/no-policies.yaml" MATH_CODING_ATTESTATION_STORE="$tmp/no-store" $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD 2>/dev/null | jq -r .verdict)
  >   if [ "$v" = "block" ]; then g=protected; else g=not-protected; fi
  >   if bash "$DUNE_SOURCEROOT/scripts/protected-paths.sh" match "$p"; then m=protected; else m=not-protected; fi
  >   if [ "$g" = "$m" ]; then r=agree; else r=DISAGREE; fi
  >   echo "$p gate=$g matcher=$m $r"
  >   git reset -q --hard HEAD~1
  > done < "$tmp/probes"
  bin/probe gate=protected matcher=protected agree
  lib/probe gate=protected matcher=protected agree
  spec/probe gate=protected matcher=protected agree
  schemas/probe gate=protected matcher=protected agree
  axioms/probe gate=protected matcher=protected agree
  scripts/install-tooling/probe gate=protected matcher=protected agree
  README.md gate=not-protected matcher=not-protected agree
  docs/probe gate=not-protected matcher=not-protected agree
  scripts/probe gate=not-protected matcher=not-protected agree
  tests/cli/probe gate=not-protected matcher=not-protected agree

Every answer agrees, and the answers are not vacuous: six paths are
protected and four are not, so a gate that protected everything -- or
nothing -- would be caught here.

THE NEGATIVE CONTROL. A gate that reads a DIFFERENT list must answer
differently. So the list is copied, one extra pattern is added, and
the gate is pointed at the copy: `docs/probe` is protected in the copy
and not in the canonical list, and the gate must now say so. If it
did not, the comparison above would be comparing a thing with itself.

  $ cp "$DUNE_SOURCEROOT/scripts/protected-paths.txt" "$tmp/perturbed.txt"
  $ printf 'docs/*\n' >> "$tmp/perturbed.txt"
  $ mkdir -p docs
  $ echo x > docs/probe
  $ git add -A
  $ git commit -q -m "change docs/probe"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICIES="$tmp/no-policies.yaml" MATH_CODING_ATTESTATION_STORE="$tmp/no-store" MATH_CODING_PROTECTED_PATHS="$tmp/perturbed.txt" $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD 2>/dev/null | jq -r .verdict
  block
  $ cd /
  $ rm -rf "$tmp"
