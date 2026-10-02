# SpotWidget

A native macOS desktop widget for Spotify. It shows the current track, album art, progress, playback controls, and lyrics in a compact WidgetKit experience that can sit on the desktop.

The project includes:

- Small, medium, and large WidgetKit layouts.
- Album-art focused layouts that scale from small to extra large.
- Play, pause, previous, and next controls.
- A live progress display without direct scrubbing.
- Synced and plain lyrics from [LRCLIB](https://lrclib.net).
- Plain-lyrics page controls for tracks without synced lyrics.
- A tiny menu bar helper that keeps a local bridge running for faster Spotify control.

## Requirements

- macOS 14 or newer.
- Xcode with the macOS SDK.
- Spotify desktop app installed.
- An Apple ID signed into Xcode. A free Personal Team is enough for local use.

## Build With Xcode

Use the Xcode project when you want the widget to appear in macOS's desktop widget picker.

1. Open `SpotWidget.xcodeproj` in Xcode.
2. Select the `SpotWidget` project in the navigator.
3. Select the `SpotWidget` target, then `Signing & Capabilities`.
4. Enable `Automatically manage signing`.
5. Choose your Apple ID or Personal Team.
6. Repeat steps 3-5 for the `SpotWidgetExtension` target.
7. Build and run the `SpotWidget` scheme.
8. Open the desktop widget picker and search for `SpotWidget`.

Default bundle identifiers:

```text
com.leounib.SpotWidget
com.leounib.SpotWidget.SpotWidgetExtension
```

If Xcode says a bundle identifier is unavailable, change `leounib` to something unique in both targets.

## Install Locally

The easiest route on a new Mac is the install script:

```bash
git clone git@github.com:JuusBocks/spotwidget.git
cd spotwidget
./scripts/install-local.sh --team-id YOUR_TEAM_ID
```

After signing has been configured once in Xcode, the team flag is usually optional:

```bash
./scripts/install-local.sh
```

The script builds SpotWidget, copies it to `/Applications`, registers the widget extension, refreshes WidgetKit, and opens the menu bar helper.

For a dedicated second-Mac checklist, see [INSTALL.md](INSTALL.md).

After a successful Xcode build, copy the app into `/Applications` and launch it:

```bash
cp -R "$HOME/Library/Developer/Xcode/DerivedData/SpotWidget-"*/Build/Products/Debug/"SpotWidget.app" /Applications/
open "/Applications/SpotWidget.app"
```

For a deterministic command-line build that keeps output inside this repository, replace `YOUR_TEAM_ID` with your Apple Developer Team ID or omit that setting after configuring signing in Xcode:

```bash
xcodebuild \
  -project SpotWidget.xcodeproj \
  -scheme SpotWidget \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates \
  build

cp -R build/DerivedData/Build/Products/Debug/"SpotWidget.app" /Applications/
open "/Applications/SpotWidget.app"
```

Then add the widget:

1. Control-click the desktop.
2. Choose `Edit Widgets`.
3. Search for `SpotWidget`.
4. Drag the widget to the desktop.

Approve macOS Automation access if prompted. The widget reads and controls the local Spotify app with AppleScript.

## Helper App

The app runs as a menu bar utility. It does not open a normal player window.

The menu bar icon exists because WidgetKit extensions are short-lived. The helper app runs a localhost bridge on `127.0.0.1:47391`, caches Spotify metadata, and sends playback commands. This makes the widget controls much more reliable than asking the widget extension to run AppleScript directly every time.

## Lyrics

Lyrics are fetched from LRCLIB using track title, artist, album, and duration. When synced lyrics are available, the large widget highlights the current line. When only plain lyrics are available, the large widget shows page controls.

LRCLIB may not have every song. Spotify itself does not expose full lyrics through its documented public API.

## Manual Build Script

There is also a script for local compile checks:

```bash
./scripts/build-app.sh
```

The app bundle is created at:

```text
build/SpotWidget.app
```

This path is useful for development, but the Xcode build with your Apple Team is the recommended route for a real desktop widget install.

## Resource Smoke Test

To check that SpotWidget stays light while Spotify is playing, run:

```bash
./scripts/resource-smoke-test.sh --launch --duration 300
```

The test samples SpotWidget once per second, writes a CSV and text report to `reports/`, and fails if average CPU rises above `2%` or memory rises above `150 MB`.

For a longer test on another Mac:

```bash
./scripts/resource-smoke-test.sh --launch --duration 1800
```

While it runs, play Spotify, skip a few tracks, pause/resume, and toggle shuffle. The widget itself is hosted by macOS, so this script focuses on the SpotWidget helper process that does the Spotify polling and command bridge.

## Package A Downloadable App

To create release packages that can be uploaded to a GitHub Release:

```bash
./scripts/package-app.sh --team-id YOUR_TEAM_ID --version 0.1.0
```

The packages are written to:

```text
dist/SpotWidget-0.1.0-macOS.dmg
dist/SpotWidget-0.1.0-macOS.zip
```

Use the DMG for the familiar drag-to-Applications install experience. The zip is useful for checksums, automation, and Homebrew-style packaging.

For personal testing, a private GitHub Release is fine. For a smooth public install, sign the app with a Developer ID certificate and notarize it with Apple before uploading.

## Create A GitHub Release

For private testing:

```bash
./scripts/release-github.sh --team-id YOUR_TEAM_ID --version 0.1.0
```

This builds `dist/SpotWidget-0.1.0-macOS.dmg` and `dist/SpotWidget-0.1.0-macOS.zip`, creates a `v0.1.0` GitHub release, and uploads both files plus SHA-256 files.

For a stable release:

```bash
./scripts/release-github.sh --team-id YOUR_TEAM_ID --version 0.1.0 --stable
```

Only use `--stable` for a broadly shared release after the app has been Developer ID signed and notarized.

## Homebrew Distribution

SpotWidget can be distributed through Homebrew, but the clean version requires a signed and notarized `.zip` or `.dmg` release.

Recommended path:

1. Create a release build in Xcode.
2. Sign the app with a Developer ID Application certificate.
3. Notarize it with Apple.
4. Package the notarized `SpotWidget.app` as a zip or DMG.
5. Upload the package to a GitHub release.
6. Create a Homebrew tap with a cask formula that downloads and installs the app.

Example cask shape:

```ruby
cask "spotwidget" do
  version "1.0.0"
  sha256 "REPLACE_WITH_RELEASE_ZIP_SHA256"

  url "https://github.com/JuusBocks/spotwidget/releases/download/v#{version}/SpotWidget-#{version}.zip"
  name "SpotWidget"
  desc "Native macOS desktop widget for Spotify"
  homepage "https://github.com/JuusBocks/spotwidget"

  app "SpotWidget.app"
end
```

Users would install it with:

```bash
brew tap JuusBocks/spotwidget
brew install --cask spotwidget
```

For a private GitHub repo, Homebrew installation is more awkward because the download needs authentication. A private tap can work for collaborators with GitHub access, but public distribution is much smoother after the repo or release artifact is public.

## Troubleshooting

- If the widget does not update after a rebuild, remove it from the desktop and add it again.
- If controls stop working, make sure `SpotWidget.app` is running in the menu bar.
- If macOS asks for Automation permission, allow Spotify access.
- If the widget picker does not show the widget, rebuild from Xcode with a real Apple Team selected and launch the app once.
- If lyrics are missing, the current track likely is not in LRCLIB.

## Privacy

The app talks to:

- Spotify locally through AppleScript.
- `127.0.0.1:47391` between the helper app and widget extension.
- `lrclib.net` for lyrics lookup.

No Spotify account credentials are used or stored by this app.
