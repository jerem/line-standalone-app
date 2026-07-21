#!/usr/bin/env bash
# Build the line-standalone-chromium RPM into ./dist/ (no root needed).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
TREE="$(mktemp -d)"
trap 'rm -rf "$TREE"' EXIT

mkdir -p "$TREE"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
cp "$REPO/experimental/line-chromium.sh"          "$TREE/SOURCES/line-chromium.sh"
cp "$HERE/line-standalone-chromium.desktop"       "$TREE/SOURCES/"
cp "$HERE/line-standalone-chromium.spec"          "$TREE/SPECS/"

rpmbuild -bb --define "_topdir $TREE" "$TREE/SPECS/line-standalone-chromium.spec"

mkdir -p "$HERE/dist"
find "$TREE/RPMS" -name '*.rpm' -exec cp -v {} "$HERE/dist/" \;
echo
echo "RPM built in: $HERE/dist/"
echo "Install with: sudo dnf install $HERE/dist/*.rpm"
