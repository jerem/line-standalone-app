#!/usr/bin/env bash
#
# Remove what install-chromium.sh created. By default this keeps your profile +
# cached extension (so your LINE login survives a reinstall); pass --purge to
# delete those too.
#
# This only undoes the git-clone install. If you installed the RPM instead, use:
#   sudo dnf remove line-standalone-chromium
#
set -euo pipefail

EXTID="ophjlpahpchlmihnnnihgmmeilfjmjjc"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/line-chromium"
APPID="chrome-${EXTID}__index.html-Default"

# stop any running instance cleanly (flush the session cookie)
for pid in $(pgrep chromium 2>/dev/null); do
  grep -qa "line-chromium" "/proc/$pid/cmdline" 2>/dev/null && kill -TERM "$pid" 2>/dev/null || true
done

rm -vf "$APPS_DIR/$APPID.desktop"
rm -vf "$ICONS_DIR/hicolor/128x128/apps/line-standalone.png"
rm -vf "$ICONS_DIR/line-app.png"          # legacy icon from older installs
update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$ICONS_DIR/hicolor" >/dev/null 2>&1 || true

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$DATA"
  echo "Purged profile + cached extension ($DATA) — you'll log in again next time."
else
  echo "Kept profile + cached extension in $DATA."
  echo "Pass --purge to remove it too (this deletes your LINE login for this app)."
fi
echo "Done."
