# The math-coding console

The console is a Paseo plugin that lives in this repository, under `plugin/math-coding-console/`. It
puts the state of a math-coding corpus where the people who work on it already are, and it gives a
person an instrument for signing a review.

The kernel is the authority. The console asks `mathc` questions and shows the answers. It computes
no verdict of its own, because a second measurer is a second opinion nobody asked for and the two
would drift.

## The shape of it

The console is a frame and four views. The frame is the instrument's reading and is always visible:
the corpus verdict, the counts, and THE JOIN.

The join is the fact the console's earlier shape hid. The store's size and the corpus's size sat in
two panels and invited the reader to add them; the sum reads like a healthy corpus with a large
store, and the sum is not the truth. The join says how much of the store discharges a promise that
is still live, and on this repository that is a small number against a large one.

The four views answer the methodology's questions:

| View | The question | What it shows |
|---|---|---|
| **Corpus** | Where is the chain broken? | The mosaic: one cell per promise, coloured by its epistemic status, banded by the decision that promised it. |
| **This change** | May I merge? | The merge gate's own verdict, its gap kinds and the kernel's remedy for each, and the files that changed. |
| **Commitments** | What did we decide, and what still stands? | The decisions with their obligations, their axiom links, their counterexamples, and their relations. |
| **Reviews** | What must a person stand behind? | The kernel's required reviews and the manual promises, each saying what a signature means. |

The kernel's subcommands are not a view. They are verbs, and a navigation of verbs says the kernel
is a bag of commands; they live behind the Actions button.

### The mosaic

One cell per obligation. The cell's colour is the promise's EPISTEMIC STATUS, and the vocabulary is
the constitution's own:

| Cell | Meaning |
|---|---|
| observed | closed by a machine run (test / build / analysis / observation), current |
| declared | closed by a person's word (a review attestation), current |
| open | no current evidence |
| uncheckable | the corpus names no check for it at all: the paper layer |
| failed | a decisive failure |
| waived | accepted by a named, in-force, expiring waiver |

The gap kind — missing, stale, unknown — is NOT a colour. It is a debugging detail and it belongs
to the drill-down, where the chain is drawn once, vertically: decision, obligation, check, evidence,
and the gap hanging off the end that is broken.

A cell is a JOIN of three readings and the console contributes none of them: the kernel's obligation
index (`mathc packages`), the promise census (`mathc gaps`), and the store. Where the first two
disagree about the same promise, the cell carries both and the console says so; the kernel does not
always agree with itself, and a console that silently picked a side would launder.

### What the console does not do

It does not re-derive which obligations a diff touches. The kernel knows and does not expose it, so
the change view says so instead of guessing.

## What it is for

The protocol's cost is not paid in writing a decision. It is paid in looking at the corpus: to learn
whether the promises still hold, a person runs `mathc self-check`, reads a JSON document, and runs
`mathc gaps` to learn which promise is open. The review of a decision happens where nobody is
looking, because the signature is a JSON file under `attestations/` and the person who would write
it does not know whether the file is named the way the kernel expects.

The console is that instrument. `decisions/paseo-console-plugin-2026-10.yaml` records what it
promises and what holds it.

## The development loop

The plugin is installed FROM THE SOURCE DIRECTORY, so an edit reaches the running plugin without a
daemon restart. A restart would kill the agent doing the edit.

```bash
cd plugin/math-coding-console
./dev.sh              # typecheck, install, reload, status
./dev.sh reload       # reload the installed plugin without reinstalling
./dev.sh logs         # the plugin's own output
./dev.sh status       # what Paseo thinks of the plugin right now
```

`dev.sh` reads the plugin id from `MATH_CODING_CONSOLE_ID` and defaults to `math-coding-console`.
The plugin's source directory is the one `paseo plugin ls` prints in its DIRECTORY column; point it
at whichever checkout you are editing.

`show-tab.sh <tab>` makes the console open on one tab instead of the verdict, which is how a tab is
checked against a browser that cannot be driven by hand.

### Probing the console without a host

The server half of the plugin is plain Node code over the kernel, so it can be exercised against a
repository without a Paseo host in the loop:

```bash
cd plugin/math-coding-console
npx tsx scripts/probe.ts /path/to/math-coding/repo
npx tsx scripts/probe-review.ts /path/to/math-coding/repo <decision-id> <obligation-id>
```

The first prints what the console would show: the verdict, the coverage, the promise worklist, the
decisions and the review queue. The second signs a review and prints what the kernel's store holds
afterwards. Both are how the console's claims are checked while it is being written.

```bash
./scripts/render-check.sh /path/to/math-coding/repo
```

The third renders every view of the console with the corpus's own data, in Node, against the smallest
stubs that let a view render. It finds a view that throws before somebody opens that tab. It does not
prove how the console looks: that is checked by opening it in Paseo.

## What holds it

```bash
bash tests/fixtures/paseo-console-contract.sh            # what the plugin registers
bash tests/fixtures/paseo-console-kernel-authority.sh     # where its verdicts come from
bash tests/fixtures/paseo-console-mosaic.sh               # what a cell is, and where its vocabulary lives
bash tests/fixtures/paseo-console-renders.sh             # that every view renders
bash tests/fixtures/paseo-console-negative-control.sh     # that the four above can fail
```

The negative control breaks a copy of the plugin eleven ways and requires the other four fixtures to
notice each one. A check that cannot fail is not a check.

## Where the verdicts come from

| The console shows | The kernel says it |
|---|---|
| the verdict, the exit code, the digests | `mathc self-check` |
| the coverage numbers | `mathc counters`, `mathc packages` |
| the open promise worklist | `mathc gaps` |
| the promise classes | `mathc gaps` |
| each obligation's verdict | `mathc packages` |
| the diagnostic sections | `mathc doctor` |
| the diff assurance | `mathc gate` |
| a signed review | `mathc attest-batch` |

The console reads the decision files for their TEXT alone. Fifteen files in this repository carry
YAML that the kernel's own parser reads and a spec-conforming parser rejects; their structure and
their verdicts reach the console, and the console says that their prose does not.
