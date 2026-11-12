#!/usr/bin/env bash
# Installs what the Mac and Linux uploads need inside WSL (Ubuntu): Valve's Linux steamcmd and rcodesign, the tool
# that signs and notarizes the Mac app without a Mac. Run once from Windows:
#   wsl -u root -- bash tools/steam/wsl_setup.sh
# Everything lands in the default WSL user's home, in ~/mosaicus-steam.
set -euo pipefail

RCODESIGN_VERSION=0.29.0
USER_NAME=$(getent passwd 1000 | cut -d: -f1)
HOME_DIR=$(getent passwd 1000 | cut -d: -f6)
BASE="$HOME_DIR/mosaicus-steam"

dpkg --add-architecture i386
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip lib32gcc-s1 ca-certificates curl

mkdir -p "$BASE/steamcmd" "$BASE/bin"
if [ ! -x "$BASE/steamcmd/steamcmd.sh" ]; then
  curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C "$BASE/steamcmd"
fi
if [ ! -x "$BASE/bin/rcodesign" ]; then
  name="apple-codesign-$RCODESIGN_VERSION-x86_64-unknown-linux-musl"
  curl -sSL "https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign/$RCODESIGN_VERSION/$name.tar.gz" \
    | tar -xz -C /tmp
  mv "/tmp/$name/rcodesign" "$BASE/bin/rcodesign"
  rm -rf "/tmp/$name"
fi
chown -R "$USER_NAME:$USER_NAME" "$BASE"
# steamcmd updates itself on its first run.
sudo -u "$USER_NAME" "$BASE/steamcmd/steamcmd.sh" +quit >/dev/null || true
"$BASE/bin/rcodesign" --version
echo "ready: $BASE"
