cask "omnivoice" do
  version "0.8.2"
  sha256 "b4391e535747c73c630cbff944656dea71c4f8db2ef0ad2d8509bf475cb69101"

  url "https://github.com/hdcola/OmniVoice/releases/download/v#{version}/OmniVoice-#{version}.dmg"
  name "OmniVoice"
  desc "Real-time speech transcription & translation assistant"
  homepage "https://github.com/hdcola/OmniVoice"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "OmniVoice.app"

  caveats <<~EOS
    OmniVoice #{version} is an internal test build: signed with a self-signed
    certificate, not notarized. Gatekeeper will refuse to open it with something like
    "OmniVoice.app is damaged and can't be opened" until you clear the
    quarantine flag:

      xattr -cr /Applications/OmniVoice.app

    It also needs microphone, speech recognition, and (for system-audio
    capture) screen recording permission on first run. See:
    https://github.com/hdcola/OmniVoice/blob/main/Docs/RELEASE_TESTING.md
  EOS
end
