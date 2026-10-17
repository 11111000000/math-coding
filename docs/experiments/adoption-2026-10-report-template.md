# Per-project Adoption Report Template

> **Filled in by sub-agents and the orchestrator's control arm.**
> One section per session (T1, T2, T3, plus a control variant
> of one of these). Each section is independently replaceable.

## Project: `<project>`

| Baseline metric | Value |
|-----------------|-------|
| language | |
| loc | |
| tests | |
| governance | |
| existing adrs | |
| build system | |
| gitignore state | |

## Session: T1 — Bootstrap documentation

### Outcome

> One paragraph: what commitment was formalised. Include the
> decision YAML path.

### Quantitative metrics

| Metric | Value |
|--------|-------|
| `ttfd_minutes` | |
| `wall_clock_minutes` | |
| `mathc_invocations` | `validate=N, self-check=N, new-decision=N, attest=N, ...` |
| `schema_errors` | list of `MC-*` codes seen |
| `decisions_written` | |
| `obligations_written` | |
| `attestations_written` | manual=N, batch=N |
| `yaml_loc_per_kloc` | |
| `verdict_transitions` | ordered list of self-check outputs |

### Friction events

```yaml
- id: T1-1
  code: F-XXX   # one of F-SETUP, F-SCHEMA, F-WORKFLOW, F-TOOLING,
                # F-COGNITIVE, F-INTEGRATION, F-DOC, F-BROWNFIELD
  context: <what I was trying>
  trigger: <what happened>
  repro: <one-line: how to reproduce>
  severity: 1-5
  fix_recommendation: <one-line: what would have prevented it>
```

(Repeat for each event. Append, do not edit earlier events.)

### Qualitative

- `cognitive_load`: 1-5 with rationale
- `would_use_for_real`: yes/no/depends with rationale
- one-paragraph honest reflection

---

## Session: T2 — Small change

(same template as T1)

---

## Session: T3 — Decision update / lifecycle

(same template as T1)

---

## Control arm — T\<N\> without math-coding

> For one of T1/T2/T3, the same task done WITHOUT math-coding.
> Records wall-clock, lines changed, outcome.

| Metric | Value |
|--------|-------|
| `wall_clock_minutes` | |
| `loc_changed` | |
| `outcome` | |
| `tools_used` | |
| `subjective_compare_to_with_math_coding` | one paragraph |