# tools/winget/PUBLISH.md

> How to ship a winget release of `mathc` once a math-coding
> GitHub release lands.

## Scope

The winget manifests in `tools/winget/manifests/m/mathcoding/mathc/`
are the canonical source. They are versioned alongside the math-coding
release; the `Versions/3.3.0.yaml` (and successor files) match the
`VERSION` file at the repo root.

## One-time setup

1. Fork [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs).
2. Add a remote `winget-pkgs` to your local clone of math-coding:
   ```
   git remote add winget-pkgs git@github.com:<your-name>/winget-pkgs.git
   ```
3. Make sure you have local Windows tooling to validate the manifest:
   - `wingetcreate` from
     [`microsoft/winget-create`](https://github.com/microsoft/winget-create),
     OR
   - `winget validate --manifest <path>` from an existing
     Windows+winget client.

## Per-release steps

When a `vX.Y.Z` tag lands on `11111000000/math-coding` and the
release workflow publishes `mathc-windows-x86_64.exe` +
`SHA256SUMS`:

1. **Compute the SHA-256** of the Windows binary. The release
   pipeline emits `SHA256SUMS` whose Windows line is:
   ```
   <hex-digest>  mathc-windows-x86_64.exe
   ```
   Extract the hex digest.

2. **Update `manifests/m/mathcoding/mathc/X.Y.Z/`**:
   - `mathcoding.mathc.installer.yaml` — bump `Version`,
     `InstallerSha256`, the `ReleaseDate` from the GitHub release,
     and the `InstallerUrl` URL.
   - `mathcoding.mathc.locale.en-US.yaml` — bump `Version` only;
     copy/sales text is stable.
   - `mathcoding.mathc.X.Y.Z.yaml` under `Versions/` — bump
     `PackageVersion` and the channel/ManifestVersion triple.

3. **Validate locally** (on Windows):
   ```
   winget validate --manifest .\manifests\m\mathcoding\mathc\X.Y.Z
   ```

4. **Copy into your `winget-pkgs` fork**, keeping the same path:
   ```
   git checkout -b winget/mathcoding/mathc/X.Y.Z
   cp -r manifests/m/mathcoding/mathc/X.Y.Z winget-pkgs/manifests/m/mathcoding/mathc/
   cd winget-pkgs
   winget validate --manifest .\manifests\m\mathcoding\mathc\X.Y.Z
   git commit -am "mathcoding.mathc: bump to X.Y.Z"
   git push -u origin winget/mathcoding/mathc/X.Y.Z
   ```

5. **Open a PR** against `microsoft/winget-pkgs:main`. Microsoft
   automation runs `winget validate` and approves within
   typically 1-3 days.

## Notes

- Package ID is `mathcoding.mathc` (Owner=mathcoding, Name=mathc).
  This is the ID the user types after `winget install`.
- The manifest is signed by Microsoft's automation; no separate
  signing key is required.
- If the package has not been merged into winget-pkgs yet, the
  `winget install mathcoding.mathc` command fails with "package
  not found"; users on Windows fall back to the
  `irm install.ps1 | iex` path documented in
  `QUICKSTART.md` and `site/install.md`.
- The manifest files are auto-generated from the live release
  by `tools/winget/scripts/render-winget-manifest.py`. The script
  is run by the release pipeline at tag time, generating a
  candidate PR text that a maintainer pastes into the fork.

## File map

```
tools/winget/
├── PUBLISH.md                                       (this file)
├── scripts/
│   └── render-winget-manifest.py                   (generator)
└── manifests/
    └── m/
        └── mathcoding/
            └── mathc/
                └── 3.3.0/                          (one folder per release)
                    ├── mathcoding.mathc.installer.yaml
                    ├── mathcoding.mathc.locale.en-US.yaml
                    ├── mathcoding.mathc.defaultLocale.yaml
                    └── Versions/
                        └── 3.3.0.yaml
```
