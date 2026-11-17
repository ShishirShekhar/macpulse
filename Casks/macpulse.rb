cask "macpulse" do
  version "1.5.0"
  sha256 "b7d79e26562dde9e89d79d4142fa26833308e36fec3ffdb6757e5c77077a370c"

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
