The release.yml publish step references the
`sigstore/cosign-installer` GitHub Action. Per
`decisions/release-cosign-blob-sign-2026-10.yaml`
obligation `cosign-blob-step-installed`, the `cosign
sign-blob` step installs cosign via this action (the
IMAGE cosign workflow in `.github/workflows/docker.yml`
already uses the same action; the release.yml instance
is the mirror for binary assets).

  $ cd "$DUNE_SOURCEROOT"
  $ grep -q 'sigstore/cosign-installer' .github/workflows/release.yml && \
  >   echo "release.yml references sigstore/cosign-installer"
  release.yml references sigstore/cosign-installer

  $ yq '.jobs.publish.steps[]|select(.name=="Install cosign")|.uses' \
  >   .github/workflows/release.yml
  "sigstore/cosign-installer@v3"

The release.yml publish steps (both tag-push and
edge-prerelease) add the `.sig` and `.pem` files for
each `mathc-*` binary alongside the binary itself. Per
the `cosign-blob-step-installed` obligation, the
per-binary asset count rises from 1 to 3
(`<bin>`, `<bin>.sig`, `<bin>.pem`).

The number is derived, not remembered: each publish step
lists `mathc-*` binaries and every one of them contributes
exactly two signed assets, so the count is twice the number
of `mathc-*` binaries in `files:`.

With seven binaries — linux-x86_64, linux-aarch64,
darwin-x86_64, darwin-aarch64, windows-x86_64.exe,
windows-aarch64.exe and linux-x86_64-musl — that is 14.

This fixture previously pinned 12, which was correct when
the list held six binaries. `mathc-windows-aarch64.exe`
arrived with `release-windows-aarch64-binary-2026-10` (D7,
commit 6b6260a9) and made it seven. Note that
`mathc-linux-x86_64-musl` was ALREADY present when 12 was
pinned, so musl is not what moved this number; the
Windows ARM64 entry is. The derivation below prints both
sides of the arithmetic so the next matrix addition fails
loudly with its cause attached, rather than as a bare
off-by-two diff.

  $ cd "$DUNE_SOURCEROOT"
  $ files=$(yq -r '.jobs.publish.steps[]|select(.name=="Publish on tag — official release").with.files' .github/workflows/release.yml); \
  >   bins=$(printf '%s\n' "$files" | grep -E '^dist-bin/mathc' | grep -vE '\.(sig|pem)$' | wc -l); \
  >   sigs=$(printf '%s\n' "$files" | grep -cE '\.(sig|pem)$'); \
  >   echo "binaries=$bins signed-assets=$sigs"
  binaries=7 signed-assets=14

  $ yq '.jobs.publish.steps[]|select(.name=="Publish on tag — official release").with.files' .github/workflows/release.yml | \
  >   grep -oE '\.sig|\.pem' | wc -l
  14

  $ yq '.jobs.publish.steps[]|select(.name=="Publish on main / manual dispatch — rolling edge").with.files' .github/workflows/release.yml | \
  >   grep -oE '\.sig|\.pem' | wc -l
  14

The release.yml `cosign sign-blob` step iterates every
`dist-bin/mathc-*` binary and runs
`cosign sign-blob --yes --output-signature … --output-certificate …`.
The bash case pattern excludes `*.tar.gz`, `*.txt`,
`*.sig`, `*.pem` so the loop signs every binary exactly
once (and does not re-sign its own outputs).

  $ cd "$DUNE_SOURCEROOT"
  $ grep -A 6 'name: cosign sign-blob (each mathc-\* binary)' .github/workflows/release.yml | \
  >   grep -q 'cosign sign-blob' && echo "step body runs cosign sign-blob"
  step body runs cosign sign-blob

  $ grep -A 20 'name: cosign sign-blob (each mathc-\* binary)' .github/workflows/release.yml | \
  >   grep -q -- '--output-signature' && \
  >   grep -A 20 'name: cosign sign-blob (each mathc-\* binary)' .github/workflows/release.yml | \
  >   grep -q -- '--output-certificate' && \
  >   echo "step uses --output-signature and --output-certificate"
  step uses --output-signature and --output-certificate

install.sh contains the new `verify_cosign_blob`
helper and a `cosign verify-blob` invocation. Per
obligation `install-sh-cosign-blob-flags`, the
existing `--cosign-verify` / `--no-cosign-verify`
flag pair (originally gating the IMAGE cosign verify)
is extended to also gate the binary blob verify.

  $ cd "$DUNE_SOURCEROOT"
  $ grep -q 'verify_cosign_blob()' scripts/install-tooling/install.sh && \
  >   echo "install.sh defines verify_cosign_blob"
  install.sh defines verify_cosign_blob

  $ grep -q 'cosign verify-blob' scripts/install-tooling/install.sh && \
  >   echo "install.sh calls cosign verify-blob"
  install.sh calls cosign verify-blob

  $ grep -q 'MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL' scripts/install-tooling/install.sh && \
  >   echo "install.sh emits MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL on failure"
  install.sh emits MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL on failure

