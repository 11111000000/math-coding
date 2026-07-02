# Theory 11 — Confidence as Information

## Problem

The `confidence` field in `assumptions.yaml` is currently
free-floating: the convention recommends it but does not
explain why it must be in $[0, 1]$, how to interpret a value
near 0.5 versus 0.95, or how much information is missing at
each confidence level. Agents cannot calibrate effort without
this grounding.

## Desired outcome

A document that:

- Anchors `confidence` to Shannon information content
  $I(P) = -c \log_2 c - (1 - c) \log_2 (1 - c)$
- Explains why the interval is $[0, 1]$: probability
  constraints + 4-marker partitioning + belief update closure
- Provides a reference table: confidence → bits → marker →
  agent action
- Shows non-linear effort calibration: small changes near 0.5
  are cheap; small changes near 0.95 are expensive

## Constraints

- Notation is compact (LaTeX-as-ASCII)
- A concrete example ties information content to confidence
  values
- References to Shannon, Cover-Thomas, Jaynes, MacKay

# Adaptations

(none)