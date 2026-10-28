(* lib/templates_embedded.ml — Adoption templates embedded as OCaml
 * string constants.
 *
 * 3.3 → 3.4 contract (PLAN.md §0.4): the templates under
 * `templates/` are no longer walked from the source tree at
 * install time. `mathc init` writes the embedded version
 * directly. The walk-up-from-binary search (which used to live
 * in `lib/init/init.ml::find_source_ci_workflow`) is gone —
 * a release tarball that does not bundle `templates/` now
 * behaves identically to a source build, because the templates
 * are baked into the binary.
 *
 * Source of truth: `templates/*` in the math-coding repo.
 * The content below is a verbatim copy at HEAD. *)

let ci_yml =
  {|
# math-coding blocking-CI template.
#
# Drop this file at .github/workflows/mathc.yml in a target repo
# that has run `mathc init` (or copied `decisions/decision.yaml`
# by hand). The workflow runs `mathc validate` against every
# staged decisions/*.yaml, then `mathc self-check` against the
# commit. A non-zero exit on either step blocks the merge.
#
# Pin the math-coding release tag to match the version of the
# binary the maintainer has on their machine. To find the latest
# release, see https://github.com/11111000000/math-coding/releases.

name: math-coding

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  self-check:
    name: mathc self-check
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # mathc self-check reads recent commits

      - name: Install mathc
        env:
          MATH_CODING_VERSION: edge  # pin to your install-toolkit
        run: |
          curl -fsSL \
            "https://github.com/11111000000/math-coding/releases/download/${MATH_CODING_VERSION}/install.sh" \
            | sh -s -- --version="${MATH_CODING_VERSION}"

      - name: Validate staged decisions
        run: |
          set -e
          for f in $(git diff --name-only -- 'decisions/*.yaml'); do
            mathc validate "$f"
          done

      - name: Self-check
        run: mathc self-check
|}

