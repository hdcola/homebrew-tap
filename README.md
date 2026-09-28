# hdcola/tap

Personal Homebrew tap for [hdcola](https://github.com/hdcola)'s casks.

## Install

```bash
brew tap hdcola/tap
brew trust hdcola/tap
brew install --cask omnivoice
```

`brew trust` (Homebrew 7+ only — older versions load third-party taps
without it) tells Homebrew this tap is fine to load; skip it and
`brew install` stops with "Refusing to load cask ... from untrusted tap".

## Casks

- [`omnivoice`](Casks/omnivoice.rb) — [OmniVoice](https://github.com/hdcola/OmniVoice),
  a real-time speech transcription & translation assistant for macOS. See
  its own repo for release notes and testing instructions.
