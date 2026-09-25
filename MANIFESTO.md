# Eight principles of math-coding

> **Audience note.** If you arrived via an AI coding agent (Cursor,
> Claude Code, Copilot Workspace, or any other), read [README.md](README.md)
> first — that document is the entry pitch. This file is the formal
> exposition; start here only if you came from the kernel side.

## Introduction

math-coding is a convention for recording architectural decisions in the form of verifiable packets. The convention applies to itself: the kernel $S$ that implements the eight principles is itself described through those same principles. This forms a fixed point $Y$ in the programmer's sense: a fixed point of the function that maps an arbitrary decision-recording convention to a convention capable of describing itself.

The convention's motto is "The practice of recording decisions before code." The eight principles below formalise what that practice means. Each principle is a minimal statement, without which the convention either loses verifiability or reduces to ceremony. The principles are stated as theorems and packets; one static OCaml kernel verifies them.

The convention stores only text and git history. No servers, databases, or frameworks are used. Each decision exists as a directory `math/<name>/packet.md` with a proposition, a witness (a commit SHA), and nine frontmatter fields. Five foundations and three extensions make up the eight packets verified by the same kernel; there is no special path for the foundations themselves.

## 1. A decision is a triple

**Thesis.** A decision in math-coding is structurally isomorphic to the triple (proposition, code, witness), and the kernel $S$ verifies the correspondence between its elements.

**Justification.** The Curry-Howard isomorphism states that a proposition is a type, a code is a term, and inhabitation is a proof. In software engineering, the proposition becomes a statement about a decision, the code its realisation, and the witness the binding of the proposition to a commit, making inhabitation verifiable. Without the triple structure, a proposition remains documentation without consequences: its change is impossible to track. With the triple, proposition and code become a verifiable pair, and any change to the code requires either updating the proposition or explicit supersession.

**Formal statement.**

$$\mathrm{Decision} = \langle \mathrm{name},\ \mathrm{proposition},\ \mathrm{code},\ \mathrm{witness},\ \mathrm{register},\ \mathrm{state},\ \mathrm{actor},\ \mathrm{confidence},\ \mathrm{superseded\_by} \rangle$$

```ocaml
type decision = {
  name          : string;
  proposition   : string;             (* non-empty *)
  code          : string option;      (* optional *)
  witness       : Sha.t option;       (* optional *)
  register      : register;           (* fact | hypothesis | judgment | unknown *)
  state         : fsm_state;          (* draft | applied | reviewed | retired | abandoned *)
  actor         : actor;              (* human | agent | system *)
  confidence    : float;              (* [0, 1] *)
  superseded_by : string option;
  beneficiary   : beneficiary;
}
```

The kernel $S$ rejects a packet with an empty `proposition`, requires `witness` for transition to `applied` or `reviewed`, and signals drift when the proposition is changed after witnessing.

**Cross-reference.** The principle `curry-howard.triple` is recorded in `math/foundations/curry-howard/`. All other foundations and extensions inherit the triple structure: `temporal.lifecycle` computes state from the witness and git history; `constructive.proof` concretises the witness as a reproducible command; `categorical.supersession-spo` defines the rules of triple evolution through supersession.

**Worked example.** A decision about the TTL policy for a cache is adopted: the proposition is "TTL = 60 seconds with manual invalidation through `/admin/manual-invalidate`." The directory `math/ttl-policy/packet.md` is created with this proposition before the cache code is written. After implementation, the command `mathc amend ttl-policy` fixes the witness to the current commit. The command `mathc check` reports `applied ✓`. Any subsequent change to the cache code without `mathc supersede` produces drift, detected by the kernel.

## 2. The lifecycle is computed

**Thesis.** The lifecycle $L$ of a decision is a function of the decision and git history; $L$ is computed, not stored.

**Justification.** Decisions evolve. A proposition that is true at commit $A$ may turn out to be false at commit $B$. Storing state as an enumeration allows drift between the declared state and the actual one: a developer changes the code but forgets to update the `status` field. Computing state from git history makes drift detection automatic and falsifiable — the attempt to lie about state becomes impossible, because state is a consequence of history, not an editable field of it.

**Formal statement.**

$$L : \mathrm{Decision} \times \mathrm{Repo} \to \{\mathrm{Draft},\ \mathrm{Applied},\ \mathrm{Drift},\ \mathrm{Stale}\}$$

