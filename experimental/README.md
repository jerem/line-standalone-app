# Experimental: standalone LINE via Chromium (no Web Store install)

This variant runs LINE as a standalone app **without installing the extension from
the Chrome Web Store** — it fetches the extension itself. It exists because of a
hard constraint we discovered the hard way (see below).

## TL;DR findings

- **Google Chrome (branded) refuses to side-load extensions.** Launching with
  `--load-extension` logs `--load-extension is not allowed in Google Chrome,
  ignoring.` (`extension_service.cc`). The extension never registers, so its page
  fails with `ERR_BLOCKED_BY_CLIENT`. **No CLI flag bypasses this** — we tested
  `--disable-features=ExtensionDisableUnsupportedDeveloper`,
  `--disable-features=DisableLoadExtensionCommandLineSwitch`,
  `--disable-extensions-except`, and enabling Developer Mode in the profile. All
  ignored, because the flag is dropped before any of them apply.
- **Chromium still honors `--load-extension`.** So this approach requires a
  Chromium-family browser (plain `chromium`, Brave, Edge, Vivaldi…), *not* Google
  Chrome. Verified on Chromium 150.
- Even on Chromium, opening the app window **races** the extension's registration,
  so the first paint is `ERR_BLOCKED_BY_CLIENT`. The launcher works around this by
  reloading the window until the LINE app actually renders (see below).

## How it works

`line-chromium.sh`:
1. Downloads the official LINE `.crx` from Google's update service.
2. Unpacks it and **injects the developer public key** (extracted from the CRX
   signature block, the proof whose key hashes to the canonical id) into
   `manifest.json`, so the unpacked copy keeps its real id
   `ophjlpahpchlmihnnnihgmmeilfjmjjc` — otherwise it'd get a random path-derived id
   and `chrome-extension://…/index.html` wouldn't resolve.
3. Launches Chromium with a dedicated profile, `--load-extension`, and
   `--app=chrome-extension://<id>/index.html`, plus `--remote-debugging-port=0`.
4. Over that (localhost-only, ephemeral) DevTools port, drives `Page.reload` until
   `#root` is populated — deterministic regardless of machine speed.

`install-chromium.sh` fetches once, extracts the icon, and writes a
GNOME/Wayland-correct `.desktop` (`chrome-<id>__index.html-Default.desktop`, with a
matching `StartupWMClass`) so the dock shows the LINE icon.

## Usage

```bash
./install-chromium.sh          # one-time: creates the "LINE (Chromium)" menu entry
./line-chromium.sh             # or launch directly
./line-chromium.sh --refresh   # re-download the extension (no auto-update otherwise)
```

Override the browser with `CHROME_BIN=/path/to/chromium ./line-chromium.sh`.

## Trade-offs vs. the installed-extension approach (repo root)

| | Installed (root repo, Chrome) | This (Chromium, fetched) |
|---|---|---|
| Manual Web Store install | required | **not needed** |
| Browser | Google Chrome | Chromium only |
| Login | shares your Chrome profile | isolated profile → separate QR login |
| Push notifications | work | unreliable (side-loaded copy lacks GCM creds) |
| Auto-update | yes (store) | no — re-run `--refresh` |
| DevTools port | none | localhost-only ephemeral port stays open for the browser's lifetime |

The installed-extension approach in the repo root remains the recommended path on
Google Chrome. This is the answer to "provision without a Web Store install," which
is only possible on Chromium.
