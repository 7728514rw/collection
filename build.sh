#!/bin/bash
# Builds "Game Collection.app" and "Music Collection.app" (same sources, -D MUSIC picks the second)
# into ./build. Pass --install to also copy them to /Applications; --launch to open them too.
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build; mkdir -p build

build() {  # name exec icon flags...
  local NAME="$1" EXEC="$2" ICON="$3"; shift 3
  local OUT="build/$NAME.app"
  mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
  echo "compiling $NAME..."
  swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 "$@" \
    -o "$OUT/Contents/MacOS/$EXEC" Sources/*.swift
  cp "Apps/$EXEC.plist" "$OUT/Contents/Info.plist"
  swift Tools/make-icon.swift "$ICON" "build/$ICON-1024.png"
  rm -rf build/AppIcon.iconset; mkdir -p build/AppIcon.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s "build/$ICON-1024.png" --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "build/$ICON-1024.png" --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o "$OUT/Contents/Resources/AppIcon.icns"
  codesign --force --deep -s - "$OUT" 2>/dev/null
  echo "built $OUT"
  if [[ "${INSTALL:-}" == "1" ]]; then
    local DEST="/Applications/$NAME.app"
    [[ -w /Applications ]] || DEST="$HOME/Applications/$NAME.app"
    rm -rf "$DEST"; cp -R "$OUT" "$DEST"; echo "installed $DEST"
    [[ "${LAUNCH:-}" == "1" ]] && open "$DEST"
  fi
}

for a in "$@"; do
  [[ "$a" == "--install" ]] && INSTALL=1
  [[ "$a" == "--launch" ]] && LAUNCH=1
done
build "Game Collection"  GameCollection  games
build "Music Collection" MusicCollection music -D MUSIC
