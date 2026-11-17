cask "macpulse" do
  version "1.4.0"
  sha256 "945028180f89eee80eeb878d1d35cb6658e8350d7e576b66d80cd7d06e5993fb"

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