```ocaml
let lifecycle d repo =
  match d.witness with
  | None -> Draft
  | Some sha ->
    let prop_now = proposition_at d.name repo in
    if prop_now <> d.proposition then Drift
    else Applied
```

Only the terminal states (`reviewed`, `retired`, `abandoned`) require an explicit CLI action, since they encode human judgment rather than a mechanical fact.

**Cross-reference.** The principle `temporal.lifecycle` is recorded in `math/foundations/temporal/`. It combines with `curry-howard.triple`: the witness from the triple becomes the argument of $L$. The link to `process-fsm.fsm` (principle 6) is that transitions between FSM states are determined by history, not by a field in a file.

**Worked example.** A developer changes the file `lib/cache.ex` after the `ttl-policy` decision has been witnessed. The command `mathc check` reports `ttl-policy: drift ?`, since the proposition and the realisation have diverged. The developer either reverts the code (`git revert` and `mathc amend`) or fixes the new proposition through `mathc supersede ttl-policy ttl-policy-v2 "TTL = 30 seconds with event-based invalidation"`. In both cases the history is consistent.

## 3. Proof is reproducible

**Thesis.** The state `proven` requires reproducible evidence: re-running the command must yield the recorded exit code.

**Justification.** Classical logic permits "proven" without a construction. Constructive logic requires a term — a program that normalises to the desired value. In software engineering, the term is a re-runnable command: a test, a benchmark, a type check. If the result is not reproducible, the statement is not proven — it remains a hypothesis. This is the only epistemic register that triggers real kernel action; the others (`fact`, `hypothesis`, `judgment`, `unknown`) are declarations of stance and do not influence the verdicts.

**Formal statement.**

$$\mathrm{Reproducible} \triangleq \mathrm{Re\!-\!run}(\mathrm{command}) = \mathrm{recorded\_exit}$$

```ocaml
type evidence = {
  command       : string;
  recorded_exit : int;
  when_         : Sha.t;
}

let verify_evidence ev =
  if run_command ev.command = ev.recorded_exit
  then Pass
  else Fail
```

A packet with `substrate: shell` or `substrate: pbt` has evidence — a path to a command and an expected exit code. On every `mathc check`, the kernel re-runs the command and compares the result. On mismatch, the kernel signals drift.

**Cross-reference.** The principle `constructive.proof` is recorded in `math/foundations/constructive/`. The link to `curry-howard.triple` is that re-running the command is normalisation in the Curry-Howard sense: the program `command` reduces to a value (the exit code). The link to `temporal.lifecycle` is that the `evidence.when_` field is a git SHA, synchronising the statement with history.

**Worked example.** The decision `build-reproducibility` asserts that `cargo build --release` is reproducible in an identical environment. The proposition fixes the recorded exit code `0`. Half a year later the compiler version changes, and `cargo build --release` returns `1`. The command `mathc check` reports `build-reproducibility: drift ?` — re-running no longer yields the recorded code. The developer either updates the proposition through supersession, or restores the identical environment.

## 4. Supersession is a strict partial order

**Thesis.** The "supersedes" relation on decisions is a strict partial order: irreflexive, asymmetric, and transitive.

**Justification.** Decisions evolve. When the proposition changes, the previous decision is not edited — it is superseded by a new one. The supersession relation must be a strict partial order for the meaning to be preserved. Irreflexivity forbids trivial self-supersession. Asymmetry excludes cycles. Transitivity allows composing chains into lineages. Without these properties, the history of decisions becomes inconsistent: a reviewer cannot determine which decision is current.

**Formal statement.** Let $\preceq$ denote "$a$ supersedes $b$". Then:

$$\forall a.\ \neg(a \preceq a) \quad\text{(irreflexivity)}$$

$$\forall a, b.\ (a \preceq b) \Rightarrow \neg(b \preceq a) \quad\text{(asymmetry)}$$

$$\forall a, b, c.\ (a \preceq b) \wedge (b \preceq c) \Rightarrow (a \preceq c) \quad\text{(transitivity)}$$

```ocaml
let check_spo decisions =
  List.for_all decisions ~f:(fun d ->
    not (supersedes d d) &&
    List.for_all (supersedees d) ~f:(fun other ->
      not (supersedes other d)) &&
    transitive_holds d)
```

