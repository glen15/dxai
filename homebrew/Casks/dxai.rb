cask "dxai" do
  version :latest
  sha256 :no_check

  url "https://github.com/glen15/dxai/releases/latest/download/DxaiBar.zip"
  name "Deus eX AI"
  desc "AI dev environment manager for your Mac menu bar"
  homepage "https://github.com/glen15/dxai"

  depends_on macos: ">= :ventura"

  app "DxaiBar.app"

  postflight do
    system_command "/usr/bin/open", args: [staged_path.join("DxaiBar.app")]
  end

  zap trash: [
    "~/Library/Preferences/com.dxai.DxaiBar.plist",
    "~/Library/Caches/com.dxai.DxaiBar",
    "~/.config/dxai",
  ]
end
