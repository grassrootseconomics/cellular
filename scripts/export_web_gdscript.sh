#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_DIR="${1:-"$ROOT_DIR/web"}"
TMP_DIR="$ROOT_DIR/tmp/web-gdscript-project"
GODOT_BIN="${GODOT_BIN:-godot}"
CELLULAR_WEB_PWA="${CELLULAR_WEB_PWA:-0}"
GODOT_VERSION="$("$GODOT_BIN" --version 2>/dev/null || true)"

if [[ "$GODOT_VERSION" == *".mono."* || "$GODOT_VERSION" == *"mono"* ]]; then
  if command -v godot4 >/dev/null 2>&1; then
    GODOT4_VERSION="$(godot4 --version 2>/dev/null || true)"
    if [[ "$GODOT4_VERSION" != *".mono."* && "$GODOT4_VERSION" != *"mono"* && "$GODOT4_VERSION" != "" ]]; then
      GODOT_BIN="godot4"
      GODOT_VERSION="$GODOT4_VERSION"
      echo "Using non-.NET Godot binary: $GODOT_BIN ($GODOT_VERSION)"
    fi
  fi
fi

if [[ "$GODOT_VERSION" == *".mono."* || "$GODOT_VERSION" == *"mono"* ]]; then
  cat >&2 <<'EOF'
GDScript-only Web export requires the standard non-.NET Godot editor binary.
The current GODOT_BIN points to a Mono/.NET Godot build, which cannot export Web in Godot 4.

Install/download the standard Godot 4.6.3 editor and rerun, for example:
  GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64 bash scripts/export_web_gdscript.sh
EOF
  exit 1
fi

if [[ "$GODOT_VERSION" != 4.6.3* ]]; then
  echo "Warning: project is targeting Godot 4.6.3; exporting with $GODOT_BIN ($GODOT_VERSION)." >&2
fi

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR" "$EXPORT_DIR"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='.godot/' \
  --exclude='android/build/' \
  --exclude='android/.gradle/' \
  --exclude='build/' \
  --exclude='tmp/' \
  --exclude='web/' \
  --exclude='src/' \
  --exclude='sim/' \
  --exclude='Cellular.csproj' \
  --exclude='Cellular.sln' \
  --exclude='**/*.cs' \
  "$ROOT_DIR/" "$TMP_DIR/"

mkdir -p "$TMP_DIR/web"
for icon in \
  index.144x144.png \
  index.180x180.png \
  index.512x512.png \
  index.apple-touch-icon.png \
  index.icon.png; do
  if [[ -f "$ROOT_DIR/web/$icon" ]]; then
    cp "$ROOT_DIR/web/$icon" "$TMP_DIR/web/$icon"
  fi
done

python3 - "$TMP_DIR/project.godot" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(', "C#"', '').replace('"C#", ', '').replace('"C#"', '')

lines = text.splitlines()
out = []
skip = False
for line in lines:
    if line.strip() == "[dotnet]":
        skip = True
        continue
    if skip and re.match(r"^\[[^\]]+\]$", line.strip()):
        skip = False
    if not skip:
        out.append(line)
path.write_text("\n".join(out) + "\n")
PY

python3 - "$TMP_DIR/export_presets.cfg" "$CELLULAR_WEB_PWA" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
pwa = sys.argv[2].strip().lower() in {"1", "true", "yes", "on"}
text = path.read_text()
if not pwa:
    text = text.replace("progressive_web_app/enabled=true", "progressive_web_app/enabled=false")
    text = text.replace(
        "progressive_web_app/ensure_cross_origin_isolation_headers=true",
        "progressive_web_app/ensure_cross_origin_isolation_headers=false",
    )
path.write_text(text)
PY

rm -f \
  "$EXPORT_DIR/index.html" \
  "$EXPORT_DIR/index.js" \
  "$EXPORT_DIR/index.wasm" \
  "$EXPORT_DIR/index.pck" \
  "$EXPORT_DIR/index.audio.worklet.js" \
  "$EXPORT_DIR/index.audio.position.worklet.js" \
  "$EXPORT_DIR/index.service.worker.js" \
  "$EXPORT_DIR/index.offline.html" \
  "$EXPORT_DIR/index.manifest.json" \
  "$EXPORT_DIR/index.png"

"$GODOT_BIN" --headless --path "$TMP_DIR" --export-release "Web" "$EXPORT_DIR/index.html"

if [[ "$CELLULAR_WEB_PWA" != "1" && "$CELLULAR_WEB_PWA" != "true" && "$CELLULAR_WEB_PWA" != "yes" && "$CELLULAR_WEB_PWA" != "on" && -f "$EXPORT_DIR/index.html" ]]; then
  python3 - "$EXPORT_DIR/index.html" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
hook = """<script>
if (location.search.indexOf('cellular-clear-service-worker=1') !== -1 && 'serviceWorker' in navigator) {
	navigator.serviceWorker.getRegistrations().then((registrations) => {
		return Promise.all(registrations.map((registration) => registration.unregister()));
	}).then(() => {
		if ('caches' in window) {
			return caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key))));
		}
	}).then(() => {
		location.replace(location.pathname);
	});
}
</script>
"""
if "cellular-clear-service-worker=1" not in text:
    text = text.replace("</head>", hook + "\n\t</head>")
path.write_text(text)
PY
fi

if [[ -f "$ROOT_DIR/CNAME" ]]; then
  cp "$ROOT_DIR/CNAME" "$EXPORT_DIR/CNAME"
fi

if [[ -f "$ROOT_DIR/web/clear.html" ]]; then
  python3 - "$ROOT_DIR/web/clear.html" "$EXPORT_DIR/clear.html" <<'PY'
from pathlib import Path
import shutil
import sys

source = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
if source != target:
    shutil.copyfile(source, target)
PY
fi

echo "Exported GDScript-only web build to $EXPORT_DIR"
if [[ "$CELLULAR_WEB_PWA" != "1" && "$CELLULAR_WEB_PWA" != "true" && "$CELLULAR_WEB_PWA" != "yes" && "$CELLULAR_WEB_PWA" != "on" ]]; then
  cat <<EOF
Local PWA/service-worker output is disabled for easier browser testing.
If this origin previously showed the offline page, clear the old browser service worker once:
  http://127.0.0.1:8060/?cellular-clear-service-worker=1

For release PWA output, rerun with:
  CELLULAR_WEB_PWA=1 bash scripts/export_web_gdscript.sh
EOF
fi
