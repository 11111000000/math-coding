# Theory 11 — Confidence as Information

## Formal definition

The **confidence** field in `assumptions.yaml` is a value
$c \in [0, 1]$ attached to a proposition $P$. The convention
treats it as a single bit of structured information about the
agent's belief. Information theory gives the answer to
*why this interval is $[0, 1]$ and not larger*.

### Binary encoding as information

A proposition $P$ with confidence $c$ is a **biased coin**:
probability $c$ of being true, $1 - c$ of being false. The
**Shannon information content** (self-information) of $P$
under this distribution is:

$$I(P) = -c \log_2 c - (1 - c) \log_2 (1 - c) \quad \text{bits}$$

This is the **binary entropy function** $H(c)$, the expected
information in bits needed to resolve $P$.

### Boundary cases

- $c = 0$ or $c = 1$: $I(P) = 0$ bits. The proposition is
  fully resolved; one state has probability 1, the other 0.
  No information is missing. The agent's belief is a **fact**
  (epistemology = `fact`).
- $c = 0.5$: $I(P) = 1$ bit. The proposition is maximally
  uncertain; resolving it reveals one full bit. The agent's
  belief is a **hypothesis** (epistemology = `hypothesis`).
- $c \in (0, 1)$ generally: $0 < I(P) \leq 1$ bit. The agent
  has partial information.

### Why the interval is $[0, 1]$ and not larger

Three reasons grounded in information theory:

1. **Probabilities are in $[0, 1]$.** Confidence is
   interpreted as a probability. Any number outside this
   interval is not a probability.

2. **Epistemic markers are 4-valued, not continuous.**
   The four markers `fact`, `hypothesis`, `judgment`,
   `unknown` partition the interval:
   - `fact` ↔ $\{0, 1\}$ (boundary, $I(P) = 0$)
   - `judgment` ↔ $\{0, 1\}$ (design decision, also at
     boundary)
   - `hypothesis` ↔ $(0, 1)$ (interior, $0 < I(P) \leq 1$)
   - `unknown` ↔ $\{0\}$ (no information, marker status,
     not a probability)

   The convention reserves the interior for `hypothesis`. Any
   continuous value between 0 and 1 is a `hypothesis` with
   that confidence.

3. **The belief update rule of theory-07 keeps $c \in [0, 1]$.**
   The multiplicative update
   $c' = c \cdot (1 + \alpha \cdot e)$ with $c, \alpha, e
   \in [0, 1]$ stays in $[0, 1]$ when $\alpha \cdot e \leq
   1 - c$. The convention's defaults ($\alpha = 0.2$, $e
   \in [0, 1]$) respect this for the common case.

## Connection to math-coding

The confidence field answers: **how much information is
missing** if the agent has to act on this assumption now?

| Confidence $c$ | $I(P)$ bits | Marker | Agent action |
|----------------|--------------|--------|--------------|
| $1.0$ | $0$ | `fact` | trust, verify if cheap |
| $0.95$ | $0.286$ | `fact` | trust, record source |
| $0.7$ | $0.881$ | `hypothesis` | search for evidence |
| $0.5$ | $1.000$ | `hypothesis` | search, plan for surprise |
| $0.3$ | $0.881$ | `hypothesis` | search, expect contradiction |
| $0.05$ | $0.286$ | `hypothesis` | almost certain negation |
| $0.0$ | $0$ | `fact` or `unknown` | depends on direction |

Notice the symmetry: $c$ and $1 - c$ have the same
information content. A 30%-confidence belief that "X is true"
and a 30%-confidence belief that "X is false" are equally
informative; what differs is the **direction** of the belief.
The four markers separate direction (true/false) from
resolution (resolved/unresolved).

### Why confidence is recommended but not required

Without a numeric confidence, an agent reading `hypothesis`
must decide *how much* to search for evidence. The convention
encourages confidence because:

- A `hypothesis` with `confidence: 0.5` is "I have no idea;
  please plan accordingly."
- A `hypothesis` with `confidence: 0.95` is "I am almost
  certain; one verification check should suffice."
- A `hypothesis` with `confidence: 0.05` is "I almost
  believe the negation; one more piece of evidence should
  flip me to `fact` with the opposite statement."

Without confidence, all three look identical to the action
protocol of theory-07.

## Example

A `assumptions.yaml` entry:

```yaml
- id: A7
  statement: TLC will find no counterexample to I4.
  status: agent-inferred
  epistemology: hypothesis
  confidence: 0.85
```

Information analysis:

- $I(P) = H(0.85) \approx 0.610$ bits. The agent is missing
  about 0.6 bits of information.
- A single TLC run either confirms (resolves 0.610 bits to 0)
  or finds a counterexample (also resolves to 0, but flips the
  belief).

If the agent's confidence were instead $0.5$:

- $I(P) = 1.000$ bits. The agent has **no idea**.
- A single TLC run still resolves it to 0 bits, but the agent
  cannot predict the outcome — it must run TLC with the
  expectation of surprise.

If the agent's confidence were $0.99$:

- $I(P) \approx 0.080$ bits. Almost resolved.
- The agent might skip TLC for cost reasons and rely on
  structural reasoning. This is a **judgment call** that
  the agent records in `task.md`.

## Why this matters

Confidence is not a number to be ignored. The information
content is **non-linear** in $c$:

- Going from $c = 0.5$ to $c = 0.7$ resolves 0.119 bits
  (12% of the way from "no idea" to "resolved").
- Going from $c = 0.95$ to $c = 0.99$ resolves 0.066 bits
  (over 80% of the remaining way).

Effort spent on verification should be proportional to
$I(P)$, not to $|1 - c|$. The convention's epistemic action
protocol (theory-07) recommends "search for evidence" for
all `hypothesis` markers, but a careful agent weights the
search budget by information content.

## References

- Shannon, "A Mathematical Theory of Communication" (1948)
- Cover & Thomas, "Elements of Information Theory" (2006),
  ch. 2 (Entropy)
- Jaynes, "Probability Theory: The Logic of Science" (2003)
- MacKay, "Information Theory, Inference, and Learning
  Algorithms" (2003), ch. 4 (Probability and Entropy)
- Paris, "The Uncertain Reasoner's Companion" (2006)