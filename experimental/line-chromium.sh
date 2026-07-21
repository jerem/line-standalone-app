#!/usr/bin/env bash
#
# Standalone LINE via Chromium, WITHOUT installing the extension from the Web Store.
#
# Google Chrome (branded) refuses --load-extension ("not allowed in Google Chrome,
# ignoring"), so this REQUIRES a Chromium-family browser that still honors it.
#
# It downloads the official LINE extension .crx, unpacks it, injects the developer
# public key (so it keeps its canonical id), and launches it in a dedicated Chromium
# profile as a standalone --app window.
#
# Because --load-extension re-registers the extension on every launch, opening the
# app window immediately RACES the extension's service worker (=> ERR_BLOCKED_BY_CLIENT).
# We avoid that with a two-phase launch: warm up the extension first, wait until its
# service worker is registered, then open the app window.
#
# Notes:
#   * isolated profile -> separate LINE login (QR scan); that's expected here
#   * push notifications may be unreliable (side-loaded copy lacks valid GCM creds)
#
set -euo pipefail

EXTID="ophjlpahpchlmihnnnihgmmeilfjmjjc"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/line-chromium"
EXT_DIR="$DATA/extension"
PROFILE_DIR="$DATA/profile"
CRX="$DATA/line.crx"

# --- require a Chromium-family binary that allows --load-extension ---------
CHROME_BIN="${CHROME_BIN:-}"
if [[ -z "$CHROME_BIN" ]]; then
  for c in chromium chromium-browser brave-browser microsoft-edge vivaldi-stable; do
    command -v "$c" >/dev/null 2>&1 && { CHROME_BIN="$(command -v "$c")"; break; }
  done
fi
if [[ -z "$CHROME_BIN" ]]; then
  echo "ERROR: no Chromium-family browser found. Google Chrome will NOT work here" >&2
  echo "       (it blocks --load-extension). Install 'chromium' or set CHROME_BIN=." >&2
  exit 1
fi
case "$CHROME_BIN" in
  *google-chrome*) echo "ERROR: Google Chrome blocks --load-extension. Use Chromium (set CHROME_BIN=)." >&2; exit 1 ;;
esac

mkdir -p "$DATA" "$PROFILE_DIR"