**Cross-reference.** The principle `categorical.supersession-spo` is recorded in `math/foundations/categorical/`. It connects with `temporal.lifecycle`: the lifecycle is computed for each decision, while supersession links decisions into a history of what replaced what. It connects with `curry-howard.triple` through the `superseded_by` field of the `decision` type.

**Worked example.** The decision `error-handling` (Result + context, September 2025) is superseded by `error-handling-v2` (Result + tracing, March 2026). Then `error-handling-v2` is superseded by `error-handling-v3`. The chain `error-handling` → `error-handling-v2` → `error-handling-v3` is transitive: the third decision supersedes the first by definition of the SPO. The kernel rejects the attempt to create a cycle or self-supersession.

## 5. Register and justification

**Thesis.** Each packet declares an epistemic register (`fact`/`hypothesis`/`judgment`/`unknown`) and a numerical confidence; a convention without justification is ceremony.

**Justification.** Decisions are made with varying degrees of certainty. A fact requires reproduction; a hypothesis requires a formulation open to refutation; a judgment requires an explicit indication of possible harm (reversibility, mitigation); an unknown requires an honest acknowledgement of the boundary. Without an explicit register, epistemic honesty turns into self-deception: a developer fills in `fact` without evidence, an agent fills in `fact` without verification. Without justification, the proposition becomes a slogan beyond criticism.

**Formal statement.**

$$\mathrm{register} \in \{\mathrm{fact},\ \mathrm{hypothesis},\ \mathrm{judgment},\ \mathrm{unknown}\}$$

$$\mathrm{confidence} : \mathrm{Decision} \to [0, 1]$$

The relation between register and confidence:

$$\mathrm{fact} \Rightarrow \mathrm{confidence} \in [0.95, 1]$$
$$\mathrm{hypothesis} \Rightarrow \mathrm{confidence} \in (0.5, 0.95)$$
$$\mathrm{judgment} \Rightarrow \mathrm{confidence} \in \{0, 1\} \text{ (categorical)}$$
$$\mathrm{unknown} \Rightarrow \mathrm{confidence} = 0$$

```ocaml
type register = Fact | Hypothesis | Judgment | Unknown

let validate_register r c =
  match r with
  | Fact       -> c >= 0.95
  | Hypothesis -> c > 0.5 && c < 0.95
  | Judgment   -> c = 0.0 || c = 1.0
  | Unknown    -> c = 0.0
```

The `judgment` register obligates the substantive `motivation` field (in the `## Why` section): an indication of possible harm (reversibility, mitigation, responsibility). An empty `## Why` for `judgment` is rejected by the kernel with a `Warn` flag.

**Cross-reference.** The principle `motivation.register-and-why` belongs to the extensions and is recorded in `math/extensions/motivation/`. It connects with `curry-howard.triple` through the `register` field of the `decision` type, and with `dialectic-tas.required-sections` (principle 7) — for the `judgment` register, the thesis/antithesis/synthesis structure is required as a concretisation of motivation.

