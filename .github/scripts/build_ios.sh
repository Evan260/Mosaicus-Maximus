#!/usr/bin/env bash
# Runs on a Mac: signs the Xcode project Godot exported for the iPhone and uploads it to App Store Connect, where it
# reaches TestFlight once Apple has processed it.
#   bash .github/scripts/build_ios.sh <the exported project as a .tar.gz>
set -euo pipefail

ARCHIVE="$1"
ROOT="$(pwd)"
source "$ROOT/.github/scripts/names.sh"
WORK="${RUNNER_TEMP:-/tmp}/ios"
SECRETS=(IOS_DIST_P12 IOS_DIST_P12_PASSWORD IOS_PROFILE ASC_API_KEY_P8 ASC_API_KEY_ID ASC_API_ISSUER_ID APPLE_TEAM_ID)

missing=()
for name in "${SECRETS[@]}"; do
  [ -n "${!name:-}" ] || missing+=("$name")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "::error title=iPhone secrets missing::Missing: ${missing[*]} (docs/Release-builds.md)"
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK/project"
tar -xzf "$ARCHIVE" -C "$WORK/project"
projects=("$WORK/project"/*.xcodeproj)
project="${projects[0]}"
[ -d "$project" ] || { echo "::error::No Xcode project in $ARCHIVE"; exit 1; }
scheme="$(basename "$project" .xcodeproj)"
plist="$(find "$WORK/project/$scheme" -maxdepth 1 -name '*-Info.plist' | head -1)"
[ -f "$plist" ] || { echo "::error::No Info.plist in $WORK/project/$scheme"; exit 1; }

KEYCHAIN="$WORK/signing.keychain-db"
P12="$WORK/distribution.p12"
P8="$WORK/AuthKey_$ASC_API_KEY_ID.p8"
PROFILE="$WORK/profile.mobileprovision"
cleanup() {
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -f "$P12" "$P8"
}
trap cleanup EXIT

KEYCHAIN_PASSWORD="$(openssl rand -hex 24)"
echo "::add-mask::$KEYCHAIN_PASSWORD"
printf '%s' "$IOS_DIST_P12" | base64 --decode > "$P12"
printf '%s' "$ASC_API_KEY_P8" | base64 --decode > "$P8"
printf '%s' "$IOS_PROFILE" | base64 --decode > "$PROFILE"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$P12" -k "$KEYCHAIN" -P "$IOS_DIST_P12_PASSWORD" -f pkcs12 -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# codesign only finds identities in keychains on the search list, so the new one joins the user's.
existing="$(security list-keychains -d user | tr -d '"' | xargs)"
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $existing

security cms -D -i "$PROFILE" > "$WORK/profile.plist"
profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$WORK/profile.plist")"
profile_name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$WORK/profile.plist")"
app_id="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$WORK/profile.plist")"
bundle_id="${app_id#*.}"
# Xcode reads profiles from the second folder since Xcode 16 and older tools from the first.
for dir in "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
  mkdir -p "$dir"
  cp "$PROFILE" "$dir/$profile_uuid.mobileprovision"
done

# Apple refuses a build number it has seen for this version, so each run of the workflow gets the next one.
build="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$plist"
version="$(grep -m1 -o 'MARKETING_VERSION = [^;]*' "$project/project.pbxproj" | cut -d' ' -f3 | tr -d '"')"
echo "$GAME_NAME $version ($build), $bundle_id, signed with $profile_name"

xcodebuild -project "$project" -scheme "$scheme" -configuration Release -destination "generic/platform=iOS" \
  -archivePath "$WORK/$scheme.xcarchive" archive \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  CODE_SIGN_IDENTITY="Apple Distribution" CURRENT_PROJECT_VERSION="$build" \
  PROVISIONING_PROFILE_SPECIFIER="$profile_name" OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" | tail -n 40

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key><dict><key>$bundle_id</key><string>$profile_name</string></dict>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$WORK/$scheme.xcarchive" -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$WORK/export" -authenticationKeyPath "$P8" -authenticationKeyID "$ASC_API_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_API_ISSUER_ID"
echo "::notice title=Uploaded to App Store Connect::$GAME_NAME $version ($build) reaches TestFlight once Apple has processed it, usually within half an hour."
