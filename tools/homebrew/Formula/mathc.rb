class Mathc < Formula
  desc "Risk-adaptive assurance protocol for software changes"
  homepage "https://github.com/11111000000/math-coding"
  url "https://github.com/11111000000/math-coding/releases/download/v3.3.0/mathc-darwin-aarch64"
  sha256 "202a09d8a114c1eb9cc0ab3c94500898737c24ee7287778d6adb8bf79e3a6a3d"
  license "Apache-2.0"
  version "3.3.0"

  livecheck do
    url :stable
    regex(/v(\d+(?:\.\d+)+)/)
  end

  def install
    bin.install "mathc-darwin-aarch64" => "mathc"
  end

  test do
    assert_match "math-coding #{version}", shell_output("#{bin}/mathc version")
  end
end
