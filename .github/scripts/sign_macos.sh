#!/usr/bin/env bash
# Runs on a Mac: opens Godot's export, signs, notarizes and staples the app when the Apple secrets are set, and zips it
# with the credits into dist/. Without the secrets it zips the app unsigned and says so.
#   bash .github/scripts/sign_macos.sh <folder with the exported .zip and the credits>
set -euo pipefail

EXPORT="$1"
ROOT="$(pwd)"
source "$ROOT/.github/scripts/names.sh"
WORK="${RUNNER_TEMP:-/tmp}/mac"
DIST="$ROOT/dist"
SECRETS=(MACOS_CERTIFICATE_P12 MACOS_CERTIFICATE_PASSWORD APPLE_API_KEY_P8 APPLE_API_KEY_ID APPLE_API_ISSUER_ID APPLE_TEAM_ID)

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK/$GAME_NAME" "$DIST"
exported=("$EXPORT"/*.zip)
ditto -x -k "${exported[0]}" "$WORK/$GAME_NAME"
cp "$EXPORT/Credits and licences.txt" "$WORK/$GAME_NAME/"
apps=("$WORK/$GAME_NAME"/*.app)
app="${apps[0]}"
[ -d "$app" ] || { echo "::error::No .app inside ${exported[0]}"; exit 1; }

missing=()
for name in "${SECRETS[@]}"; do
  [ -n "${!name:-}" ] || missing+=("$name")
done
if [ ${#missing[@]} -eq ${#SECRETS[@]} ]; then
  echo "::notice title=macOS build left unsigned::The Apple secrets are not set, so $GAME_NAME for macOS is not signed or notarized (docs/Release-builds.md)."
  ditto -c -k --keepParent "$WORK/$GAME_NAME" "$DIST/$SLUG-$LABEL-macos-unsigned.zip"
  exit 0
fi
if [ ${#missing[@]} -gt 0 ]; then
  echo "::error title=Apple secrets incomplete::Missing: ${missing[*]} (docs/Release-builds.md)"
  exit 1
fi

KEYCHAIN="$WORK/signing.keychain-db"
P12="$WORK/certificate.p12"
P8="$WORK/AuthKey.p8"
cleanup() {
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -f "$P12" "$P8"
}
trap cleanup EXIT

KEYCHAIN_PASSWORD="$(openssl rand -hex 24)"
echo "::add-mask::$KEYCHAIN_PASSWORD"
printf '%s' "$MACOS_CERTIFICATE_P12" | base64 --decode > "$P12"
printf '%s' "$APPLE_API_KEY_P8" | base64 --decode > "$P8"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$P12" -k "$KEYCHAIN" -P "$MACOS_CERTIFICATE_PASSWORD" -f pkcs12 -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# codesign only finds identities in keychains on the search list, so the new one joins the user's.
existing="$(security list-keychains -d user | tr -d '"' | xargs)"
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $existing
IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" | grep "Developer ID Application" | grep "($APPLE_TEAM_ID)" | head -1 | awk '{print $2}')"
if [ -z "$IDENTITY" ]; then
  echo "::error::The certificate holds no Developer ID Application identity for team $APPLE_TEAM_ID"
  exit 1
fi

sign() {
  codesign --force --timestamp --options runtime --keychain "$KEYCHAIN" --sign "$IDENTITY" "$@"
}
while IFS= read -r -d '' library; do
  sign "$library"
done < <(find "$app/Contents" \( -name '*.dylib' -o -name '*.so' \) -type f -not -path '*.framework/*' -print0)
while IFS= read -r -d '' framework; do
  sign "$framework"
done < <(find "$app/Contents" -name '*.framework' -type d -prune -print0)
sign --entitlements "$ROOT/tools/steam/macos_entitlements.plist" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

ditto -c -k --keepParent "$app" "$WORK/notarize.zip"
result="$(xcrun notarytool submit "$WORK/notarize.zip" --key "$P8" --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" --wait --timeout 1h --output-format json)" || true
field() {
  printf '%s' "$result" | python3 -c 'import json, sys; t = sys.stdin.read(); print(json.loads(t).get(sys.argv[1], "") if t.strip().startswith("{") else "")' "$1"
}
status="$(field status)"
if [ "$status" != Accepted ]; then
  submission="$(field id)"
  echo "::error title=Notarization failed::Apple answered '$status'; its log follows"
  [ -n "$submission" ] && xcrun notarytool log "$submission" --key "$P8" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID"
  exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=4 "$app"

ditto -c -k --keepParent "$WORK/$GAME_NAME" "$DIST/$SLUG-$LABEL-macos.zip"
ls -l "$DIST"
