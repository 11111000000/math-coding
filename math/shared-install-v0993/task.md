# shared-install-v0993

## Problem

  math-coding runtime payload lives once at $XDG_DATA_HOME/math-coding/<ver>/, projects carry only a 25-line wrapper plus math/ and .mathrc.

## Desired outcome

  `git clone <project>` no longer pulls core/, extensions/, or meta/ into the user's repo.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
