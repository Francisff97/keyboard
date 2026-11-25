#!/bin/bash
# Crea la versione da scaricare di Tocco: dist/Tocco-<versione>.dmg e .zip
#
#   ./scripts/build_release.sh
#
# Serve un Mac con Flutter e Xcode. L'app è firmata "ad hoc" (senza account
# Apple Developer): la prima volta va aperta con tasto destro → Apri.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
APP_NAME="Tocco"
OUT="dist"
APP="build/macos/Build/Products/Release/${APP_NAME}.app"

echo "→ Tocco ${VERSION}"
echo "→ pacchetti"
flutter pub get

echo "→ test"
flutter test

echo "→ build macOS (release)"
flutter build macos --release

echo "→ firma ad hoc"
codesign --force --deep --sign - "$APP"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "→ zip"
ditto -c -k --keepParent "$APP" "${OUT}/${APP_NAME}-${VERSION}.zip"

echo "→ dmg"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "${OUT}/${APP_NAME}-${VERSION}.dmg" >/dev/null
rm -rf "$STAGE"

echo ""
echo "Fatto:"
ls -lh "$OUT"
open "$OUT"