**Worked example.** An agent adopts the decision "disable package signature verification on CI to speed up the build." The register is `judgment`, since this is a decision about trust. The confidence is 0 (categorical: we either disable it or we don't). The motivation contains an indication of reversibility (a CI flag), the possible harm (package forgery), and the mitigation (limiting it to the `feature/*` branch). The proposition is not accepted without a filled motivation; the kernel returns a warning pointing to the empty field.

## 6. A state machine with one prohibition

**Thesis.** Decisions exist in five states — `draft`, `applied`, `reviewed`, `retired`, `abandoned`; the only forbidden transition is `draft` → `reviewed` without `witness`.

**Justification.** Without an explicit state machine, the packet remains "applied" by default, and review loses its meaning. With a five-state machine, each decision follows an explicit path: from proposition (draft) to inhabitation (applied) to human verification (reviewed), with the possibility of exit through `retired` or `abandoned`. The prohibition on `draft` → `reviewed` without `witness` closes the trivial bypass: one cannot declare a decision reviewed without passing through inhabitation via git fixation. This is the minimal and sufficient restriction: one rule closes all bypasses.

**Formal statement.** States and permitted transitions:

| from | to | condition |
|---|---|---|
| `draft` | `applied` | requires `mathc amend` (setting `witness`) |
| `applied` | `reviewed` | requires a reviewer's signature (`mathc review`) |
| `applied` | `draft` | requires `mathc supersede` or explicit rollback |
| `applied` | `retired` | CLI: `mathc retire <name>` |
| `applied` | `abandoned` | CLI: `mathc abandon <name>` |
| **`draft`** | **`reviewed`** | **forbidden** — impossible without `witness` |

```ocaml
let transition d target =
  match d.state, target with
  | Draft, Reviewed ->
    Error "draft→reviewed without witness is forbidden"
  | Draft, Applied when d.witness = None ->
    Error "applied requires witness"
  | _, _ -> Ok target
```

**Cross-reference.** The principle `process-fsm.fsm` belongs to the extensions and is recorded in `math/extensions/process-fsm/`. It connects with `curry-howard.triple` (without a witness a packet does not inhabit), with `temporal.lifecycle` (the FSM state is a subset of the lifecycle), and with `actor-discipline.signed-commits` (the transition to `reviewed` requires a signature in `Strict` and `Lenient` modes).

**Worked example.** The decision `auth-skip-csrf` (disable CSRF verification for API endpoints) is created in the `draft` state. The developer tries to call `mathc review auth-skip-csrf` immediately without `amend`. The kernel rejects: the transition `draft → reviewed` is forbidden. The developer is forced first to fix the witness through `mathc amend`, and only after that, with a reviewer's signature, to move to `reviewed`.

## 7. Thesis, antithesis, synthesis are mandatory

**Thesis.** Packets with the `judgment` epistemic register require `## Thesis`, `## Antithesis`, `## Synthesis` sections; the structural form of dialectic is mandatory for human judgments.

**Justification.** Human judgment without explicit consideration of counterarguments is prone to self-deception. The dialectic tradition shows that synthesis is reachable only through passing through thesis and antithesis; truncating this structure turns judgment into declaration. In software engineering, a judgment about trust, security, or reversibility must contain an explicit antithesis — the strongest counterargument against the adopted decision. Without it, the proposition becomes a slogan, and a reviewer cannot distinguish a considered decision from an impulsive one.

**Formal statement.** A packet with `register = judgment` (or `actor = human`) must contain the sections:

```markdown
## Thesis
<statement of the claim with justification>

## Antithesis
<the strongest counterargument and its analysis>

## Synthesis
<the final decision, with an indication of reversibility and mitigation>
```

```ocaml
let validate_dialectic d =
  if d.register = Judgment || d.actor = Human then
    let body = read_packet_body d in
    if has_section "Thesis" body
       && has_section "Antithesis" body
       && has_section "Synthesis" body
    then Pass
    else Warn "Judgment requires Thesis/Antithesis/Synthesis sections"
  else Pass
```

The absence of any of the three sections yields `Warn` (not `Fail`); however, the convention strongly recommends filling in all three.

**Cross-reference.** The principle `dialectic-tas.required-sections` belongs to the extensions and is recorded in `math/extensions/dialectic-tas/`. It connects with `motivation.register-and-why` (principle 5) — motivation for `Judgment` is concretised through the TAS structure, and with `curry-howard.triple` — the thesis is the proposition, the antithesis is counter-evidence, and the synthesis is inhabitation that takes the counterargument into account.

**Worked example.** The decision `vendor-lock-in` (use of a proprietary SaaS for logging) is adopted at three in the morning as an emergency fix. The register is `Judgment`. The developer writes `## Thesis` (SaaS is faster to deploy), `## Antithesis` (vendor lock-in makes migration expensive; if the vendor goes down, the logs are lost), `## Synthesis` (we adopt SaaS, but with interface abstraction and quarterly review of the dependency). Without the `Antithesis` section the kernel issues a warning — this forces the developer to consider the counterargument even under time pressure.

## 8. Signatures fix the author

**Thesis.** A decision fixes the author through commit signatures; the signing mode (`strict`/`lenient`/`off`) is determined by the project and verified by the kernel.

**Justification.** A decision without an author has no accountability. In distributed development (human, agent, agent-based system), a commit signature is the only cryptographically verifiable way to tie a proposition to a subject. Without an explicit signing mode, a project ends up in one of two failure modes: "everyone is signed, but nobody checks," or "nobody is signed, and authorship is untraceable." The three modes — `strict`, `lenient`, `off` — cover three classes of projects: critical infrastructure, ordinary development, prototyping.

**Formal statement.**

$$\mathrm{SigningMode} = \{\mathrm{Strict},\ \mathrm{Lenient},\ \mathrm{Off}\}$$

| mode | requirement | consequence |
|---|---|---|
| `Strict` | every packet commit has a valid GPG/SSH signature | the kernel rejects a packet without a signature (`Fail`) |
| `Lenient` | the `amend` commit has a signature; the others — no | the kernel rejects a packet whose `amend` commit has no signature (`Warn`) |
| `Off` | signatures are not required | the kernel does not verify signatures |

```ocaml
type signing_mode = Strict | Lenient | Off

let verify_signing d mode =
  match mode with
  | Strict -> all_commits_signed d
  | Lenient -> List.for_all (amend_commits d) ~f:signed_p
  | Off -> Ok
```

The `signed_by` field in the `decision` type records the fingerprint of the author of the `amend` commit. The field is present in the packet starting from the `applied` state.

**Cross-reference.** The principle `actor-discipline.signed-commits` belongs to the extensions and is recorded in `math/extensions/actor-discipline/`. It connects with `curry-howard.triple` through the `signed_by` field, with `process-fsm.fsm` (principle 6) — the transition to `reviewed` requires a signature in `Strict` and `Lenient` modes — and with `temporal.lifecycle` (principle 2) — authorship is recovered from the witness commit.

**Worked example.** The project `core-infrastructure` sets the mode to `Strict`. The decision `crypto-policy` is created by a human, but the `amend` commit is created by an agent without a configured GPG key. The kernel `mathc check` reports `crypto-policy: ✗ no signature`. The agent configures the key, and the developer recreates the commit. In the prototype `personal-scratchpad` the mode is `Off` — the kernel does not verify signatures, and the same scenario passes without resistance.

## The convention applies to itself (kernel-uniformity)

math-coding has the property of kernel-uniformity: the kernel $S$ that verifies packets is itself described through the same eight principles. This is the fixed point $Y$ in the programmer's sense:

$$Y(\mathrm{math\text{-}coding}) = \mathrm{math\text{-}coding}$$

$Y$ is the function that turns an arbitrary decision-recording convention into a convention capable of describing itself. math-coding is the fixed point of this function.

The five foundations (`curry-howard`, `temporal`, `constructive`, `categorical`, `motivation`) and the three extensions (`process-fsm`, `dialectic-tas`, `actor-discipline`) are ordinary packets in the `math/foundations/` and `math/extensions/` directories. They do not form a "metalevel." Their structure is the same: proposition in frontmatter, witness in git history, state computed by the kernel. When the kernel checks the packet `curry-howard`, it runs the same code as for a user packet. There is no special path; this is the formal expression of the $Y$-property.

Each foundation and extension refers to others through theorems: `curry-howard.triple` provides the basic triple; `temporal.lifecycle` builds on top of it; `constructive.proof` concretises the witness as a reproducible command; `categorical.supersession-spo` defines evolution; `motivation.register-and-why` adds epistemic honesty; `process-fsm.fsm` concretises the lifecycle; `dialectic-tas.required-sections` concretises motivation; `actor-discipline.signed-commits` fixes authorship. All eight are mutually loaded.

If any statement in the foundation packets turns out to be false, the kernel will detect the drift the same way as for a user packet: through `Drift` or through a structural error. This means math-coding is capable of self-repair: an error in the description of a principle is detected and resolved through `supersede`. The convention has no unverifiable exceptions.

## Conclusion

math-coding exists because a proposition is not code, and code does not explain itself. Without an explicit proposition the code becomes unchangeable — every change risks destroying an intent that no one recorded. With a proposition, intent becomes verifiable: proposition and code become a pair whose drift is detected automatically.

The eight principles are minimal and mutually loaded. Each one bears a load: removing `curry-howard.triple` strips the proposition of code; removing `temporal.lifecycle` makes drift undetectable; removing `constructive.proof` turns proof into declaration; removing `categorical.supersession-spo` allows cycles in decision history; removing `motivation.register-and-why` strips epistemic honesty; removing `process-fsm.fsm` eliminates review; removing `dialectic-tas.required-sections` eliminates the obligation to consider counterarguments; removing `actor-discipline.signed-commits` eliminates authorship. None of the eight can be removed without losing the meaning of the convention.

The convention is runnable: one static OCaml binary verifies structure, lifecycle, evidence, and supersession. The convention is textual: only plain text and git. The convention is minimal: ~700 lines of OCaml, one binary, eight packets. The convention applies to itself: $Y(\mathrm{math\text{-}coding}) = \mathrm{math\text{-}coding}$.
