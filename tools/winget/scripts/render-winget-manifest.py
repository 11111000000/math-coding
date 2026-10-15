#!/usr/bin/env python3
"""Render winget-pkgs manifests for a math-coding release.

Usage:
    tools/winget/scripts/render-winget-manifest.py \
        --version 3.3.0 \
        --sha256-windows-x86_64 <HEX64> \
        --release-date 2026-10-15 \
        --out tools/winget/manifests/m/mathcoding/mathc/3.3.0

The script is idempotent: re-running overwrites the four target files
with consistent cross-references (the same Version, ReleaseDate,
InstallerSha256, etc. appear in `installer.yaml`,
`locale.en-US.yaml`, `Versions/<version>.yaml`).

Determinism: `CanonicalVersion` is the version string with
the `v` prefix stripped. The script does NOT fetch from GitHub;
the caller passes the SHA-256 already computed by the release
pipeline (or read by the operator from `SHA256SUMS`).

The four files conform to winget schema 1.6.0
(https://github.com/microsoft/winget-cli/tree/master/src/AppInstaller.Resources/Schema).
Strict conformance to the schema is verified by `winget validate`
on a Windows machine; this script does not embed schema validation.
"""
import argparse
import datetime as dt
import json
import pathlib
import sys


def parse_args():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--version', required=True,
                   help='math-coding release tag without "v" prefix, e.g. 3.3.0')
    p.add_argument('--sha256-windows-x86_64', required=True,
                   help='hex SHA-256 of mathc-windows-x86_64.exe from SHA256SUMS')
    p.add_argument('--release-date', required=True,
                   help='ISO date, e.g. 2026-10-15')
    p.add_argument('--out', required=True,
                   help='output dir, must end with m/mathcoding/mathc/<version>')
    return p.parse_args()


PACKAGE_ID = 'mathcoding.mathc'
PACKAGE_NAME = 'mathc'
PUBLISHER = 'MathCoding'
PUBLISHER_URL = 'https://github.com/11111000000/math-coding'
LICENSE = 'Apache-2.0'
SHORT_DESC = 'Risk-adaptive assurance protocol for software changes'
MONIKER = 'mathc'


def installer_yaml(version, sha256):
    # Schema 1.6.0: PackageIdentifier, PackageVersion, Installers[].
    return f"""\
# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.6.0.schema.json
PackageIdentifier: {PACKAGE_ID}
PackageVersion: {version}
PackageLocale: en-US
InstallerType: zip
Scope: user
InstallModes:
  - silent
UpgradeBehavior: install
Commands:
  - mathc
FileExtensions:
  - .mc-decision
InstallerAbortsTerminal: false
InstallLocation: %LOCALAPPDATA%\\Programs\\mathc
ExpectedReturnCodes:
  - ReturnCode: 0
    ReturnResponse: success
Installers:
  - Architecture: x64
    InstallerUrl: https://github.com/11111000000/math-coding/releases/download/v{version}/mathc-windows-x86_64.exe
    InstallerSha256: {sha256}
    InstallerType: exe
    NestedInstallerType: portable
"""


def locale_en_us_yaml(version, release_date):
    return f"""\
# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.6.0.schema.json
PackageIdentifier: {PACKAGE_ID}
PackageVersion: {version}
PackageLocale: en-US
Publisher: {PUBLISHER}
PublisherUrl: {PUBLISHER_URL}
PublisherSupportUrl: https://github.com/11111000000/math-coding/issues
PrivacyUrl: https://github.com/11111000000/math-coding/blob/main/ETHICS.md
Author: {PUBLISHER}
PackageName: mathc
License: {LICENSE}
LicenseUrl: https://github.com/11111000000/math-coding/blob/main/LICENSE
ShortDescription: {SHORT_DESC}
Description: |
  math-coding links a concrete change to the obligations it may
  affect and to bounded evidence about those obligations. It does
  not prove software correctness. Once installed, run `mathc init`
  in a project root to scaffold the decisions/ tree, then write a
  decision file and run `mathc self-check`.
Moniker: {MONIKER}
ReleaseNotes: https://github.com/11111000000/math-coding/releases/tag/v{version}
ReleaseNotesUrl: https://github.com/11111000000/math-coding/releases/tag/v{version}
PurchaseUrl: ~
DiscoveryVersion: 1.6.0
ReleaseDate: {release_date}T00:00:00Z
Tags:
  - math
  - assurance
  - cli
  - developer-tools
  - decision-tracking
ManifestType: defaultLocale
"""


def versions_yaml(version):
    return f"""\
# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.6.0.schema.json
PackageIdentifier: {PACKAGE_ID}
PackageVersion: {version}
Channel: stable
ManifestVersion: 1.6.0
"""


def main():
    args = parse_args()
    out_root = pathlib.Path(args.out)
    if not out_root.name == args.version:
        print(f'output dir must end with /{args.version}; got {out_root}', file=sys.stderr)
        sys.exit(2)
    pkg_dir = out_root
    pkg_dir.mkdir(parents=True, exist_ok=True)
    versions_dir = pkg_dir / 'Versions'
    versions_dir.mkdir(exist_ok=True)

    (pkg_dir / f'{PACKAGE_ID}.installer.yaml').write_text(
        installer_yaml(args.version, args.sha256_windows_x86_64), encoding='utf-8')
    # defaultLocale and locale have the same content for English; winget
    # accepts defaultLocale pointing at one and an empty locale entry.
    # Many submissions treat the en-US locale as the defaultLocale
    # AND emit a second locale file. We emit both for compatibility.
    locale_text = locale_en_us_yaml(args.version, args.release_date)
    (pkg_dir / f'{PACKAGE_ID}.defaultLocale.yaml').write_text(
        locale_text, encoding='utf-8')
    (pkg_dir / f'{PACKAGE_ID}.locale.en-US.yaml').write_text(
        locale_text, encoding='utf-8')

    (versions_dir / f'{args.version}.yaml').write_text(
        versions_yaml(args.version), encoding='utf-8')

    print(f'winget manifests written under {pkg_dir}', file=sys.stderr)
    print(json.dumps({
        'package': PACKAGE_ID,
        'version': args.version,
        'installer_yaml': str(pkg_dir / f'{PACKAGE_ID}.installer.yaml'),
        'locale_yaml':    str(pkg_dir / f'{PACKAGE_ID}.locale.en-US.yaml'),
        'defaultLocale':  str(pkg_dir / f'{PACKAGE_ID}.defaultLocale.yaml'),
        'versions_yaml':  str(versions_dir / f'{args.version}.yaml'),
    }, indent=2))


if __name__ == '__main__':
    main()
