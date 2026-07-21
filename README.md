# LINE standalone app (Linux)

Turns the official **LINE Chrome extension** into a standalone desktop app: its own
chromeless window, taskbar/dock entry, and icon — no browser tabs or address bar.

It does this by launching the extension's UI in Chrome's `--app` mode. The window
still runs inside the extension context, so every `chrome.*` API and your existing
LINE login keep working. This is *not* a detached web app — LINE's UI depends on
extension-only APIs (`chrome.storage`, `chrome.cookies`, `chrome.notifications`, …)
and on the extension bypassing CORS, so running it truly outside Chrome isn't
practical.

## Prerequisites

- Google Chrome (or Chromium) installed.
- The official **LINE** extension installed and logged in:
  https://chromewebstore.google.com/detail/line/ophjlpahpchlmihnnnihgmmeilfjmjjc
- A Linux desktop (built/tested on GNOME + native Wayland; also works on X11).

## Install

```bash
git clone <this-repo> line-standalone-app
cd line-standalone-app
./install.sh
```

The installer auto-detects which Chrome profile has LINE installed (preferring
`Default`). Then search **LINE** in your app menu and launch it.

Useful options:

```bash
./install.sh --list                 # show profiles that have LINE installed
./install.sh --profile "Profile 1"  # install for a specific profile
```

Environment overrides (rarely needed):

- `CHROME_BIN=/path/to/chrome` — pick a specific browser binary.
- `CHROME_CONFIG=~/.config/google-chrome` — pick a specific config dir.

## Uninstall

```bash
./uninstall.sh
```

## Why the launcher looks the way it does (GNOME Wayland)

Under native Wayland, Chrome tags an `--app=` window with a computed `app_id`:

```
chrome-<extension-id>__index.html-<Profile>
```

(e.g. `chrome-ophjlpahpchlmihnnnihgmmeilfjmjjc__index.html-Default`; a profile named
`Profile 1` becomes `Profile_1`). GNOME matches a running window to a launcher by
that `app_id`, so the `.desktop` file's **filename** and its **`StartupWMClass`**
must both equal that exact string — otherwise the window shows a generic/blank icon
instead of grouping under the launcher. The `--class` flag does *not* affect this;
Chrome ignores it for app windows. The installer computes and sets this for you,
which is why re-running it after switching profiles is necessary.

## Files

- `install.sh` — detects profile, installs the launcher, and extracts the LINE
  icon from your locally-installed extension.
- `uninstall.sh` — removes them.

The LINE logo is not bundled (it's LINE Corporation's trademark); the installer
copies it from your own installed extension at install time.
