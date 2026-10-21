# Plan-2026-11 template fixes (F5, F6, F7, F8)

> This document records the 4 docs-only template fixes that
> the orchestrator applies as part of the plan-2026-11-
> adoption-fixes plan-doc commit. They are absorbed into
> `docs/experiments/brownfield-experiment-v2-2026-10.md`
> and `docs/experiments/adoption-2026-10-agent-template.md`
> per the discriminator verdicts. No sub-decision is filed;
> the orchestrator does the edits as part of the plan-doc
> commit.

## F5: Pre-flight: verified-by-clone

Add to `docs/experiments/adoption-2026-10-agent-template.md`
(before §3 hypotheses):

> ### Pre-flight: verified-by-clone
>
> Every candidate project must include the one-line shell
> transcript
>
> ```
> git clone --depth=1 <url> /tmp/check \
>   && git -C /tmp/check ls-tree --name-only -r HEAD \
>      | grep -E '(^|/)(docs/adr|adr|docs/decisions|docs/decision)/'
> ```
>
> with a positive result. Candidates without a positive
> grep are dropped with a documented reason. This catches
> the speculative-pick class before the experiment runs.

Also: in `docs/experiments/brownfield-experiment-v2-2026-10.md`
§3, explicitly note why `opentelemetry-go`, `opa`, and
`cncf/toc` were rejected. The current §3 silently drops them
without naming the reason. The C4 verification log at
`/tmp/brownfield-v2-verify/` no longer exists, so the
original verification cannot be re-checked. Per the F5
discriminator: "the `git ls-tree` check missed `docs/decision/`
(singular) where opentelemetry-go actually keeps its ADRs."

## F6: Per-session smoke test with `mathc doctor`

Add to `docs/experiments/adoption-2026-10-agent-template.md`
(before the per-sub-decision prompt template):

> ### Per-session smoke test
>
> Every agent's first action must include
>
> ```
> mathc doctor --json | jq '.verdict'
> ```
>
> A non-`pass` result blocks the session with a documented
> exit. This catches (a) binary staleness (the original
> experiment's exact failure), (b) install drift between
> worktrees, (c) env-var resolver bugs that would otherwise
> look like agent errors.

Also add the same paragraph to
`docs/experiments/brownfield-experiment-v2-2026-10.md` §5
T1 and §5 T2 templates.

## F7: Friction disambiguation rule

Replace the orchestrator's vague "prefer upstream" rule in
`docs/experiments/adoption-2026-10-agent-template.md` (and
`brownfield-experiment-v2-2026-10.md` §7 lines 386-419)
with the discriminator's precise rule:

> ### When two codes fit
>
> When an event could be F-WORKFLOW (when-to-do-what) or
> F-SEMANTIC (kernel surprised me), prefer F-WORKFLOW if the
> agent's confusion is about which command to run next;
> prefer F-SEMANTIC if the agent's confusion is about why a
> command returned an unexpected output. **Test:** if removing
> the feature would eliminate the confusion, it's
> F-SEMANTIC; if a better onboarding doc would eliminate it,
> it's F-WORKFLOW.

File `decisions/refine-friction-disambiguation-2026-10.yaml`
(mode: light, change_kind: editorial, axiom_link: [A1])
recording the rule. Apply retrospectively to the 4
F-SEMANTIC events in §10.5 (line 459).

## F8: Implementation vs acceptance-pinning

Add to `docs/experiments/adoption-2026-10-agent-template.md`:

> ### Implementation vs acceptance
>
> If the sub-decision's plan-doc text names a kernel file
> or subcommand as the implementation target, and
> `git log` shows that file/subcommand shipped in a prior
> commit, the sub-decision's actual scope is
> `acceptance-pinning` (decision file + cram fixture +
> attestation), not `implementation`. Reduce the per-
> sub-decision time estimate accordingly (reference-class
> `single-file-edit`, not `feature-add`).

Apply retrospectively to plan-2026-10-adoption-fixes' §5
A3 description (lines 105-119 of the plan-doc) where A3's
actual scope was "pin existing implementation as acceptance
crate", not "ship the attest-batch subcommand".

