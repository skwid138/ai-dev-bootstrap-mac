#!/usr/bin/env bash
#
# Re-renders launcher/icon/justvibes.svg into launcher/icon/JustVibes.icns.
#
# Run this whenever the SVG changes; commit both the SVG and the resulting
# .icns. Users running bootstrap.sh do NOT execute this script — they get the
# pre-built .icns directly.
#
# Tools used: qlmanage (Quick Look), sips, iconutil. All built into macOS.
# No homebrew/network/extra installs required.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG="$HERE/icon/justvibes.svg"
ICONSET_DIR="$HERE/icon/JustVibes.iconset"
ICNS_OUT="$HERE/icon/JustVibes.icns"

if [[ ! -f "$SVG" ]]; then
  echo "error: $SVG not found" >&2
  exit 1
fi

# 1. Render SVG to a single 1024x1024 master PNG via Quick Look.
master_png="$(mktemp -d)/master.png"
qlmanage -t -s 1024 -o "$(dirname "$master_png")" "$SVG" >/dev/null 2>&1
mv "$(dirname "$master_png")/$(basename "$SVG").png" "$master_png"

# 2. Generate the .iconset directory (Apple's required size matrix).
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# size:filename pairs per https://developer.apple.com/design/human-interface-guidelines/app-icons
declare -a sizes=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)

for entry in "${sizes[@]}"; do
  size="${entry%%:*}"
  name="${entry##*:}"
  sips -z "$size" "$size" "$master_png" --out "$ICONSET_DIR/$name" >/dev/null
done

# 3. Assemble the .icns.
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"

# 4. Clean up the iconset (only the .icns is committed).
rm -rf "$ICONSET_DIR"

echo "wrote $ICNS_OUT"
