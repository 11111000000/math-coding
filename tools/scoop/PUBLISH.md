# tools/scoop

> How to ship a Scoop release of `mathc` once a math-coding
> GitHub release lands.

## Scope

The Scoop manifest in `tools/scoop/mathc.json` is the canonical
source. It is versioned alongside math-coding releases; the
`version` field tracks the latest tagged release.

## One-time setup

1. Fork
   [`ScoopInstaller/Scoop`](https://github.com/ScoopInstaller/Scoop)
   and the manifest bucket
   [`ScoopInstaller/Extras`](https://github.com/ScoopInstaller/Extras)
   (or [`ScoopInstaller/Main`](https://github.com/ScoopInstaller/Main)
   for `scoop install mathc`, but `Extras` has lower-vetting overhead).
2. Add remotes to a fork clone of math-coding:
   ```
   git remote add scoop-extras git@github.com:<your-name>/Extras.git
   ```
3. Install Scoop locally for smoke-testing:
   ```
   irm get.scoop.sh | iex
   ```

## Per-release steps

When a `vX.Y.Z` tag lands on `11111000000/math-coding` and the
release workflow publishes `mathc-windows-x86_64.exe` +
`SHA256SUMS`:

1. **Compute the SHA-256** of the Windows binary. Read the
   line from the release's `SHA256SUMS` whose basename
   matches `mathc-windows-x86_64.exe`.
2. **Update `tools/scoop/mathc.json`**:
   - `version`: bump to `X.Y.Z`
   - `url`: bump the URL to `releases/download/vX.Y.Z/...`
   - `hash`: bump the SHA-256 to the matched line's digest
3. **Validate** locally:
   ```
   scoop cat .\tools\scoop\mathc.json | jq .version
   ```
4. **Copy into your `Extras` fork** keeping the same path:
   ```
   git checkout -b scoop/mathc/X.Y.Z
   cp -p tools/scoop/mathc.json Extras/bucket/mathc.json
   cd Extras
   scoop cat .\bucket\mathc.json | jq empty
   git commit -am "mathc: bump to X.Y.Z"
   git push -u origin scoop/mathc/X.Y.Z
   ```
5. **Open a PR** against `ScoopInstaller/Extras:main`. The Scoop
   maintainers typically merge within hours.

## Notes

- The package is `mathc` (no `extras/` prefix needed; one
  binary, single architecture).
- Scoop's auto-update uses `mathc.json`'s `autoupdate.hash`
  to refetch the SHA-256 on each release.
- The `tools/scoop/scripts/render-scoop-manifest.py` script
  is run by a maintainer at tag time and emits the JSON
  above; the maintainer pastes it into the fork.

## File map

```
tools/scoop/
├── PUBLISH.md
└── mathc.json
```