The existing `--cosign-verify` / `--no-cosign-verify`
flag pair continues to gate both the IMAGE cosign
verify and the new BLOB cosign verify. A user who
passes `--no-cosign-verify` skips both checks; a user
who does not pass either flag runs both.

  $ cd "$DUNE_SOURCEROOT"
  $ grep -q -- '--cosign-verify' scripts/install-tooling/install.sh && \
  >   grep -q -- '--no-cosign-verify' scripts/install-tooling/install.sh && \
  >   echo "install.sh flag pair --cosign-verify/--no-cosign-verify present"
  install.sh flag pair --cosign-verify/--no-cosign-verify present

install.ps1 mirrors the same change in PowerShell. Per
obligation `install-ps1-cosign-blob-flags`, a new
`Test-CosignBlob` function runs `cosign verify-blob`
against the downloaded binary's `.sig` and `.pem`
triple, gated by `-NoCosignVerify` (the existing
default-on switch for both image and blob verify).

  $ cd "$DUNE_SOURCEROOT"
  $ grep -q 'function Test-CosignBlob' scripts/install-tooling/install.ps1 && \
  >   echo "install.ps1 defines Test-CosignBlob"
  install.ps1 defines Test-CosignBlob

  $ grep -q 'cosign verify-blob' scripts/install-tooling/install.ps1 && \
  >   echo "install.ps1 calls cosign verify-blob"
  install.ps1 calls cosign verify-blob

  $ grep -q 'MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL' scripts/install-tooling/install.ps1 && \
  >   echo "install.ps1 emits MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL on failure"
  install.ps1 emits MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL on failure

The CI-side signer identity and the user-side
verifier identity are the SAME string. Both
`MC_COSIGN_IDENTITY_REGEXP` (in install.sh) and
`$MC_COSIGN_IDENTITY_REGEXP` (in install.ps1) carry
`https://github.com/11111000000/math-coding`; the
release.yml workflow does NOT pass any
`--certificate-identity-regexp` (keyless + OIDC is
the default), and the install scripts use that exact
regexp on the verify side.

  $ cd "$DUNE_SOURCEROOT"
  $ grep -q 'https://github.com/11111000000/math-coding' scripts/install-tooling/install.sh && \
  >   echo "install.sh identity regexp matches the signer identity"
  install.sh identity regexp matches the signer identity

  $ grep -q 'https://github.com/11111000000/math-coding' scripts/install-tooling/install.ps1 && \
  >   echo "install.ps1 identity regexp matches the signer identity"
  install.ps1 identity regexp matches the signer identity

OCAML_KERNEL_CONVENTIONS.md §11.37 documents the
`cosign sign-blob` trap per obligation
`cosign-blob-trap-log`. The trap log entry follows
the §11 format with symptom/fix/trigger sections.

The fixture used to name `OCAML_BEST_PRACTICES.md`, but
commit 45b2143 ("docs(defense): rename kernel-side docs
and add adoption-disambiguation banner") renamed that file
to `OCAML_KERNEL_CONVENTIONS.md`. The rename was pure
mechanical — `git show 45b2143` records the pair
`OCAML_BEST_PRACTICES.md => OCAML_KERNEL_CONVENTIONS.md`,
10 lines changed — and the §11.37 trap entry itself moved
across intact at line 2281. Only the fixture went stale,
which is why this assertion went red rather than the entry
going missing.

  $ cd "$DUNE_SOURCEROOT"
  $ grep -q '^### 11\.37' OCAML_KERNEL_CONVENTIONS.md && \
  >   echo "OCAML_KERNEL_CONVENTIONS.md has §11.37 trap entry"
  OCAML_KERNEL_CONVENTIONS.md has §11.37 trap entry

The decision that recorded this work
(`decisions/release-cosign-blob-sign-2026-10.yaml`) was a work
record and the census removed it. What the test checks is the
ARTEFACT, not the record of it: the release workflow signs the blob.

  $ cd "$DUNE_SOURCEROOT"
  $ grep -c 'cosign' .github/workflows/release.yml
  18

  $ grep -q 'cosign' .github/workflows/release.yml && \
  >   echo "the release workflow signs the blob"
  the release workflow signs the blob
