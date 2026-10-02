cask "omnivoice" do
  version "0.6.0"
  sha256 "912534140556c0580e4969dc95d6398bff7bdee2b2fceb75be996d0c18b5751e"

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
