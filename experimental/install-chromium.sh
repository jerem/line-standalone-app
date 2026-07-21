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
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

# the isolated profile dir is always "Default", so the window app_id is fixed:
APPID="chrome-${EXTID}__index.html-Default"

# NOTE: this git-clone install and the RPM package are MUTUALLY EXCLUSIVE — both
# write the same app_id .desktop entry, and a user-level entry shadows the system
# (RPM) one. Use one method only. If you installed the RPM, remove it first with
# `sudo dnf remove line-standalone-chromium`.

[[ -x "$LAUNCHER" ]] || chmod +x "$LAUNCHER"

# Provision the extension (cached) AND extract the themed "line-standalone" icon —
# the launcher does both. Cheap if already cached.
echo "Provisioning the LINE extension + icon (one-time) ..."
"$LAUNCHER" --fetch-only

mkdir -p "$APPS_DIR"
DESKTOP_FILE="$APPS_DIR/$APPID.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=LINE (Chromium)
Comment=Standalone LINE via Chromium (side-loaded extension)
Exec=$LAUNCHER
Icon=line-standalone
Terminal=false
StartupNotify=true
Categories=Network;InstantMessaging;
StartupWMClass=$APPID
EOF
chmod +x "$DESKTOP_FILE"

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

echo "Installed:"
echo "  launcher : $LAUNCHER"
echo "  desktop  : $DESKTOP_FILE"
echo "  app_id   : $APPID"
echo
echo "Search \"LINE (Chromium)\" in your app menu. First launch = QR login."
echo "Uninstall with ./uninstall-chromium.sh"
