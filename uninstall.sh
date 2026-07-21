#!/usr/bin/env bash
#
# Remove the standalone LINE launcher installed by ./install.sh
#
set -euo pipefail

EXTID="ophjlpahpchlmihnnnihgmmeilfjmjjc"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"

removed=0
# any launcher this repo may have produced (all profiles)
for f in "$APPS_DIR"/chrome-"$EXTID"__index.html-*.desktop; do
  [[ -e "$f" ]] || continue
  rm -v "$f"; removed=1
done

if [[ -f "$ICONS_DIR/line-app.png" ]]; then
  rm -v "$ICONS_DIR/line-app.png"; removed=1
fi

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$ICONS_DIR" >/dev/null 2>&1 || true

[[ "$removed" -eq 1 ]] && echo "Removed." || echo "Nothing to remove."
