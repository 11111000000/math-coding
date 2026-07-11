# Theory: Confidence as Information

**Rigor:** any (relevant for hypothesis and judgment)

Each assumptions.yaml entry has confidence: c ∈ [0, 1].
The information content of an assumption is:

  I(c) = -c·log₂(c) - (1-c)·log₂(1-c)  (bits)

- c = 0.5: I = 1.0 bit (max uncertainty)
- c = 0.9: I = 0.469 bits
- c = 0.99: I = 0.080 bits
- c = 0 or 1: I = 0 bits (resolved)

**Used in:** assumptions.yaml with epistemology: hypothesis.
Total uncertainty of a packet: sum of I(c) over all hypothesis
entries. Used as readiness signal: total > 2 bits means
"this packet has too much uncertainty to be verified".

**Example:** packet with 4 hypothesis assumptions at
confidence 0.7, 0.6, 0.8, 0.5. Total I = 0.881 + 0.971 + 0.722 +
1.0 = 3.574 bits. Above 2 → packet not ready for verified status.