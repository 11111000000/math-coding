# math-coding console

A control panel for the math-coding assurance protocol, inside Paseo. It shows the state of a
math-coding corpus, names every open promise with the reason it is open, and lets a person read a
decision, judge it, and sign it without leaving the tool they work in.

The protocol is what binds each change to a written commitment, a list of obligations and bounded
evidence that they hold. The console is how you look at all three.

## What it shows

The console reads the repository through the `mathc` kernel and shows what the kernel says.

- **Verdict**: the self-check verdict, the exit code, the kernel and repository digests, and every
  subject that is not green with the kernel's own causes and remedies.
- **Promises**: the open promise worklist. Each row names the decision and the obligation, why it is
  open, and what would close it. Filter by state and by class.
- **Decisions**: the corpus catalogue, with each decision's intent, its obligations, the kernel's
  verdict on each, its scope, its declared risk, and its counterexample and antithesis. The kernel's
  own diagnostics for the file are shown beside them.
- **Review**: the promises a person is being asked to stand behind. Those are the obligations whose
  verifier names a human, and the ones the kernel reports as open.
- **Evidence**: the attestation store, by kind, by result and by producer class, with the share that
  is a human declaration rather than a machine observation.
- **Actions**: the kernel's own subcommands, from `self-check` and `rehash` to `gate`, `render` and
  `new-decision`.

## What it lets you do

Sign a review. The console shows the claim, the verifier, the kernel's current verdict and the
attestation the signature will replace, then asks for a verdict, an identity and a reason. The
signature becomes a `review` attestation written by the kernel itself, and the console reports the
verdict the kernel reached afterwards. When the review is made from an agent's session, the verdict
and the reason are sent to that session to be challenged.

Move a decision through its lifecycle, run any kernel subcommand, and read what it said.

## How it works

The console computes nothing. Every verdict, every count and every promise state is the kernel's,
read over the plugin's RPC. The console reads the corpus files for their text alone, so that a
decision can be read; a decision whose file the console cannot parse still appears with its
structure and its verdict, and says that its prose is missing.

## Setup

The plugin needs the `mathc` kernel on the daemon machine, and a repository that holds a math-coding
corpus. It finds the kernel in this order: the `MATH_CODING_BIN` environment variable, the
repository's own build under `_build/default/bin/`, then `mathc` on `PATH`.

The repository is taken from the workspace the panel is open in. A screen opened outside a workspace
takes it from Settings, under math-coding, where the same screen holds the identity reviews are
signed under and the command that produces the evidence a test attestation claims.

## Limits

The console is as good as the kernel it talks to. A kernel without the promise census reports no
promise classes, and the worklist is built from the kernel's obligation index instead. A decision
file the console cannot parse shows its structure and its verdict and not its prose. What the kernel
cannot read is outside the gate, and the console does not pretend otherwise.
