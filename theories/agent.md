# Agent (A6)

An AI coding agent is a function over a state space:

  S = (chat_history, files_read, files_written, mode, role)

The agent reads and writes files, proposes actions, and may
ask clarifying questions. Its actions form a trace:

  trace = [(read, file), (propose, mode), (write, file), ...]

The convention treats every agent as an interpreter over
the plain-text files in this repository. The agent's proof
term is its trace; the agent's type-checker is
`core/check/verify.sh` and (in axiom A6) `core/self/probe.sh`.

In math-coding:

  agent mode   ∈ { skip, light, standard, strict }
  agent role   ∈ { developer, designer, product-manager,
                  researcher, tech-writer }
  agent reads  AGENTS.md, docs/axioms.md, theories/*.md,
              math/<packet>/
  agent writes math/<packet>/<file>.md, optionally with
              packet.yaml:applications[] entries

axiom A6 (self-application) is the convention closing the
loop: an agent runs the convention on the convention.

See math/06-self-application/, AGENTS.md.