fetch_and_unpack() {
  local ver url
  ver="$("$CHROME_BIN" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"; ver="${ver:-120.0.0.0}"
  url="https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${ver}&x=id%3D${EXTID}%26installsource%3Dondemand%26uc"
  echo "Fetching LINE extension (.crx) ..."
  curl -fsSL -o "$CRX" "$url"; [[ -s "$CRX" ]] || { echo "ERROR: download failed." >&2; exit 1; }
  echo "Unpacking + injecting developer key ..."
  rm -rf "$EXT_DIR"; mkdir -p "$EXT_DIR"
  python3 - "$CRX" "$EXT_DIR" "$EXTID" <<'PY'
import sys, struct, zipfile, io, hashlib, base64, json, os
crx, out, target = sys.argv[1], sys.argv[2], sys.argv[3]
d = open(crx, 'rb').read(); assert d[:4] == b'Cr24', "not a CRX"
hlen = struct.unpack('<I', d[8:12])[0]; header = d[12:12+hlen]
zipfile.ZipFile(io.BytesIO(d[12+hlen:])).extractall(out)
def rv(b, i):
    r = s = 0
    while True:
        x = b[i]; i += 1; r |= (x & 0x7f) << s
        if not x & 0x80: return r, i
        s += 7
def fields(b):
    i = 0
    while i < len(b):
        k, i = rv(b, i); fn, wt = k >> 3, k & 7
        if wt == 2: ln, i = rv(b, i); yield fn, b[i:i+ln]; i += ln
        elif wt == 0: _, i = rv(b, i)
        else: break
def eid(pub):
    h = hashlib.sha256(pub).digest()
    return ''.join(chr(ord('a')+((h[i//2]>>(4 if i%2==0 else 0))&0xf)) for i in range(32))
dev = None
for fn, val in fields(header):
    if fn == 2:
        for sfn, sval in fields(val):
            if sfn == 1 and eid(sval) == target: dev = sval
if dev is None: sys.exit("ERROR: no developer key matching id %s" % target)
mp = os.path.join(out, 'manifest.json'); m = json.load(open(mp))
m['key'] = base64.b64encode(dev).decode(); json.dump(m, open(mp, 'w'))
print("  ready (%s)" % target)
PY
}

if [[ "${1:-}" == "--refresh" || ! -f "$EXT_DIR/manifest.json" ]]; then
  fetch_and_unpack
else
  echo "Using cached extension (pass --refresh to re-download)."
fi

# provision only (used by install-chromium.sh); don't launch
[[ "${1:-}" == "--fetch-only" ]] && { echo "Fetch complete."; exit 0; }

# --- launch the standalone app window --------------------------------------
# Opening the extension page races the extension's registration, so the window
# first shows ERR_BLOCKED_BY_CLIENT. We drive a reload-until-loaded loop over a
# localhost-only DevTools port (ephemeral; Chromium picks it) so the visible
# window deterministically ends up on LINE, regardless of machine speed.
echo "Launching LINE (Chromium) ..."
rm -f "$PROFILE_DIR/DevToolsActivePort"
"$CHROME_BIN" --user-data-dir="$PROFILE_DIR" --no-first-run --no-default-browser-check \
  --remote-debugging-port=0 \
  --load-extension="$EXT_DIR" \
  --app="chrome-extension://$EXTID/index.html" >/dev/null 2>&1 &
APP_PID=$!

# wait for Chromium to publish its chosen DevTools port
PORT=""
for _ in $(seq 1 40); do
  [[ -f "$PROFILE_DIR/DevToolsActivePort" ]] && { PORT="$(head -1 "$PROFILE_DIR/DevToolsActivePort")"; break; }
  sleep 0.25
done

if [[ -n "$PORT" ]]; then
  python3 - "$PORT" "$EXTID" <<'PY' || true
import socket,base64,os,struct,json,sys,time,urllib.request
port,extid=sys.argv[1],sys.argv[2]
def targets():
    try: return json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json",timeout=3))
    except Exception: return []
# find the LINE app page target
tid=None
for _ in range(40):
    for t in targets():
        if t.get("type")=="page" and extid in t.get("url",""): tid=t["id"]; break
    if tid: break
    time.sleep(0.25)
if not tid: sys.exit(0)
s=socket.create_connection(("127.0.0.1",int(port)),timeout=6)
k=base64.b64encode(os.urandom(16)).decode()
s.sendall((f"GET /devtools/page/{tid} HTTP/1.1\r\nHost:127.0.0.1:{port}\r\nUpgrade:websocket\r\nConnection:Upgrade\r\nSec-WebSocket-Key:{k}\r\nSec-WebSocket-Version:13\r\n\r\n").encode())
b=b""
while b"\r\n\r\n" not in b: b+=s.recv(4096)
mid=[0]
def snd(method,params=None):
    mid[0]+=1
    p=json.dumps({"id":mid[0],"method":method,"params":params or {}}).encode()
    h=bytearray([0x81]);l=len(p);m=os.urandom(4)
    (h.append(0x80|l) if l<126 else (h.append(0x80|126),h.extend(struct.pack(">H",l))));h+=m
    s.sendall(bytes(h)+bytes(x^m[i%4] for i,x in enumerate(p)));return mid[0]
def rcv():
    s.recv(1);l=s.recv(1)[0]&0x7f
    if l==126:l=struct.unpack(">H",s.recv(2))[0]
    elif l==127:l=struct.unpack(">Q",s.recv(8))[0]
    d=b""
    while len(d)<l:d+=s.recv(l-len(d))
    return json.loads(d)
def loaded():
    i=snd("Runtime.evaluate",{"expression":"((document.querySelector('#root')||{}).childElementCount||0)>0 && !/blocked/i.test(document.body?document.body.innerText:'')","returnByValue":True})
    for _ in range(20):
        m=rcv()
        if m.get("id")==i: return bool(m.get("result",{}).get("result",{}).get("value"))
    return False
s.settimeout(6)
snd("Page.enable")
for _ in range(20):                       # ~20 tries, reloading until it renders
    if loaded(): break
    snd("Page.reload",{"ignoreCache":True})
    time.sleep(1)
s.close()
PY
fi

# keep the profile alive; when the window closes, Chromium exits on its own
wait "$APP_PID" 2>/dev/null || true
