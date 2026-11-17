cask "macpulse" do
  version "1.6.0"
  sha256 "ab9f5a897bc7043cfe2469430fd8764dc3fff43325d00572d3dd2a443f930db2"

  url "https://github.com/ShishirShekhar/macpulse/releases/download/v#{version}/MacPulse-v#{version}.zip"
  name "MacPulse"
  desc "Native, fast, private macOS health dashboard"
  homepage "https://github.com/ShishirShekhar/macpulse"

  depends_on macos: ">= :ventura"

  app "MacPulse.app"

  uninstall launchctl: "com.macpulse.daily",
            quit:      "com.macpulse.app"

  zap trash: [
    "~/Library/Application Support/MacPulse",
    "~/Library/LaunchAgents/com.macpulse.daily.plist",
    "~/Library/Logs/MacPulse.log",
    "~/Library/Preferences/com.macpulse.app.plist",
  ]
end
