# Homebrew cask. Install:
#   brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
#   brew install --cask andrey-insarov/keepit/keepit
# version/sha256 are rewritten by CI on every release (make cask).
cask "keepit" do
  version "2.13.0"
  sha256 "af19d4541ea59a3356e17b53e6c49aed517f44132c1c0dab4615c3d9e69bb555"

  url "https://github.com/andrey-insarov/Keepit/releases/download/v#{version}/Keepit-#{version}.dmg"
  name "Keepit – Clipboard Manager"
  desc "Clipboard history and templates with encryption, Touch ID and hot keys"
  homepage "https://keep.it.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :ventura

  app "Keepit.app"

  uninstall quit:       "com.it.keep",
            login_item: "Keepit"

  zap trash: [
    "~/Library/Application Support/Keepit",
    "~/Library/Caches/com.it.keep",
    "~/Library/HTTPStorages/com.it.keep",
    "~/Library/Preferences/com.it.keep.plist",
    "~/Library/Saved Application State/com.it.keep.savedState",
  ]
end
