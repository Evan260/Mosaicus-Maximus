#!/usr/bin/env bash
# Uploads the release builds in artifacts/ to Steam with steamcmd, live on the testing branch, using the depots in
# tools/steam/steam.json and tools/steam/publish.py's build script layout:
#   bash .github/scripts/steam_upload.sh <playtest|game|demo>
set -euo pipefail

TARGET="$1"
case "$TARGET" in
  playtest|game) EDITION=full ;;
  demo) EDITION=demo ;;
  *) echo "::error::Unknown Steam target '$TARGET'; use playtest, game or demo"; exit 1 ;;
esac
ROOT="$(pwd)"
source "$ROOT/.github/scripts/names.sh"
ARTIFACTS="$ROOT/artifacts"
WORK="${RUNNER_TEMP:-/tmp}/steam"
if [ -z "${STEAM_USERNAME:-}" ] || [ -z "${STEAM_CONFIG_VDF:-}" ]; then
  echo "::error title=Steam secrets missing::Set STEAM_USERNAME and STEAM_CONFIG_VDF (docs/Release-builds.md)"
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK/content" "$WORK/output" "$WORK/unpack"
platforms="$(python3 - "$TARGET" "$WORK" "$LABEL" <<'PY'
import json
import sys

sys.path.insert(0, "tools/steam")
import publish

name, work, label = sys.argv[1:]
target = json.loads(open("tools/steam/steam.json", encoding="utf-8").read())["targets"][name]
depots = [platform for platform, depot in target["depots"].items() if depot]
if not target["app_id"] or not depots:
    sys.exit(f"Set the {name} app id and depot ids in tools/steam/steam.json first (docs/Steam-publishing.md)")
if target["branch"] != "testing":
    sys.exit("A build only goes live on the testing branch; set its branch to testing in tools/steam/steam.json")
note = f"{label} built on GitHub".replace('"', "'")
with open(f"{work}/app_build.vdf", "w", encoding="utf-8", newline="\n") as f:
    f.write(publish.vdf(target, {p: target["depots"][p] for p in depots}, note, f"{work}/content", f"{work}/output"))
print(" ".join(depots))
PY
)"

for platform in $platforms; do
  case "$platform" in
    windows)
      unzip -q -o "$ARTIFACTS/$SLUG-$LABEL-windows.zip" -d "$WORK/unpack/windows"
      mv "$WORK/unpack/windows/$GAME_NAME" "$WORK/content/windows"
      # The everything-unlocked launcher stays in the GitHub release but never reaches players on Steam.
      rm -f "$WORK/content/windows/$GAME_NAME - everything unlocked.bat"
      ;;
    linux)
      mkdir -p "$WORK/content/linux"
      tar -xzf "$ARTIFACTS/$SLUG-$LABEL-linux.tar.gz" -C "$WORK/content/linux" --strip-components=1
      ;;
    macos)
      if [ ! -f "$ARTIFACTS/$SLUG-$LABEL-macos.zip" ]; then
        echo "::error title=Mac build unsigned::Steam needs a notarized Mac app; add the Apple secrets or set the macos depot to 0"
        exit 1
      fi
      unzip -q -o "$ARTIFACTS/$SLUG-$LABEL-macos.zip" -d "$WORK/unpack/macos"
      mv "$WORK/unpack/macos/$GAME_NAME" "$WORK/content/macos"
      chmod 755 "$WORK/content/macos/"*.app/Contents/MacOS/*
      ;;
  esac
done

sudo dpkg --add-architecture i386
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq lib32gcc-s1 >/dev/null
mkdir -p "$HOME/steamcmd"
curl -fsSL --retry 3 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C "$HOME/steamcmd"
"$HOME/steamcmd/steamcmd.sh" +quit >/dev/null || true
# The saved login from a computer where steamcmd already passed Steam Guard, so no password or code is needed here.
mkdir -p "$HOME/Steam/config"
(umask 077 && printf '%s' "$STEAM_CONFIG_VDF" | base64 --decode > "$HOME/Steam/config/config.vdf")

set +e
"$HOME/steamcmd/steamcmd.sh" +login "$STEAM_USERNAME" +run_app_build "$WORK/app_build.vdf" +quit | tee "$WORK/steamcmd.log"
set -e
rm -f "$HOME/Steam/config/config.vdf"
if ! grep -q "Successfully finished AppID" "$WORK/steamcmd.log"; then
  echo "::error title=Steam upload failed::If steamcmd asked for a password or Steam Guard code, make STEAM_CONFIG_VDF again (docs/Release-builds.md)"
  exit 1
fi
echo "::notice title=Uploaded to Steam::$GAME_NAME $LABEL is live on the testing branch of the $TARGET app"
