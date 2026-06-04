#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_DIR="${1:-"$ROOT_DIR/web"}"
TMP_DIR="$ROOT_DIR/tmp/web-gdscript-project"
GODOT_BIN="${GODOT_BIN:-godot}"
CELLULAR_WEB_LOCAL_TEST="${CELLULAR_WEB_LOCAL_TEST:-0}"
CELLULAR_WEB_PWA="${CELLULAR_WEB_PWA:-1}"
GODOT_VERSION="$("$GODOT_BIN" --version 2>/dev/null || true)"
APP_NAME="$(python3 - "$ROOT_DIR/project.godot" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
match = re.search(r'^config/name="([^"]+)"', text, re.M)
print(match.group(1) if match else "Cellular")
PY
)"
APP_VERSION="$(python3 - "$ROOT_DIR/project.godot" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
match = re.search(r'^config/version="([^"]+)"', text, re.M)
print(match.group(1) if match else "0.0.0")
PY
)"
WEB_RELEASE_ID="${CELLULAR_WEB_RELEASE_ID:-$APP_VERSION-$(date -u +%Y%m%d%H%M%S)}"

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

if [[ "$CELLULAR_WEB_LOCAL_TEST" == "1" || "$CELLULAR_WEB_LOCAL_TEST" == "true" || "$CELLULAR_WEB_LOCAL_TEST" == "yes" || "$CELLULAR_WEB_LOCAL_TEST" == "on" ]]; then
  CELLULAR_WEB_PWA=0
fi

if [[ "$GODOT_VERSION" != 4.6.3* ]]; then
  echo "Warning: project is targeting Godot 4.6.3; exporting with $GODOT_BIN ($GODOT_VERSION)." >&2
fi

echo "Exporting Cellular Web in release mode with $GODOT_BIN ($GODOT_VERSION)."
echo "App version: $APP_VERSION"
echo "Web release id: $WEB_RELEASE_ID"
if [[ "$CELLULAR_WEB_PWA" == "1" || "$CELLULAR_WEB_PWA" == "true" || "$CELLULAR_WEB_PWA" == "yes" || "$CELLULAR_WEB_PWA" == "on" ]]; then
  echo "PWA/service-worker output: enabled"
else
  echo "PWA/service-worker output: disabled for local testing"
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

mkdir -p "$TMP_DIR/src"
cp "$ROOT_DIR/src/CellularBoardRendererGd.gd" "$TMP_DIR/src/CellularBoardRendererGd.gd"

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

python3 - "$TMP_DIR/project.godot" "$APP_VERSION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
app_version = sys.argv[2]
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
text = "\n".join(out) + "\n"

def ensure_project_settings(source, section, settings):
    lines = source.splitlines()
    header = f"[{section}]"
    section_start = None
    section_end = len(lines)
    for index, line in enumerate(lines):
        if line.strip() == header:
            section_start = index
            break
    if section_start is None:
        insertion = ["", header, ""]
        insertion.extend(f"{key}={value}" for key, value in settings.items())
        return source.rstrip() + "\n" + "\n".join(insertion) + "\n"
    for index in range(section_start + 1, len(lines)):
        if re.match(r"^\[[^\]]+\]$", lines[index].strip()):
            section_end = index
            break
    for key, value in settings.items():
        replacement = f"{key}={value}"
        replaced = False
        for index in range(section_start + 1, section_end):
            if lines[index].strip().startswith(f"{key}="):
                lines[index] = replacement
                replaced = True
                break
        if not replaced:
            lines.insert(section_end, replacement)
            section_end += 1
    return "\n".join(lines) + "\n"

text = ensure_project_settings(text, "audio", {
    'driver/driver': '"Dummy"',
    'driver/enable_input': 'false',
    'general/text_to_speech': 'false',
})
text = ensure_project_settings(text, "application", {
    'config/version': f'"{app_version}"',
})
path.write_text(text)
PY

python3 - "$TMP_DIR/scenes/title_screen.tscn" "$APP_VERSION" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
if not path.exists():
    raise SystemExit(0)

lines = path.read_text().splitlines()
in_version_label = False
insert_at = None
for index, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('[node '):
        in_version_label = 'name="VersionLabel"' in stripped
        insert_at = index + 1 if in_version_label else None
        continue
    if in_version_label and stripped.startswith('[connection '):
        if insert_at is not None:
            lines.insert(index, f'text = "v{version}"')
        break
    if in_version_label:
        if stripped.startswith('text = '):
            lines[index] = f'text = "v{version}"'
            insert_at = None
            break
        insert_at = index + 1
else:
    if in_version_label and insert_at is not None:
        lines.insert(insert_at, f'text = "v{version}"')

path.write_text("\n".join(lines) + "\n")
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

python3 - "$EXPORT_DIR" "$APP_NAME" "$APP_VERSION" "$WEB_RELEASE_ID" <<'PY'
from pathlib import Path
import html
import json
import re
import sys

export_dir = Path(sys.argv[1])
app_name = sys.argv[2]
app_version = sys.argv[3]
release_id = sys.argv[4]

version_payload = {
    "name": app_name,
    "version": app_version,
    "release": release_id,
}
(export_dir / "version.json").write_text(json.dumps(version_payload, indent=2) + "\n")
(export_dir / "version.txt").write_text(f"{app_name} {app_version} ({release_id})\n")

