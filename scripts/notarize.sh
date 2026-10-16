#!/bin/bash
# Credentials must already be stored with `xcrun notarytool store-credentials`.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to the full Developer ID Application certificate name}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool keychain profile name}"
[[ "$SIGNING_IDENTITY" == "Developer ID Application: "* ]] || {
    echo 'A Developer ID Application identity is required.' >&2; exit 1;
}
security find-identity -v -p codesigning | grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null || {
    echo 'The requested signing certificate and private key are not available.' >&2; exit 1;
}
auth=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then auth+=(--keychain "$NOTARY_KEYCHAIN"); fi
# Authenticate before rebuilding or replacing any distribution artifacts.
xcrun notarytool history "${auth[@]}" --output-format json >/dev/null
mkdir -p artifacts/notarization

json_value() {
    /usr/bin/plutil -extract "$2" raw -o - "$1"
}

notarize_archive() {
    local archive="$1" label="$2" digest request state request_id status
    digest="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
    request="artifacts/notarization/$label-$digest-submission.json"
    state="artifacts/notarization/$label-$digest-status.json"
    # Keep submission IDs and logs bound to the exact archive digest.
    if [[ ! -s "$request" ]]; then
        xcrun notarytool submit "$archive" "${auth[@]}" --output-format json > "$request.tmp"
        mv "$request.tmp" "$request"
    fi
    request_id="$(json_value "$request" id)"
    echo "Waiting for Apple notarization: $label ($request_id)"
    if ! xcrun notarytool wait "$request_id" "${auth[@]}" --timeout 30m --output-format json > "$state"; then
        echo "Notarization wait failed; submission ID: $request_id. Use notarytool info/wait with this ID before submitting again." >&2
        return 1
    fi
    status="$(json_value "$state" status)"
    xcrun notarytool log "$request_id" "${auth[@]}" "artifacts/notarization/$label-$digest-log.json"
    if [[ "$status" != 'Accepted' ]]; then
        echo "Apple returned $status; see artifacts/notarization/$label-$digest-log.json" >&2
        return 1
    fi
}

bash scripts/build.sh universal
app=artifacts/HazeFocus.app
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
app_zip="artifacts/notarization/HazeFocus-$version-submission.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$app_zip"
notarize_archive "$app_zip" app
xcrun stapler staple "$app"
xcrun stapler validate "$app"
# Package the stapled app without rebuilding and losing its ticket.
bash scripts/package.sh --skip-build
dmg="artifacts/HazeFocus-$version.dmg"
notarize_archive "$dmg" dmg
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
codesign --verify --strict "$app"
codesign --verify --strict "$dmg"
spctl --assess --type execute --verbose=2 "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
hdiutil verify "$dmg"
shasum -a 256 "$dmg" "artifacts/HazeFocus-$version.zip" > artifacts/SHA256SUMS.txt
echo "Notarized and verified: $dmg"
