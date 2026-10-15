# scripts/install-tooling/install.ps1
#
# math-coding installer for Windows PowerShell. Mirrors the
# POSIX-sh `install.sh` semantics:
#   - default = install latest stable binary
#   - downloads SHA256SUMS, verifies the binary's digest,
#     installs to %LOCALAPPDATA%\Programs\mathc\mathc.exe
#   - idempotently adds the install dir to user PATH
#   - on failure, prints a structured `diagnostic: MC-...`
#     line so install.t cram tests can match by token
#
# Invocation (one-liner):
#   irm https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 | iex
#
# Or explicit:
#   iwr https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 -useb | iex
#
# Exit codes (exit value matches the integer exit):
#   0   install succeeded
#   1   SHA-256 mismatch (partial binary removed)
#   2   input error (unsupported flag, missing argument)
#   3   network / TLS / curl error (NOT_FOUND, unreachable, etc.)
#
# Flags (all are case-insensitive, prefix-supported):
#   -Version <X>            override default version
#                            (default = "latest"; "edge" honoured)
#   -UserSkill              also install the per-user opencode skill
#   -Upgrade                with -UserSkill: overwrite even when
#                           version pin matches
#   -CosignVerify           (default on) verify the ghcr.io image
#   -NoCosignVerify         skip cosign verify (skip when cosign absent
#                           unless this switch is set: warning only)
#   -NoPathUpdate           skip user-PATH update
#   -Check                  exit 0 if installed binary already matches
#                           the requested version
#   -WhatIf                 print the action plan without I/O
#   -Help                   this help
#
# Env overrides:
#   MATH_CODING_INSTALL_DIR  override the install dir (default
#                            %LOCALAPPDATA%\Programs\mathc)
#   HTTPS_NO_PROXY           standard .NET behaviour applies

