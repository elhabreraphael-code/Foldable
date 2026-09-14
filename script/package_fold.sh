#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
DEST="${1:-$PROJECT_DIR/dist/release}"
mkdir -p "$DEST"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" dist/Foldable.app/Contents/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" dist/Foldable.app/Contents/Info.plist)
SOURCE_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist)
SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
if [ "$VERSION" != "$SOURCE_VERSION" ] || [ "$BUILD" != "$SOURCE_BUILD" ]; then
  echo "Bundle/source version mismatch. Build the matching source before packaging." >&2
  exit 1
fi
VERSION="${VERSION}-Final"
lipo dist/Foldable.app/Contents/MacOS/Fold -verify_arch arm64
# Build first with build_fold.sh. Packaging never recompiles an approved app.
codesign --verify --deep --strict dist/Foldable.app
STAGING="$(mktemp -d "$PROJECT_DIR/.build/fold-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/image" "$STAGING/Foldable-source"
ditto dist/Foldable.app "$STAGING/image/Foldable.app"
ln -s /Applications "$STAGING/image/Applications"
cp README.md "$STAGING/image/Read me.md"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/Foldable.app "$DEST/Foldable-${VERSION}-arm64.zip"
hdiutil create -volname Foldable -srcfolder "$STAGING/image" -ov -format UDZO "$DEST/Foldable-${VERSION}-arm64.dmg"
/usr/bin/rsync -a --exclude='.git' --exclude='.build' --exclude='dist' --exclude='.DS_Store' --exclude='.codex' ./ "$STAGING/Foldable-source/"
mkdir -p "$STAGING/Foldable-source/dist"
/usr/bin/ditto -c -k --keepParent "$STAGING/Foldable-source" "$DEST/Foldable-${VERSION}-source.zip"
(cd "$DEST" && shasum -a 256 Foldable-${VERSION}-arm64.zip Foldable-${VERSION}-arm64.dmg Foldable-${VERSION}-source.zip > SHA256SUMS.txt)
echo "Packaged in $DEST"
