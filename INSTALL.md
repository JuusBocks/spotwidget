# Install SpotWidget On Another Mac

Use this when testing SpotWidget on another Mac that has access to the private GitHub repo.

## Quick Install

1. Download `SpotWidget-0.1.0-macOS.dmg` from the GitHub Release.
2. Open the DMG.
3. Drag `SpotWidget.app` into `Applications`.
4. Open `SpotWidget.app`.
5. If macOS blocks the app, open `System Settings` > `Privacy & Security`, scroll down, choose `Open Anyway`, then open SpotWidget again.
6. On the desktop, right-click and choose `Edit Widgets`.
7. Search for `SpotWidget`, add the widget, then start playing something in Spotify.

SpotWidget shows album art, playback controls, live progress, and lyrics when they are available. Some songs may not have lyrics, and some lyric views may need a quick interaction with the widget before they show. When LRCLIB has the track, SpotWidget supports a wide range of synced lyrics.

## Best Test Path

This is the most reliable path while SpotWidget is still a private developer build.

### 1. Prepare the Mac

Install:

- Spotify
- Xcode from the Mac App Store

Open Xcode once and sign in with your Apple ID:

1. Open Xcode.
2. Go to `Xcode` > `Settings` > `Accounts`.
3. Add your Apple ID.

### 2. Clone and Install

```bash
git clone git@github.com:JuusBocks/spotwidget.git
cd spotwidget
./scripts/install-local.sh --team-id YOUR_TEAM_ID
```

If Xcode signing has already been configured on that Mac, this is usually enough:

```bash
./scripts/install-local.sh
```

The installer builds the app, copies it to `/Applications`, registers the widget, refreshes WidgetKit, and opens SpotWidget.

### 3. Add the Widget

1. Control-click the desktop.
2. Choose `Edit Widgets`.
3. Search for `SpotWidget`.
4. Drag a SpotWidget widget to the desktop.

Allow Automation access if macOS asks. SpotWidget needs it to read and control Spotify.

## Downloadable DMG Path

From your main Mac, create release packages:

```bash
./scripts/package-app.sh --team-id YOUR_TEAM_ID --version 0.1.0
```

Upload `dist/SpotWidget-0.1.0-macOS.dmg` to a GitHub Release.

Or build and publish the private GitHub release in one step:

```bash
./scripts/release-github.sh --team-id YOUR_TEAM_ID --version 0.1.0
```

On the MacBook:

1. Download the DMG from the GitHub Release.
2. Open it.
3. Drag `SpotWidget.app` onto `Applications`.
4. Open `SpotWidget.app`.
5. If macOS blocks it, go to `System Settings` > `Privacy & Security`, scroll down, click `Open Anyway`, then open it again.
6. Add the widget from `Edit Widgets`.

For personal testing, macOS may still warn about the app if it is not Developer ID signed and notarized. For a smooth public install, the release DMG should contain a Developer ID signed and notarized app.

## Troubleshooting

- If `SpotWidget` does not appear in the widget picker, run `./scripts/install-local.sh` again and restart the Mac.
- If playback controls do nothing, make sure `SpotWidget.app` is open in the menu bar.
- If macOS asks for Spotify Automation access, allow it.
- If Xcode reports a signing error, open the project in Xcode and choose your Apple ID team for both the app target and widget extension target.
