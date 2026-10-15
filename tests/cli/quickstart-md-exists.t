QUICKSTART.md exists, is at most 100 lines, and is cross-linked
from README.md, USAGE.md, and adoption/SKILL.md. The new file is
the entry point for first-time adopters; the back-links from the
existing canonical narrative (USAGE.md, adoption/SKILL.md) are
the discoverability surface.

  $ cd "$DUNE_SOURCEROOT"
  $ [[ -f QUICKSTART.md ]] && echo "QUICKSTART.md: present"
  QUICKSTART.md: present

  $ lines=$(wc -l < QUICKSTART.md)
  $ if [ "$lines" -le 100 ]; then echo "QUICKSTART.md: line count ok ($lines <= 100)"; else echo "QUICKSTART.md: too long ($lines > 100)"; exit 1; fi
  QUICKSTART.md: line count ok (55 <= 100)

README.md points to QUICKSTART.md as the first read.

  $ grep -q "QUICKSTART.md" README.md && echo "README.md: forwards to QUICKSTART.md"
  README.md: forwards to QUICKSTART.md

USAGE.md (the full adoption runbook) has a forward banner to
QUICKSTART.md in its first five lines, so a new reader is sent to
the quickstart first and back here for detail.

  $ head -5 USAGE.md | grep -q "QUICKSTART.md" && echo "USAGE.md: top-of-file forward ok"
  USAGE.md: top-of-file forward ok

adoption/SKILL.md (the canonical AI-agent skill) cross-references
QUICKSTART.md so agents can find the canonical entry point
without re-reading USAGE.md.

  $ grep -q "QUICKSTART.md" adoption/SKILL.md && echo "adoption/SKILL.md: cross-references QUICKSTART.md"
  adoption/SKILL.md: cross-references QUICKSTART.md
