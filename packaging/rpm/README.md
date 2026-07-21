# RPM package (Fedora)

Builds `line-standalone-chromium` — the Chromium-based standalone LINE app
(see `../../experimental/`) as an installable RPM with a `chromium` dependency.

The package ships **only** the launcher (`/usr/bin/line-chromium`) and the desktop
entry. It does **not** bundle LINE's extension or logo — the launcher fetches the
extension from Google on first run and extracts the icon per-user. So the RPM
itself carries no third-party code.

## Build

```bash
./build-rpm.sh          # -> dist/line-standalone-chromium-*.noarch.rpm  (no root needed)
```

## Install

```bash
sudo dnf install ./dist/line-standalone-chromium-*.noarch.rpm
```

`dnf` pulls in `chromium` automatically. Then launch **"LINE (Chromium)"** from
your app menu (first launch fetches the extension and shows the QR login).

## Uninstall

```bash
sudo dnf remove line-standalone-chromium
```

Per-user runtime data (`~/.local/share/line-chromium/`, the extracted icon) is not
removed by the package — delete it manually if you want a clean slate.

## Contents

- `line-standalone-chromium.spec` — the RPM spec (noarch; `Requires: chromium,
  python3, curl`).
- `line-standalone-chromium.desktop` — installed as
  `chrome-<extid>__index.html-Default.desktop` so GNOME/Wayland matches the window
  to the launcher (icon grouping).
- `build-rpm.sh` — builds into `dist/` using a throwaway rpmbuild tree.
