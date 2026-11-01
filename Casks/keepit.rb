# Homebrew cask. Install:
#   brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
#   brew install --cask andrey-insarov/keepit/keepit
# version/sha256 are rewritten by CI on every release (make cask).
cask "keepit" do
  version "2.6.0"
  sha256 "7b125e1935e35634eb21d1550b806cd75ca238b836703a037c8bd2a404109dc5"

  url "https://github.com/andrey-insarov/Keepit/releases/download/v#{version}/Keepit-#{version}.dmg"
  name "Keepit – Clipboard Manager"
  desc "Clipboard history and templates with encryption, Touch ID and hot keys"
  homepage "https://keep.it.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

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
