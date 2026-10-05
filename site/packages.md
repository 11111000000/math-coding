# Packages

> The package surface of math-coding 3.0.0.20. Every row below
> is a decision-obligation pair the kernel knows about; every
> verdict is the kernel's current assessment.

The package grid below is the live output of:

```bash
mathc packages --format=html
```

The kernel emits the same data as JSON (`--format=json`) and as
a fixed-width table (`--format=text`). The HTML form carries a
`data-mathc-package-count` attribute that lets site-level tooling
verify the kernel's count without re-walking the decisions.

## Why a packages surface

A project's assurance posture is a graph of decision-obligation
pairs. Walking that graph is the kernel's job; **publishing** it
is the packages surface's job. Without it, every consumer (the
site, an LLM agent, a downstream CI) has to re-walk
`decisions/*.yaml` and reproduce the same parse. With the
surface, every consumer reads the same kernel output.

## How to consume

```bash
mathc packages --format=json | jq '.counts'
```

gives the live aggregate:

```text
{
  "fail": 0,
  "missing": 0,
  "no_store": 0,
  "pass": 23,
  "stale": 0,
  "total": 23,
  "unknown": 0,
  "waived": 0
}
```

The grid below the prose is the HTML form, embedded by
`lib/render.ml`. The kernel writes both.