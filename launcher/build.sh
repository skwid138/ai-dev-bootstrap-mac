#!/usr/bin/env bash
#
# Assembles a "Vibe Code.app" macOS app bundle from the source files in this
# directory. Bundle layout:
#
#   Vibe Code.app/
#     Contents/
#       Info.plist           (from launcher/Info.plist)
#       MacOS/
#         launch             (from launcher/launch.sh, executable)
#       Resources/
#         VibeCode.icns      (from launcher/icon/VibeCode.icns)
#
# Usage:  launcher/build.sh <output-dir>
#
# The output dir will contain "Vibe Code.app". Any pre-existing bundle of that
# name is replaced atomically.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <output-dir>" >&2
  exit 64
fi

dest_dir="$1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LAUNCH_SH="$HERE/launch.sh"
INFO_PLIST="$HERE/Info.plist"
ICNS="$HERE/icon/VibeCode.icns"

for f in "$LAUNCH_SH" "$INFO_PLIST" "$ICNS"; do
  if [[ ! -f "$f" ]]; then
    echo "error: missing required file: $f" >&2
    exit 1
  fi
done

mkdir -p "$dest_dir"

# Build into a staging dir, then atomically swap into place. Avoids leaving a
# half-built bundle if anything fails mid-build.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

bundle="$staging/Vibe Code.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"

cp "$INFO_PLIST" "$bundle/Contents/Info.plist"
cp "$ICNS" "$bundle/Contents/Resources/VibeCode.icns"

# Bundle executable: copy launch.sh, name it "launch" (matches CFBundleExecutable).
cp "$LAUNCH_SH" "$bundle/Contents/MacOS/launch"
chmod 755 "$bundle/Contents/MacOS/launch"

# Atomic-ish swap. macOS doesn't have rename-replace for directories, so we
# delete + move; the window is small and the alternative (in-place edit) risks
# leaving stale files behind.
final="$dest_dir/Vibe Code.app"
if [[ -d "$final" ]]; then
  rm -rf "$final"
fi
mv "$bundle" "$final"

# Touch the bundle so Finder/Launch Services notices the new mtime and refreshes
# the icon cache. Without this, replacing an existing bundle can show the old
# icon until cache invalidation.
touch "$final"

echo "built $final"
