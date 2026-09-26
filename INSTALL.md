# Install Widgify On Another Mac

Use this when testing Widgify on another Mac that has access to the private GitHub repo.

## Best Test Path

This is the most reliable path while Widgify is still a private developer build.

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
git clone git@github.com:JuusBocks/widgify.git
cd widgify
./scripts/install-local.sh --team-id YOUR_TEAM_ID
```

If Xcode signing has already been configured on that Mac, this is usually enough:

```bash
./scripts/install-local.sh
```

The installer builds the app, copies it to `/Applications`, registers the widget, refreshes WidgetKit, and opens Widgify.

### 3. Add the Widget

1. Control-click the desktop.
2. Choose `Edit Widgets`.
3. Search for `Widgify`.
4. Drag a Widgify widget to the desktop.

Allow Automation access if macOS asks. Widgify needs it to read and control Spotify.

## Downloadable Zip Path

From your main Mac, create a zip:

```bash
./scripts/package-app.sh --team-id YOUR_TEAM_ID --version 0.1.0
```

Upload `dist/Widgify-0.1.0-macOS.zip` to a GitHub Release.

On the MacBook:

1. Download the zip from the GitHub Release.
2. Unzip it.
3. Move `Widgify.app` to `/Applications`.
4. Open `Widgify.app`.
5. Add the widget from `Edit Widgets`.

For personal testing, macOS may still warn about the app if it is not Developer ID signed and notarized. For a smooth public install, the release zip should be signed with a Developer ID certificate and notarized by Apple.

## Troubleshooting

- If `Widgify` does not appear in the widget picker, run `./scripts/install-local.sh` again and restart the Mac.
- If playback controls do nothing, make sure `Widgify.app` is open in the menu bar.
- If macOS asks for Spotify Automation access, allow it.
- If Xcode reports a signing error, open the project in Xcode and choose your Apple ID team for both the app target and widget extension target.
