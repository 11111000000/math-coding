# build-skill-v0992

## Problem

  extensions/agents/opencode/SKILL.md is generated, not hand-authored. Single source for normative content.

## Desired outcome

  SKILL.md rebuilds automatically from core/spec/, core/theories/, and KNOWN_LIMITATIONS.md via meta/build-skill.sh. --check mode fails if stale.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
