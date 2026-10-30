# The math-coding console

The console is a Paseo plugin that lives in this repository, under `plugin/math-coding-console/`. It
puts the state of a math-coding corpus where the people who work on it already are, and it gives a
person an instrument for signing a review.

The kernel is the authority. The console asks `mathc` questions and shows the answers. It computes
no verdict of its own, because a second measurer is a second opinion nobody asked for and the two
would drift.

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

## What holds it

```bash
bash tests/fixtures/paseo-console-contract.sh            # what the plugin registers
bash tests/fixtures/paseo-console-kernel-authority.sh     # where its verdicts come from
bash tests/fixtures/paseo-console-negative-control.sh     # that the two above can fail
```

The negative control breaks a copy of the plugin six ways and requires the other two fixtures to
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
