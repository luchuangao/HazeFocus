#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh universal
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
staging="$(mktemp -d "${TMPDIR:-/tmp}/hazefocus-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto artifacts/HazeFocus.app "$staging/HazeFocus.app"
ln -s /Applications "$staging/Applications"
cp docs/使用说明.txt "$staging/使用说明.txt"
hdiutil create -volname "HazeFocus" -srcfolder "$staging" -ov -format UDZO "artifacts/HazeFocus-$version.dmg"
ditto -c -k --sequesterRsrc --keepParent artifacts/HazeFocus.app "artifacts/HazeFocus-$version.zip"
shasum -a 256 "artifacts/HazeFocus-$version.dmg" "artifacts/HazeFocus-$version.zip" > artifacts/SHA256SUMS.txt
