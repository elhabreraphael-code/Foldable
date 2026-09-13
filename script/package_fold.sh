#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
DEST="${1:-$PROJECT_DIR/dist/release}"
mkdir -p "$DEST"
# Build first with build_fold.sh. Packaging never recompiles an approved app.
codesign --verify --deep --strict dist/Foldable.app
STAGING="$(mktemp -d "$PROJECT_DIR/.build/fold-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/image" "$STAGING/Foldable-source"
ditto dist/Foldable.app "$STAGING/image/Foldable.app"
ln -s /Applications "$STAGING/image/Applications"
cp README.md "$STAGING/image/Read me.md"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/Foldable.app "$DEST/Foldable-1.0.0-arm64.zip"
hdiutil create -volname Foldable -srcfolder "$STAGING/image" -ov -format UDZO "$DEST/Foldable-1.0.0-arm64.dmg"
/usr/bin/rsync -a --exclude='.git' --exclude='.build' --exclude='dist' --exclude='.DS_Store' --exclude='.codex' ./ "$STAGING/Foldable-source/"
mkdir -p "$STAGING/Foldable-source/dist"
/usr/bin/ditto -c -k --keepParent "$STAGING/Foldable-source" "$DEST/Foldable-1.0.0-source.zip"
(cd "$DEST" && shasum -a 256 Foldable-1.0.0-arm64.zip Foldable-1.0.0-arm64.dmg Foldable-1.0.0-source.zip > SHA256SUMS.txt)
echo "Packaged in $DEST"
