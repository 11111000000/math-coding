# witness-external-v0992

## Thesis

  Witness is an external file, not a field in packet.yaml. axiom A5 recursion breaks when refresh commit rewrites applications[].

## Antithesis

  applications[] in packet.yaml keeps everything in one file. Moving to external witness file is one more file to maintain; easy to lose during git operations (rm, mv).

## Synthesis

  External witness is append-only and never modified by packet content changes. Self-reference (packet.yaml::applications[] = packet.yaml) is the recursion source. axiom A5 needs witness to be stable across refresh commits; only an external file achieves this.
