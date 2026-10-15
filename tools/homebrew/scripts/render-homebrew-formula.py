#!/usr/bin/env python3
"""Render a Homebrew formula for a math-coding release.

Usage:
    tools/homebrew/scripts/render-homebrew-formula.py \
        --version 3.3.0 \
        --sha256-darwin-aarch64 <HEX64> \
        --sha256-darwin-x86_64 <HEX64> \
        --sha256-linux-x86_64 <HEX64> \
        --out tools/homebrew/Formula/mathc.rb

The output is a Ruby class ready for commit to
github.com/11111000000/homebrew-tap:Formula/mathc.rb.
"""
import argparse


HOMEBREW_URL_BASE = 'https://github.com/11111000000/math-coding/releases/download'


def render(version, sha_darwin_arm, sha_darwin_x64, sha_linux):
    return f'''class Mathc < Formula
  desc "Risk-adaptive assurance protocol for software changes"
  homepage "https://github.com/11111000000/math-coding"
  url "{HOMEBREW_URL_BASE}/v{version}/mathc-darwin-aarch64"
  sha256 "{sha_darwin_arm}"
  license "Apache-2.0"
  version "{version}"

  livecheck do
    url :stable
    regex(/v(\\d+(?:\\.\\d+)+)/)
  end

  def install
    bin.install "mathc-darwin-aarch64" => "mathc"
  end

  test do
    assert_match "math-coding #{{version}}", shell_output("#{{bin}}/mathc version")
  end
end
'''


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--version', required=True)
    p.add_argument('--sha256-darwin-aarch64', required=True)
    p.add_argument('--sha256-darwin-x86_64', required=False, default='')
    p.add_argument('--sha256-linux-x86_64', required=False, default='')
    p.add_argument('--out', required=True)
    args = p.parse_args()
    out = render(args.version, args.sha256_darwin_aarch64,
                 args.sha256_darwin_x86_64, args.sha256_linux_x86_64)
    with open(args.out, 'w') as f:
        f.write(out)
    print(f'wrote {args.out}')


if __name__ == '__main__':
    main()
