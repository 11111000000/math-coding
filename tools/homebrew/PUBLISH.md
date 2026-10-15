# tools/homebrew

> How to ship a Homebrew formula of `mathc` once a math-coding
> GitHub release lands.

## Scope

The formula in `tools/homebrew/Formula/mathc.rb` is the
canonical source. It is versioned alongside math-coding
releases; the `url`, `sha256`, and `version` track the latest
tagged release.

## One-time setup

1. Create the personal tap repo
   [`11111000000/homebrew-tap`](https://github.com/11111000000/homebrew-tap)
   (empty except for README.md and `Formula/` dir).
2. Add the tap as a remote to a math-coding working clone:
   ```
   git remote add tap git@github.com:11111000000/homebrew-tap.git
   ```
3. Install Homebrew locally for smoke-testing:
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

## Per-release steps

When a `vX.Y.Z` tag lands on `11111000000/math-coding` and the
release workflow publishes the macOS binaries +
`SHA256SUMS`:

1. **Compute SHA-256s** of the macOS binaries. Read the
   `SHA256SUMS` lines whose basenames match
   `mathc-darwin-x86_64` and `mathc-darwin-aarch64`.
2. **Update `tools/homebrew/Formula/mathc.rb`**:
   - `url`: switch to the matching `mathc-darwin-<arch>`
     binary. Default to `aarch64`; ship both arches via
     `livecheck` block below.
   - `sha256`: digest of the matching binary.
3. **Validate locally**:
   ```
   brew audit --strict tools/homebrew/Formula/mathc.rb
   brew style tools/homebrew/Formula/mathc.rb
   ```
4. **Copy into the tap**:
   ```
   git checkout -b mathc/X.Y.Z
   cp -p tools/homebrew/Formula/mathc.rb Formula/mathc.rb
   git commit -am "mathc X.Y.Z"
   git push -u origin mathc/X.Y.Z
   ```
5. **Open a PR** against `11111000000/homebrew-tap:main`. Homebrew
   maintainers (here: the project's own maintainer, since
   it's a personal tap) typically merge within hours.

## Notes

- Brew bottles (`bottle do ... end`) are not shipped; the
  formula is source-style and downloads the binary directly.
  Linuxbrew (the Linux Homebrew) uses the same formula and
  downloads `mathc-linux-x86_64` instead.
- The placeholder SHA-256 in the canonical file is a
  well-formed 64-hex string that fails `brew audit --strict`;
  run `tools/homebrew/scripts/render-homebrew-formula.py`
  to replace it with the actual digest at release time.

## File map

```
tools/homebrew/
├── PUBLISH.md
├── Formula/mathc.rb
└── scripts/render-homebrew-formula.py
```
