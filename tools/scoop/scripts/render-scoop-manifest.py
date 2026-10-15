#!/usr/bin/env python3
"""Render a Scoop manifest for a math-coding release.

Usage:
    tools/scoop/scripts/render-scoop-manifest.py \
        --version 3.3.0 \
        --sha256-windows-x86_64 <HEX64> \
        --out tools/scoop/mathc.json

The output is a single JSON object ready for commit to
github.com/ScoopInstaller/Extras:bucket/mathc.json.
"""
import argparse
import json
import sys


SCOOP_URL_BASE = 'https://github.com/11111000000/math-coding/releases/download'


def render(version, sha256):
    return {
        "$schema": "https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/schema.json",
        "version": version,
        "description": "math-coding CLI: risk-adaptive assurance protocol for software changes",
        "homepage": "https://github.com/11111000000/math-coding",
        "license": "Apache-2.0",
        "depends": None,
        "url": f"{SCOOP_URL_BASE}/v{version}/mathc-windows-x86_64.exe",
        "hash": sha256,
        "bin": [["mathc.exe", "mathc"]],
        "checkver": {
            "url": "https://api.github.com/repos/11111000000/math-coding/releases/latest",
            "jsonpath": "$.tag_name",
            "regex": "v([\\d.]+)"
        },
        "autoupdate": {
            "url": f"{SCOOP_URL_BASE}/v$version/mathc-windows-x86_64.exe",
            "hash": {
                "url": "https://github.com/11111000000/math-coding/releases/latest",
                "kind": "sha256"
            }
        }
    }


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--version', required=True)
    p.add_argument('--sha256-windows-x86_64', required=True)
    p.add_argument('--out', required=True)
    args = p.parse_args()
    manifest = render(args.version, args.sha256_windows_x86_64)
    with open(args.out, 'w') as f:
        json.dump(manifest, f, indent=2)
        f.write('\n')
    print(f'wrote {args.out}', file=sys.stderr)
    print(json.dumps({'version': args.version, 'path': args.out}))


if __name__ == '__main__':
    main()
