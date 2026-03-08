class Dxai < Formula
  desc "Clean, optimize, and manage AI dev environments on your Mac"
  homepage "https://github.com/glen15/dxai"
  url "https://github.com/glen15/dxai/archive/refs/tags/V#{version}.tar.gz"
  license "MIT"
  head "https://github.com/glen15/dxai.git", branch: "main"

  depends_on :macos
  depends_on "go" => :build

  resource "binaries-arm64" do
    on_arm do
      url "https://github.com/glen15/dxai/releases/download/V#{version}/binaries-darwin-arm64.tar.gz"
    end
  end

  resource "binaries-amd64" do
    on_intel do
      url "https://github.com/glen15/dxai/releases/download/V#{version}/binaries-darwin-amd64.tar.gz"
    end
  end

  def install
    # Install main CLI script
    bin.install "dxai"

    # Install support files
    (var/"lib/dxai").install Dir["bin/*.sh"]
    (var/"lib/dxai/lib").install Dir["lib/*"]

    # Build Go binaries if not using pre-built
    config_bin = var/"lib/dxai/bin"
    config_bin.mkpath

    system "go", "build", *std_go_args(ldflags: "-s -w", output: config_bin/"analyze-go"), "./cmd/analyze"
    system "go", "build", *std_go_args(ldflags: "-s -w", output: config_bin/"status-go"), "./cmd/status"
  end

  test do
    assert_match "dxai version", shell_output("#{bin}/dxai --version")
  end
end
