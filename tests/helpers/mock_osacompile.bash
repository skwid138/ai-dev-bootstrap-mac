#!/usr/bin/env bash
# Shared mock for osacompile — creates minimal .app bundle structure
# so launcher/build.sh can complete without the real AppleScript compiler.

create_osacompile_mock() {
  local mocks_dir="${1:?usage: create_osacompile_mock <mocks_dir>}"
  cat >"$mocks_dir/osacompile" <<'MOCK'
#!/bin/bash
# Mock osacompile: parse args, create minimal applet bundle.
# Real invocation: osacompile -s -o <bundle> <source>
bundle=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) bundle="$2"; shift 2 ;;
    -*) shift ;;           # consume flags like -s
    *)  shift ;;           # consume positional args (source file)
  esac
done
[[ -n "$bundle" ]] || exit 1
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/Scripts"
printf '#!/bin/bash\nexit 0\n' >"$bundle/Contents/MacOS/applet"
chmod 755 "$bundle/Contents/MacOS/applet"
touch "$bundle/Contents/Resources/Scripts/main.scpt"
# Default-icon artifacts so build.sh's cleanup assertions remain meaningful
touch "$bundle/Contents/Resources/applet.icns"
touch "$bundle/Contents/Resources/Assets.car"
# PkgInfo
printf 'APPL????' >"$bundle/Contents/PkgInfo"
# Minimal Info.plist (build.sh overwrites before plutil -lint)
cat >"$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict></dict></plist>
PLIST
exit 0
MOCK
  chmod +x "$mocks_dir/osacompile"
}
