#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-native}"
identity="${SIGNING_IDENTITY:--}"
if [[ "$identity" != "-" && "$identity" != "Developer ID Application: "* ]]; then
    echo 'SIGNING_IDENTITY must be a Developer ID Application certificate name.' >&2
    exit 1
fi
app="$PWD/artifacts/HazeFocus.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
if [[ "$mode" == "universal" ]]; then
    swift build -c release --arch arm64
    swift build -c release --arch x86_64
    lipo -create .build/arm64-apple-macosx/release/HazeFocus .build/x86_64-apple-macosx/release/HazeFocus -output "$app/Contents/MacOS/HazeFocus"
else
    swift build -c release
    binary_dir="$(swift build -c release --show-bin-path)"
    cp "$binary_dir/HazeFocus" "$app/Contents/MacOS/HazeFocus"
fi
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/HazeFocus.sdef "$app/Contents/Resources/HazeFocus.sdef"
if [[ ! -f Resources/AppIcon.icns || Resources/Brand/AppIcon-Source.png -nt Resources/AppIcon.icns || Resources/Brand/LogoMark-Source.png -nt Resources/AppIcon.icns || scripts/make-icon.swift -nt Resources/AppIcon.icns ]]; then
    xcrun swift scripts/make-icon.swift
fi
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Resources/Brand/AppIcon.png "$app/Contents/Resources/AppIcon.png"
cp Resources/Brand/LogoMark.png "$app/Contents/Resources/LogoMark.png"
cp Resources/Brand/MenuBarTemplate.png "$app/Contents/Resources/MenuBarTemplate.png"
cp Resources/Brand/MenuBarTemplate@2x.png "$app/Contents/Resources/MenuBarTemplate@2x.png"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$app/Contents/Resources/"
if [[ "$identity" == "-" ]]; then
    codesign --force --sign - --identifier com.luchuangao.hazefocus "$app"
else
    codesign --force --sign "$identity" --options runtime --timestamp --identifier com.luchuangao.hazefocus "$app"
fi
codesign --verify --strict "$app"
printf 'Built: %s\n' "$app"
