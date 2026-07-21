#!/usr/bin/env bash
#
# Install a menu launcher (.desktop) for the Chromium-based standalone LINE app.
# Fetches the extension (via line-chromium.sh), extracts the icon, and writes a
# GNOME/Wayland-correct .desktop whose filename + StartupWMClass match the window
# app_id so the dock shows the LINE icon.
#
set -euo pipefail

EXTID="ophjlpahpchlmihnnnihgmmeilfjmjjc"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$REPO_DIR/line-chromium.sh"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/line-chromium"
EXT_DIR="$DATA/extension"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"

# the isolated profile dir is always "Default", so the window app_id is fixed:
APPID="chrome-${EXTID}__index.html-Default"

[[ -x "$LAUNCHER" ]] || chmod +x "$LAUNCHER"

# fetch + unpack the extension now (so the icon exists and first launch is fast)
if [[ ! -f "$EXT_DIR/manifest.json" ]]; then
  echo "Fetching the LINE extension (one-time) ..."
  "$LAUNCHER" --fetch-only
fi

mkdir -p "$ICONS_DIR" "$APPS_DIR"
ICON_DEST="$ICONS_DIR/line-app.png"
SRC_ICON="$(find "$EXT_DIR" -name 'line_logo_128x128_on.png' 2>/dev/null | head -1)"
[[ -n "$SRC_ICON" ]] || SRC_ICON="$(find "$EXT_DIR" -name '*128*on.png' 2>/dev/null | head -1)"
if [[ -n "$SRC_ICON" ]]; then cp "$SRC_ICON" "$ICON_DEST"
else echo "WARN: LINE icon not found; launcher will use a generic icon." >&2; fi

DESKTOP_FILE="$APPS_DIR/$APPID.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=LINE (Chromium)
Comment=Standalone LINE via Chromium (side-loaded extension)
Exec=$LAUNCHER
Icon=$ICON_DEST
Terminal=false
StartupNotify=true
Categories=Network;InstantMessaging;
StartupWMClass=$APPID
EOF
chmod +x "$DESKTOP_FILE"

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$ICONS_DIR" >/dev/null 2>&1 || true

echo "Installed:"
echo "  launcher : $LAUNCHER"
echo "  desktop  : $DESKTOP_FILE"
echo "  app_id   : $APPID"
echo "  icon     : $ICON_DEST"
echo
echo "Search \"LINE (Chromium)\" in your app menu. First launch = QR login."