[CmdletBinding()]
param(
  [string]$Version = 'latest',
  [switch]$UserSkill,
  [switch]$Upgrade,
  [switch]$CosignVerify = $true,   # default-on
  [switch]$NoCosignVerify,
  [switch]$NoPathUpdate,
  [switch]$Check,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- Constants ---------------------------------------------------------------
$MC_REPO = '11111000000/math-coding'
$MC_RELEASE_BASE = "https://github.com/$MC_REPO/releases/download"
$MC_BINARY_BASENAME = 'mathc'
$MC_TARBALL_NAME = 'dist-adoption.tar.gz'

$MC_COSIGN_IMAGE_PREFIX = 'ghcr.io/11111000000/mathc'
$MC_COSIGN_IDENTITY_REGEXP = 'https://github.com/11111000000/math-coding'
$MC_COSIGN_OIDC_ISSUER = 'https://token.actions.githubusercontent.com'

# --- Helpers ----------------------------------------------------------------
function Write-Usage {
  @'
Usage: install.ps1 [-Version <X>] [-UserSkill] [-Upgrade] [-CosignVerify|-NoCosignVerify] [-NoPathUpdate] [-Check] [-Help] [-WhatIf]

Examples:
  irm https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 | iex
  iwr https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 -useb | iex -UserSkill
  iex ((iwr https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 -useb).Content) -Version 3.3.0

Exit codes: 0=ok, 1=SHA-mismatch, 2=input-error, 3=network-error.
'@
}

function Pick-InstallDir {
  if ($env:MATH_CODING_INSTALL_DIR) {
    return $env:MATH_CODING_INSTALL_DIR
  }
  if ($env:LOCALAPPDATA) {
    return (Join-Path $env:LOCALAPPDATA 'Programs\mathc')
  }
  return (Join-Path $HOME '.local\bin')
}

function Get-Arch {
  # x64 = x86_64; ARM64 = aarch64. .NET 6+ runs on Linux/macOS/Windows.
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
  switch ($arch.ToString()) {
    'X64' { return 'x86_64' }
    'Arm64' { return 'aarch64' }
    default { return '' }
  }
}

function Resolve-AssetName {
  param([string]$Version, [string]$Arch)
  if (-not $Arch) { return $null }
  return "mathc-windows-$Arch.exe"
}

function Resolve-SumsUrl {
  param([string]$Version)
  switch -Regex ($Version) {
    '^(edge|latest)$' { return "$MC_RELEASE_BASE/$Version/SHA256SUMS" }
    '^v\d'            { return "$MC_RELEASE_BASE/$Version/SHA256SUMS" }
    default           { return "$MC_RELEASE_BASE/v$Version/SHA256SUMS" }
  }
}

function Resolve-AssetUrl {
  param([string]$Version, [string]$AssetName)
  switch -Regex ($Version) {
    '^(edge|latest)$' { return "$MC_RELEASE_BASE/$Version/$AssetName" }
    '^v\d'            { return "$MC_RELEASE_BASE/$Version/$AssetName" }
    default           { return "$MC_RELEASE_BASE/v$Version/$AssetName" }
  }
}

function Resolve-TarballUrl {
  param([string]$Version)
  switch -Regex ($Version) {
    '^(edge|latest)$' { return "$MC_RELEASE_BASE/$Version/$MC_TARBALL_NAME" }
    '^v\d'            { return "$MC_RELEASE_BASE/$Version/$MC_TARBALL_NAME" }
    default           { return "$MC_RELEASE_BASE/v$Version/$MC_TARBALL_NAME" }
  }
}

function Download-File {
  param(
    [string]$Url,
    [string]$Out
  )
  try {
    Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing -ErrorAction Stop
    return 0
  } catch {
    Write-Error "install.ps1: download failed: $Url"
    Write-Error "diagnostic: MC-INSTALL-NETWORK"
    return 3
  }
}

function Test-Sha256 {
  param(
    [string]$Sums,
    [string]$Binary,
    [string]$Base
  )
  if (-not (Test-Path $Sums)) { return 2 }
  $expected = $null
  Get-Content $Sums | ForEach-Object {
    $parts = $_ -split '\s+', 2
    if ($parts.Length -ge 2) {
      $p = $parts[1]
      $bn = Split-Path -Leaf $p
      if ($bn -eq $Base) {
        $script:expected = $parts[0]
      }
    }
  }
  if (-not $expected) {
    Write-Error "install.ps1: SHA256SUMS does not list $Base"
    Write-Error "diagnostic: MC-INSTALL-SHA-LISTING-MISSING"
    return 2
  }
  $actual = (Get-FileHash -Path $Binary -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $expected) {
    Write-Error "install.ps1: SHA-256 mismatch for $Base"
    Write-Error "  expected: $expected"
    Write-Error "  actual:   $actual"
    Write-Error "diagnostic: MC-INSTALL-CHECKSUM-MISMATCH"
    return 1
  }
  return 0
}

function Test-CosignImage {
  param([string]$Version)
  if ($NoCosignVerify) { return 0 }
  $cosign = (Get-Command cosign -ErrorAction SilentlyContinue)
  if (-not $cosign) {
    Write-Warning "install.ps1: cosign not installed; skipping image signature verification (use -NoCosignVerify to suppress this warning)"
    return 0
  }
  $image = "$MC_COSIGN_IMAGE_PREFIX`:$Version"
  try {
    cosign verify `
      --certificate-identity-regexp $MC_COSIGN_IDENTITY_REGEXP `
      --certificate-oidc-issuer $MC_COSIGN_OIDC_ISSUER `
      $image | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Warning "install.ps1: cosign verify: ok: $image"
      return 0
    }
  } catch {}
  Write-Error "install.ps1: cosign verify: FAIL: $image"
  Write-Error "  retry with -NoCosignVerify only if you explicitly trust the registry for this version."
  Write-Error "diagnostic: MC-INSTALL-COSIGN-VERIFY-FAIL"
  return 1
}

# Test-CosignBlob — verify the downloaded binary's keyless cosign
# signature against its matching .sig / .pem pair. Per
# `decisions/release-cosign-blob-sign-2026-10.yaml` outcome
# `install-ps1-verifies-cosign-blob`. The pair is published as
# release assets by `.github/workflows/release.yml`'s `cosign
# sign-blob` step.
#
# Behavior (mirrors Test-CosignImage):
#   - $NoCosignVerify set: no-op, exit 0.
#   - cosign not on PATH: warning to stderr, exit 0.
#   - $Sig or $Cert path absent (e.g. a pre-D6 release):
#     warning to stderr, exit 0 (no signature to verify).
#   - cosign verify-blob exits 0: confirmation to stderr, exit 0.
#   - cosign verify-blob exits non-zero: error to stderr,
#     emit `diagnostic: MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL`,
#     exit 1.
#
# Args: $Binary (full path to the downloaded mathc-*.exe),
#       $Sig (full path to the matching .sig, or ""),
#       $Cert (full path to the matching .pem, or "").
function Test-CosignBlob {
  param(
    [string]$Binary,
    [string]$Sig,
    [string]$Cert
  )
  if ($NoCosignVerify) { return 0 }
  $cosign = (Get-Command cosign -ErrorAction SilentlyContinue)
  if (-not $cosign) {
    Write-Warning "install.ps1: cosign not installed; skipping binary signature verification (use -NoCosignVerify to suppress this warning)"
    return 0
  }
  if (-not $Sig -or -not (Test-Path $Sig) -or -not $Cert -or -not (Test-Path $Cert)) {
    Write-Warning "install.ps1: cosign signature/certificate not published for $(Split-Path -Leaf $Binary) (pre-D6 release?); skipping verify"
    return 0
  }
  try {
    cosign verify-blob `
      --signature $Sig `
      --certificate $Cert `
      --certificate-identity-regexp $MC_COSIGN_IDENTITY_REGEXP `
      --certificate-oidc-issuer $MC_COSIGN_OIDC_ISSUER `
      $Binary | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Warning "install.ps1: cosign verify-blob: ok: $(Split-Path -Leaf $Binary)"
      return 0
    }
  } catch {}
  Write-Error "install.ps1: cosign verify-blob: FAIL: $(Split-Path -Leaf $Binary)"
  Write-Error "  the binary signature does not match the math-coding GitHub Actions OIDC issuer."
  Write-Error "  this can indicate a release-asset compromise, a pre-sign release, or a tampered binary."
  Write-Error "  retry with -NoCosignVerify only if you explicitly trust the release CDN for this version."
  Write-Error "diagnostic: MC-INSTALL-COSIGN-VERIFY-BLOB-FAIL"
  return 1
}

function Install-BinaryToDir {
  param(
    [string]$Tmp,
    [string]$Dir
  )
  if (-not (Test-Path $Dir)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
  }
  $dest = Join-Path $Dir $MC_BINARY_BASENAME
  Copy-Item -Path $Tmp -Destination $dest -Force
  return $dest
}

function Add-UserPath {
  param([string]$Dir)
  $current = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = $current -split ';' | Where-Object { $_ -and ($_ -ne $Dir) }
  $parts = @($Dir) + $parts
  $new = ($parts -join ';').TrimEnd(';')
  [Environment]::SetEnvironmentVariable('Path', $new, 'User')
}

function Install-UserSkill {
  param(
    [string]$Version,
    [bool]$UpgradeFlag
  )
  $skillDir = Join-Path $env:APPDATA 'opencode\skills\math-coding'
  $skillDst = Join-Path $skillDir 'SKILL.md'
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("mathc-skill-$([System.Guid]::NewGuid()).tar.gz")
  $url = Resolve-TarballUrl -Version $Version
  $rc = Download-File -Url $url -Out $tmp
  if ($rc -ne 0) { return $rc }

  # Extract adoption/opencode/SKILL.md from the tarball.
  $skillTmp = "$tmp-skillextract.md"
  try {
    # tar ships with Windows 10 1803+; we use the bundled tar.
    # We extract a single member using -C redirect.
    $cwdTmp = New-TempDir
    tar -xzf $tmp -C $cwdTmp adoption/opencode/SKILL.md 2>$null
    Copy-Item -Path (Join-Path $cwdTmp 'adoption/opencode/SKILL.md') -Destination $skillTmp -Force
    Remove-Item -Recurse -Force $cwdTmp
  } catch {
    Write-Error "install.ps1: cannot extract opencode/SKILL.md from tarball"
    Write-Error "diagnostic: MC-INSTALL-SKILL-EXTRACT"
    return 2
  }

  if ((Test-Path $skillDst) -and (-not $UpgradeFlag)) {
    $existingPin = Select-String -Path $skillDst -Pattern '^compatible_with:[[:space:]]*mathc@>=' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingPin -and $existingPin.Line.Trim() -eq "compatible_with: mathc@>=$Version") {
      Write-Warning "install.ps1: per-user skill already at version $Version (skip; -Upgrade to overwrite)"
      Remove-Item -Force $tmp, $skillTmp -ErrorAction SilentlyContinue
      return 0
    }
  }
  if (-not (Test-Path $skillDir)) {
    New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
  }
  Copy-Item -Path $skillTmp -Destination $skillDst -Force
  Remove-Item -Force $tmp, $skillTmp -ErrorAction SilentlyContinue
  Write-Output "install.ps1: per-user skill installed at $skillDst"
  return 0
}

function New-TempDir {
  $p = Join-Path ([System.IO.Path]::GetTempPath()) ("mathc-skill-$([System.Guid]::NewGuid())")
  New-Item -ItemType Directory -Path $p -Force | Out-Null
  return $p
}

# --- Main -------------------------------------------------------------------
if ($Help) {
  Write-Usage
  return 0
}

$arch = Get-Arch
if (-not $arch) {
  Write-Error "install.ps1: unsupported Windows architecture (need x64 or Arm64)."
  Write-Error "diagnostic: MC-INSTALL-ARCH-UNSUPPORTED"
  return 2
}

if (-not $Version) {
  Write-Error "install.ps1: -Version cannot be empty"
  return 2
}
if ($Version -notmatch '^[a-zA-Z0-9._-]+$') {
  Write-Error "install.ps1: -Version '$Version' has illegal characters"
  return 2
}

$assetName = Resolve-AssetName -Version $Version -Arch $arch
if (-not $assetName) {
  Write-Error "install.ps1: cannot resolve asset name for arch=$arch"
  return 2
}

$rc = Test-CosignImage -Version $Version
if ($rc -ne 0) { return $rc }

if ($Check) {
  $installDir = Pick-InstallDir
  $dest = Join-Path $installDir "$MC_BINARY_BASENAME.exe"
  if (-not (Test-Path $dest)) {
    Write-Error "install.ps1: -Check: $dest not installed"
    return 1
  }
  $out = & $dest version 2>$null
  if ($out -and ($out -like "*math-coding ${Version}:*")) {
    Write-Output "ok: $dest at version $Version"
    return 0
  }
  Write-Error "install.ps1: -Check: $dest present but reports a different version"
  return 1
}

$installDir = Pick-InstallDir
$sumsTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("mathc-sums-$([System.Guid]::NewGuid()).txt")
$binTmp  = Join-Path ([System.IO.Path]::GetTempPath()) ("mathc-bin-$([System.Guid]::NewGuid()).exe")
# D6: cosign blob signature + certificate scratch paths. Mirrored
# from the install.sh flow (`download_cosign_blob_assets` +
# `verify_cosign_blob`). Best-effort: a pre-D6 release that does not
# publish .sig / .pem yields empty paths, which `Test-CosignBlob`
# treats as "skip" with a warning to stderr.
$sigTmp   = Join-Path ([System.IO.Path]::GetTempPath()) ("mathc-bin-$([System.Guid]::NewGuid()).sig")
$certTmp  = Join-Path ([System.IO.Path]::GetTempPath()) ("mathc-bin-$([System.Guid]::NewGuid()).pem")

$sumsUrl = Resolve-SumsUrl -Version $Version
$rc = Download-File -Url $sumsUrl -Out $sumsTmp
if ($rc -ne 0) {
  Remove-Item -Force $sumsTmp -ErrorAction SilentlyContinue
  return $rc
}

$assetUrl = Resolve-AssetUrl -Version $Version -AssetName $assetName
$rc = Download-File -Url $assetUrl -Out $binTmp
if ($rc -ne 0) {
Remove-Item -Force $sumsTmp, $binTmp, $sigTmp, $certTmp -ErrorAction SilentlyContinue
  return $rc
}

# D6: download the cosign signature + certificate for the binary
# (best-effort). Skipped silently when -NoCosignVerify or cosign
# not on PATH. A pre-D6 release that does not publish .sig / .pem
# leaves the temp files empty; Test-CosignBlob then warns-and-skips.
if (-not $NoCosignVerify) {
  $cosignCmd = Get-Command cosign -ErrorAction SilentlyContinue
  if ($cosignCmd) {
    $sigUrl  = Resolve-AssetUrl -Version $Version -AssetName "$assetName.sig"
    $certUrl = Resolve-AssetUrl -Version $Version -AssetName "$assetName.pem"
    # Tolerate 404 / network error on each file individually; a
    # pre-D6 release that does not publish .sig / .pem is the
    # common case. We DO print a brief warning when the file is
    # absent (404 → NOT_FOUND), but only when cosign is installed
    # and verification is enabled (i.e., the user opted in).
    $sigRc = Download-File -Url $sigUrl  -Out $sigTmp
    if ($sigRc -ne 0) { Remove-Item -Force $sigTmp  -ErrorAction SilentlyContinue; New-Item -ItemType File -Path $sigTmp  -Force | Out-Null }
    $certRc = Download-File -Url $certUrl -Out $certTmp
    if ($certRc -ne 0) { Remove-Item -Force $certTmp -ErrorAction SilentlyContinue; New-Item -ItemType File -Path $certTmp -Force | Out-Null }
  } else {
    # No cosign on PATH; create empty placeholders so Test-CosignBlob
    # sees "missing" and prints its own warning. (Faster than the
    # if-tree because we don't actually need the temp files.)
    New-Item -ItemType File -Path $sigTmp  -Force | Out-Null
    New-Item -ItemType File -Path $certTmp -Force | Out-Null
  }
}

# D6: cosign blob verify (auth check). Runs BEFORE SHA-256 verify
# (integrity check); both gates are independently closed.
$rc = Test-CosignBlob -Binary $binTmp -Sig $sigTmp -Cert $certTmp
if ($rc -ne 0) {
  Remove-Item -Force $sumsTmp, $binTmp, $sigTmp, $certTmp -ErrorAction SilentlyContinue
  return $rc
}

$rc = Test-Sha256 -Sums $sumsTmp -Binary $binTmp -Base $assetName
if ($rc -ne 0) {
  Remove-Item -Force $sumsTmp, $binTmp, $sigTmp, $certTmp -ErrorAction SilentlyContinue
  return $rc
}

$dest = Install-BinaryToDir -Tmp $binTmp -Dir $installDir

# Optional user-PATH append.
if (-not $NoPathUpdate) {
  try {
    Add-UserPath -Dir $installDir
    Write-Output "install.ps1: user PATH appended: $installDir"
  } catch {
    Write-Warning "install.ps1: user-PATH append failed: $($_.Exception.Message)"
  }
}

# Optional user-skill install.
if ($UserSkill) {
  $skillRc = Install-UserSkill -Version $Version -UpgradeFlag:$Upgrade
  if ($skillRc -ne 0) {
    Write-Warning "install.ps1: skill install failed; binary is at $dest (continuing)"
  }
}

Remove-Item -Force $sumsTmp, $binTmp -ErrorAction SilentlyContinue

Write-Output "install.ps1: installed to $dest"
if (Test-Path $dest) {
  & $dest version
  Write-Output "install.ps1: restart the shell for PATH to take effect"
}

return 0
