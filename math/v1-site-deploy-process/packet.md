---
proposition: "Site deployment uses the math-coding-site gh-pages branch as the canonical Pages host; updates go through the deploy-site.yml workflow or a manual clone+push cycle."
antithesis: "Building the site in a worktree and copying dist/ to a different clone is manual and error-prone. CI workflow on math-coding couldn't cross-push to math-coding-site due to GITHUB_TOKEN scope."
synthesis: "Two deployment paths: (1) trigger ./math-coding site workflow_dispatch in math-coding repo, which builds OCaml + dist + push via peaceiris/actions-gh-pages to its own gh-pages branch (works for any project that hasn't split pages). (2) When the project's main gh-pages branch is the wrong source, manually clone math-coding-site --branch gh-pages, overwrite with dist/, commit, push, and POST to /pages/builds to trigger a Pages rebuild."
substrate: shell
status: applied
files: [.github/workflows/deploy-site.yml]
---

## Intent

Document the actual deployment procedure after the math-coding
v0.618 → v1.0 split. The math-coding-site repo exists solely to
host the rendered site; its gh-pages branch is built by Pages,
not by the math-coding CI workflow.

## What this is NOT

- Not a one-click solution. Two paths, each with a manual step.
- Not a long-term arrangement. If math-coding-site ever becomes
  unnecessary, fold the site back into the math-coding repo by
  using /docs as the Pages source path.

## Run

### Path A: ./math-coding site workflow (preferred)

```sh
gh workflow run deploy-site.yml --repo 11111000000/math-coding
```

This:
  1. Builds the OCaml runtime via nix develop
  2. Runs sh scripts/install.sh for the shared binary
  3. Runs ./math-coding site to populate dist/
  4. Pushes dist/ to the math-coding repo's gh-pages branch
  5. Triggers Pages build

Pages URL: https://11111000000.github.io/math-coding-site/

### Path B: Manual (when Path A points to wrong URL)

```sh
# Clone the pages host repo
git clone --depth 1 --branch gh-pages \
  https://github.com/11111000000/math-coding-site.git /tmp/mcs

cd /tmp/mcs
git config user.email "math-coding-bot@users.noreply.github.com"
git config user.name "math-coding-bot"

# Wipe tracked files and re-add dist
git ls-files | xargs -r rm -f
cp -r /home/az/Projects/math-coding/dist/. .
touch .nojekyll
git add -A
git commit -m "v1.0 site: $(git -C math-coding rev-parse --short HEAD)"
git push origin gh-pages --force

# Trigger Pages rebuild
gh api repos/11111000000/math-coding-site/pages/builds -X POST
```

## Notes

The math-coding-site repo exists for historical reasons (it had
a mdBook-based site before v1.0). Its gh-pages branch is the
canonical Pages host. math-coding's own gh-pages branch has
only a redirect (not maintained here).
