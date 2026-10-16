#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" != "--skip-build" ]]; then
    bash scripts/build.sh universal
fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' artifacts/HazeFocus.app/Contents/Info.plist)"
[[ "$version" == "$app_version" ]] || { echo 'App and source versions differ.' >&2; exit 1; }
codesign --verify --strict artifacts/HazeFocus.app
staging="$(mktemp -d "${TMPDIR:-/tmp}/hazefocus-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto artifacts/HazeFocus.app "$staging/HazeFocus.app"
ln -s /Applications "$staging/Applications"
cp docs/使用说明.txt "$staging/使用说明.txt"
hdiutil create -volname "HazeFocus" -srcfolder "$staging" -ov -format UDZO "artifacts/HazeFocus-$version.dmg"
if [[ -n "${SIGNING_IDENTITY:-}" && "$SIGNING_IDENTITY" != "-" ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "artifacts/HazeFocus-$version.dmg"
fi
ditto -c -k --sequesterRsrc --keepParent artifacts/HazeFocus.app "artifacts/HazeFocus-$version.zip"
shasum -a 256 "artifacts/HazeFocus-$version.dmg" "artifacts/HazeFocus-$version.zip" > artifacts/SHA256SUMS.txt
