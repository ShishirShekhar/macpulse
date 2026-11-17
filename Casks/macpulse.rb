cask "macpulse" do
  version "1.7.0"
  sha256 "4e43aff3d92320f73c3796a3b70f034c3b9be6c0a2cf379007a1b458f815886c"

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
