#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BUNDLE="$PROJECT_DIR/dist/Foldable.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/LidPlane" "$BUNDLE/Contents/MacOS/Fold"
cp Info.plist "$BUNDLE/Contents/Info.plist"
cp LICENSE COPYRIGHT "$BUNDLE/Contents/Resources/"
if [ ! -f Resources/AppIcon.icns ]; then
  swift script/make_icon.swift .build/AppIcon.iconset
  iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/"
codesign --force --sign "${FOLD_SIGN_IDENTITY:--}" --identifier app.fold.mac "$BUNDLE"
echo "$BUNDLE"
