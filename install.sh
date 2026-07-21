#!/usr/bin/env bash
#
# Install a standalone desktop launcher for the official LINE Chrome extension.
# Runs LINE in Chrome's --app mode (its own chromeless window) while keeping the
# full extension context, so all chrome.* APIs and the existing login work.
#
# Usage:
#   ./install.sh                 # auto-detect profile (prefers "Default")
#   ./install.sh --profile "Profile 1"
#   ./install.sh --list          # list Chrome profiles that have LINE installed
#
set -euo pipefail

# Official LINE extension id (Chrome Web Store).
EXTID="ophjlpahpchlmihnnnihgmmeilfjmjjc"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"

# --- locate Chrome binary + config dir ------------------------------------
CHROME_BIN="${CHROME_BIN:-}"
if [[ -z "$CHROME_BIN" ]]; then
  for c in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1; then CHROME_BIN="$(command -v "$c")"; break; fi
  done
fi
[[ -n "$CHROME_BIN" ]] || { echo "ERROR: no Chrome/Chromium binary found (set CHROME_BIN=...)." >&2; exit 1; }

# Config dir matches the binary family (google-chrome vs chromium).
if [[ -z "${CHROME_CONFIG:-}" ]]; then
  case "$CHROME_BIN" in
    *chromium*) CHROME_CONFIG="$HOME/.config/chromium" ;;
    *)          CHROME_CONFIG="$HOME/.config/google-chrome" ;;
  esac
fi
[[ -d "$CHROME_CONFIG" ]] || { echo "ERROR: Chrome config dir not found: $CHROME_CONFIG" >&2; exit 1; }

# --- helpers ---------------------------------------------------------------
profiles_with_line() {
  # print profile dir names (Default, "Profile 1", ...) that have the extension
  for d in "$CHROME_CONFIG"/*/Extensions/"$EXTID"; do
    [[ -d "$d" ]] || continue
    basename "$(dirname "$(dirname "$d")")"
  done
}

# Chrome derives the Wayland app_id / X11 WM_CLASS from the profile dir with
# spaces replaced by underscores, e.g. "Profile 1" -> "Profile_1".
appid_for_profile() {
  local prof="$1"
  printf 'chrome-%s__index.html-%s' "$EXTID" "${prof// /_}"
}

# --- arg parsing -----------------------------------------------------------
PROFILE=""
case "${1:-}" in
  --list)
    echo "Chrome profiles with the LINE extension installed:"
    profiles_with_line | sort -u | sed 's/^/  - /' || true
    exit 0 ;;
  --profile)
    PROFILE="${2:-}"; [[ -n "$PROFILE" ]] || { echo "ERROR: --profile needs a value" >&2; exit 1; } ;;
  "" ) : ;;
  * ) echo "Unknown argument: $1" >&2; exit 1 ;;
esac

# --- choose profile --------------------------------------------------------
mapfile -t FOUND < <(profiles_with_line | sort -u)
if [[ ${#FOUND[@]} -eq 0 ]]; then
  echo "ERROR: the LINE extension ($EXTID) is not installed in any $CHROME_CONFIG profile." >&2
  echo "Install it first from the Chrome Web Store, then re-run this script." >&2
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  # prefer Default, else the first profile found
  if printf '%s\n' "${FOUND[@]}" | grep -qx "Default"; then
    PROFILE="Default"
  else
    PROFILE="${FOUND[0]}"
  fi
  if [[ ${#FOUND[@]} -gt 1 ]]; then
    echo "Note: LINE found in multiple profiles (${FOUND[*]}). Using \"$PROFILE\"."
    echo "      Re-run with --profile \"<name>\" to pick another."
  fi
elif ! printf '%s\n' "${FOUND[@]}" | grep -qx "$PROFILE"; then
  echo "ERROR: LINE is not installed in profile \"$PROFILE\". Found in: ${FOUND[*]}" >&2
  exit 1
fi

APPID="$(appid_for_profile "$PROFILE")"

# --- install icon ----------------------------------------------------------
mkdir -p "$ICONS_DIR" "$APPS_DIR"
ICON_DEST="$ICONS_DIR/line-app.png"
if [[ -f "$REPO_DIR/assets/line-app.png" ]]; then
  cp "$REPO_DIR/assets/line-app.png" "$ICON_DEST"
else
  # fall back to extracting the icon straight from the installed extension
  SRC_ICON="$(find "$CHROME_CONFIG/$PROFILE/Extensions/$EXTID" -name 'line_logo_128x128_on.png' 2>/dev/null | head -1)"
  [[ -n "$SRC_ICON" ]] || SRC_ICON="$(find "$CHROME_CONFIG/$PROFILE/Extensions/$EXTID" -name '*128*on.png' 2>/dev/null | head -1)"
  [[ -n "$SRC_ICON" ]] && cp "$SRC_ICON" "$ICON_DEST" || echo "WARN: could not find a LINE icon; launcher will use a generic icon." >&2
fi

# --- write the .desktop launcher ------------------------------------------
# The filename AND StartupWMClass must both equal the window's Wayland app_id
# so GNOME (native Wayland) associates the running window with this launcher.
DESKTOP_FILE="$APPS_DIR/$APPID.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=LINE
Comment=LINE (standalone app window)
Exec=$CHROME_BIN --profile-directory="$PROFILE" --app=chrome-extension://$EXTID/index.html
Icon=$ICON_DEST
Terminal=false
Categories=Network;InstantMessaging;
StartupWMClass=$APPID
EOF
chmod +x "$DESKTOP_FILE"

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$ICONS_DIR" >/dev/null 2>&1 || true

echo "Installed LINE standalone launcher:"
echo "  profile : $PROFILE"
echo "  app_id  : $APPID"
echo "  desktop : $DESKTOP_FILE"
echo "  icon    : $ICON_DEST"
echo
echo "Search \"LINE\" in your app menu and launch it. The window should show the"
echo "LINE icon in the dock. If you switch profiles later, re-run this script."