index_path = export_dir / "index.html"
if index_path.exists():
    text = index_path.read_text()
    meta = (
        f'\t\t<meta name="cellular-version" content="{html.escape(app_version, quote=True)}">\n'
        f'\t\t<meta name="cellular-release" content="{html.escape(release_id, quote=True)}">'
    )
    text = re.sub(r'\s*<meta name="cellular-version" content="[^"]*">\s*', "\n", text)
    text = re.sub(r'\s*<meta name="cellular-release" content="[^"]*">\s*', "\n", text)
    text = text.replace("</head>", meta + "\n\t</head>")
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
    index_path.write_text(text)

manifest_path = export_dir / "index.manifest.json"
if manifest_path.exists():
    data = json.loads(manifest_path.read_text())
    data["id"] = "./"
    data["name"] = app_name
    data["short_name"] = app_name
    data["description"] = "A deterministic cellular puzzle and arcade game."
    data["start_url"] = f"./index.html?v={release_id}"
    data["scope"] = "./"
    data["display"] = "standalone"
    data["theme_color"] = "#000000"
    data["background_color"] = "#000000"
    data["cellular_version"] = app_version
    data["cellular_release"] = release_id
    manifest_path.write_text(json.dumps(data, separators=(",", ":")) + "\n")

worker_path = export_dir / "index.service.worker.js"
if worker_path.exists():
    text = worker_path.read_text()
    text = re.sub(
        r"const CACHE_VERSION = '[^']*';",
        f"const CACHE_VERSION = 'cellular-{release_id}';",
        text,
        count=1,
    )
    lines = text.splitlines()
    replaced = False
    for start, line in enumerate(lines):
        if line.strip() != "if (isNavigate) {":
            continue
        if start + 1 >= len(lines) or "full cache" not in lines[start + 1]:
            continue
        depth = 0
        end = start
        for end in range(start, len(lines)):
            depth += lines[end].count("{")
            depth -= lines[end].count("}")
            if depth == 0:
                break
        replacement = [
            "\t\t\t\tif (isNavigate) {",
            "\t\t\t\t\ttry {",
            "\t\t\t\t\t\treturn await fetchAndCache(event, cache, true);",
            "\t\t\t\t\t} catch (e) {",
            "\t\t\t\t\t\tconsole.error('Network error: ', e); // eslint-disable-line no-console",
            "\t\t\t\t\t\tlet cached = await cache.match(event.request);",
            "\t\t\t\t\t\tif (cached == null) {",
            "\t\t\t\t\t\t\tcached = await cache.match(CACHED_FILES[0]);",
            "\t\t\t\t\t\t}",
            "\t\t\t\t\t\tif (cached != null) {",
            "\t\t\t\t\t\t\tif (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {",
            "\t\t\t\t\t\t\t\tcached = ensureCrossOriginIsolationHeaders(cached);",
            "\t\t\t\t\t\t\t}",
            "\t\t\t\t\t\t\treturn cached;",
            "\t\t\t\t\t\t}",
            "\t\t\t\t\t\treturn caches.match(OFFLINE_URL);",
            "\t\t\t\t\t}",
            "\t\t\t\t}",
        ]
        lines = lines[:start] + replacement + lines[end + 1:]
        replaced = True
        break
    if replaced:
        text = "\n".join(lines) + "\n"
    worker_path.write_text(text)
PY

if [[ "$CELLULAR_WEB_PWA" == "1" || "$CELLULAR_WEB_PWA" == "true" || "$CELLULAR_WEB_PWA" == "yes" || "$CELLULAR_WEB_PWA" == "on" ]]; then
  python3 - "$EXPORT_DIR" <<'PY'
from pathlib import Path
import json
import re
import sys

export_dir = Path(sys.argv[1])
required_files = [
    "index.html",
    "index.js",
    "index.wasm",
    "index.pck",
    "index.manifest.json",
    "index.service.worker.js",
    "index.offline.html",
    "index.144x144.png",
    "index.180x180.png",
    "index.512x512.png",
]
missing = [name for name in required_files if not (export_dir / name).exists()]
if missing:
    raise SystemExit("PWA export is missing required files: " + ", ".join(missing))

index_text = (export_dir / "index.html").read_text()
if 'rel="manifest"' not in index_text:
    raise SystemExit("PWA export is missing the manifest link in index.html")
if '"serviceWorker":"index.service.worker.js"' not in index_text:
    raise SystemExit("PWA export is missing the Godot service worker config in index.html")
if 'cellular-version' not in index_text or 'cellular-release' not in index_text:
    raise SystemExit("PWA export is missing Cellular release metadata in index.html")

manifest = json.loads((export_dir / "index.manifest.json").read_text())
for key in ("id", "name", "short_name", "start_url", "scope", "display", "icons"):
    if key not in manifest:
        raise SystemExit(f"PWA manifest is missing required key: {key}")
if manifest.get("display") != "standalone":
    raise SystemExit("PWA manifest display must be standalone")
icon_sizes = {str(icon.get("sizes", "")) for icon in manifest.get("icons", []) if isinstance(icon, dict)}
for size in ("144x144", "180x180", "512x512"):
    if size not in icon_sizes:
        raise SystemExit(f"PWA manifest is missing required icon size: {size}")

worker_text = (export_dir / "index.service.worker.js").read_text()
if "cellular-" not in worker_text:
    raise SystemExit("PWA service worker cache version was not stamped with the Cellular release id")
if not re.search(r"if \(isNavigate\) \{\s+try \{\s+return await fetchAndCache", worker_text):
    raise SystemExit("PWA service worker navigation should be network-first for fresh releases")
PY
fi

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

For local browser testing without PWA/service-worker output, rerun with:
  CELLULAR_WEB_LOCAL_TEST=1 bash scripts/export_web_gdscript.sh
EOF
fi
