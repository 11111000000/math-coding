# ADR: the claims of one battery at the same time

## Status

Proposed. The owner decides. Nothing in this document changes the method: the
claims still run one after another, and the evidence still says where it was
produced.

## Context

The battery of the project is the wall of the gate. The run of 2026-11-28
(run 46129797514) spent 720.4 s of machine time in 31 claims, and the step
that holds it is the whole of the `portable` job:

| Claim | Machine time |
|---|---:|
| console-generations | 105.6 s |
| site-interface | 104.6 s |
| workspace-preview | 103.6 s |
| human-queue | 102.7 s |
| console-trust-boundary | 80.9 s |
| cli-evidence | 34.2 s |
| protected-stand | 24.6 s |
| the other 24 claims | 163.2 s |

Eight claims run the console, and they take about three quarters of the time.
The gate of `main` now takes about 14 minutes: the quick gate and the battery
run side by side, the job of the pages reads the evidence of the battery
instead of running it a second time, and the deployment is retried.

The question this document answers is whether the claims of one battery may
run at the same time, and what that would cost the method.

## The three ways to make the battery cheaper

1. **Risk scaling.** The method already chose this on 2026-11-26: a claim
   declares its risk, a low-risk claim is recorded without a negative
   control, and the battery of the owner shrinks to the claims that carry
   the risk. This is the sanctioned answer, and it is on the line of
   improvements.
2. **Splitting the battery between the jobs of the runner.** Every job
   executes its own group of the claims and carries its evidence as a
   bundle; the groups are joined before the map is read. The bundle is the
   portable form of the evidence and already exists. What is missing is the
   selection: `run` knows `--changed` and `--limit`, and it cannot name the
   claims of a group.
3. **Running the claims of one run at the same time.** The run would take
   the claims from a queue and give each of them a worker.

## What the third way would cost the method

The check of a claim runs in the working tree, and that is where the
evidence comes from. Two claims at the same time cannot share one tree: the
checks of the console write into `node_modules`, into the build of the page
and into the site, and the checks of dune write into `_build`.

Every claim would therefore need a tree of its own. The copy of the tree
that the negative control already uses is such a tree, and it is not a
neutral one:

- it is a clone, and the clone stages the whole tree (`git add -A`), so a
  check that reads the state of the git of the tree reads a different state
  than the tree it was made of;
- it carries no packages, and the checks of the console install them again
  in every copy;
- the copy is taken before the check of the claim runs, so that the copy is
  the subject as it was and not the subject with the traces of the check.

The evidence would still bind to the tree as it is, because the binding is
the digest of the content of the subject. But the statement "the check ran in
the working tree" would become false, and that statement is one the method
makes to the reader of a map.

The scripts of the console hold a second rule: the heavy steps run two at a
time, because three node processes at once do not fit on a small machine. A
battery of eight console claims at the same time breaks that rule by a
factor of four.

The report of a run is the order of the claims, and the journal is
append-only. A run at the same time must keep both orders, and the journal
of two workers at once needs a lock that the method does not have today.

## What was measured and refused

- **The packages of the console from the store.** A derivation with a fixed
  output would have made the install of a copy a link. The sandbox of a
  machine has no network for npm, and the build of such a derivation stood
  still for half an hour here and for eleven minutes on the runner (pull
  requests #14 and #16, closed). The cache of the downloads replaced it
  (pull request #17).
- **The copies borrowing the packages of the tree.** The battery with the
  cache of the downloads spent 676.1 s in 31 claims (run 46127156924), and
  706.1 s with the copies borrowing them (run 46128135833). The saving and
  the cost cancelled each other, and the copies stopped being isolated from
  the tree (pull request #18, closed).

## The question for the owner

Whether the claims of one battery may run at the same time, and if they
may, which of the two ways the method accepts:

- the battery is split between the jobs of the runner, and the tool learns
  to name a group of claims and to carry the evidence of the group as a
  bundle. The method keeps its statements: every check still runs in a
  working tree, and the tree of a claim is the tree of the run.
- the claims of one run run at the same time, each in a tree of its own.
  The method must then say that the check of a claim runs in a copy of the
  working tree, and the rule of the two node processes must be rewritten.

The first way is the work of the tool and the workflow. The second way is a
change of the method, and it goes with the ritual of the change of the
build.
