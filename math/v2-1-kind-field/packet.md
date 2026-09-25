---
schema_version: "2.1"
name: v2-1-kind-field
proposition: "Packets declare kind: axiom|policy|fix|experiment; default=policy. Used for filtering, visual differentiation, and lifecycle."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

Fix packets (one-time decisions like 'we removed the box-shadow') clutter mathc list and confuse readers about what's current policy.

## Care

Adding a new field requires migration of existing 23 packets to schema 2.1; without migration, default=policy preserves compatibility.

## Thesis

Add kind to Decision and frontmatter; default=policy for legacy packets. mathc list --category=fix filters; render fades fix cards.

## Antithesis

kind is another axis; with register, state, actor, beneficiary, schema gets crowded.

## Synthesis

kind is essential for scale; without it, fix and policy are indistinguishable in listings. The cost of one extra field is small.
