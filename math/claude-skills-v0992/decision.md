# claude-skills-v0992

## Thesis

  math-coding skill is built for Claude Code via extensions/agents/claude/. SKILL.md conforms to Anthropic Skills API: required `name` and `description` only. math-agent.md is opencode-only (Claude lacks subagent concept); install-skill.sh --agent=claude installs SKILL.md to ~/.claude/skills/math-coding/ and skips agent install.

## Antithesis

  claude Skills API is a flat namespace — no nested agent. Forcing a peer-agent concept through the skill pipeline would mislead users into thinking Claude has subagents when it doesn't.

## Surface impact

  - extensions/agents/claude/SKILL.preamble.md (new) — Claude-specific frontmatter
  - extensions/agents/claude/SKILL.md (generated) — output
  - meta/build-skill.sh — AGENTS list extended ("opencode claude")
  - core/install/install-skill.sh — agent install became per-agent (case statement on AGENT); opencode-only in v0.992

## Synthesis

  claude gets the convention via SKILL.md only; the model invokes the Skill tool when the user asks about packets. Peer-agent concept is opencode-specific; documented in KNOWN_LIMITATIONS. The build pipeline supports per-agent preambles precisely so claude can drop agent-specific frontmatter cleanly.

## Worked example

  After install:

  ```
  $ sh math-coding install-skill --agent=claude
  Installed math-coding skill to ~/.claude/skills/math-coding

  # In a Claude Code session:
  > "document this decision as a packet"
  # Claude invokes Skill(name="math-coding") → loads SKILL.md
  # Claude runs sh math-coding create <name> --from -
  # User commits; Claude runs sh math-coding apply <name>
  ```

## Proof

  - `sh math-coding probe` → 0 errors, axiom A6 PROVEN
  - `sh meta/build-skill.sh claude --check` → ok
  - `sh meta/build-skill.sh --list` → "opencode claude"
  - `sh math-coding install-skill --dry-run --agent=claude` → prints `~/.claude/skills/math-coding` as target, `SKILL.md (required)` only (no agent)
  - `head extensions/agents/claude/SKILL.md` → starts with `---\nname: math-coding\ndescription: ...` (Anthropic Skills-compatible)
