cask "omnivoice" do
  version "0.5.1"
  sha256 "6786730466ee2fe0d55c4ad60efff9097a46498a211dabc71f739e96bc38c9c6"

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
    OmniVoice #{version} is an internal test build: ad-hoc signed only,
    not notarized. Gatekeeper will refuse to open it with something like
    "OmniVoice.app is damaged and can't be opened" until you clear the
    quarantine flag:

      xattr -cr /Applications/OmniVoice.app

    It also needs microphone, speech recognition, and (for system-audio
    capture) screen recording permission on first run. See:
    https://github.com/hdcola/OmniVoice/blob/main/Docs/RELEASE_TESTING.md
  EOS
end
