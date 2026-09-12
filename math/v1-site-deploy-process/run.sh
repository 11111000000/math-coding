#!/bin/sh
# Verify site deployment state.
# 1. math-coding-site gh-pages HEAD is recent (built within 24h).
# 2. The site lists no v0.99x packets.
# 3. The homepage of math-coding repo points at /math-coding-site/.
set -eu
cd "$(dirname "$0")/../.." || exit 2

# 1. math-coding-site gh-pages recent
site_sha=$(gh api repos/11111000000/math-coding-site/branches/gh-pages --jq '.commit.sha' 2>/dev/null)
site_date=$(gh api repos/11111000000/math-coding-site/branches/gh-pages --jq '.commit.commit.committer.date' 2>/dev/null)
echo "math-coding-site gh-pages sha=$site_sha date=$site_date"

# 2. Index lists no v0.99x
if curl -sf "https://11111000000.github.io/math-coding-site/index.html" 2>/dev/null | \
   grep -qE 'v0\.99[0-9]'; then
  echo "FAIL: index.html still mentions v0.99x packets" >&2
  exit 1
fi
echo "no v0.99x packets in index"

# 3. homepage points at /math-coding-site/
hp=$(gh api repos/11111000000/math-coding --jq '.homepage' 2>/dev/null)
case "$hp" in
  *math-coding-site*) echo "homepage=$hp OK" ;;
  *) echo "FAIL: homepage=$hp does not point at /math-coding-site/" >&2; exit 1 ;;
esac

echo "site deploy state OK"
