#!/usr/bin/env bash
# Exports one platform with tools/export.py, then packs it into dist/:
#   bash .github/scripts/export.sh <windows|macos|linux>
# Windows becomes a .zip and Linux a .tar.gz, which keeps the executable permissions that artifacts drop. macOS stays
# Godot's own .zip beside the credits, for the signing job to open on a Mac.
set -euo pipefail

PLATFORM="$1"
ROOT="$(pwd)"
source "$ROOT/.github/scripts/names.sh"
STAGE="$ROOT/builds/ci/$PLATFORM"
DIST="$ROOT/dist"

rm -rf "$STAGE" "$DIST"
mkdir -p "$STAGE" "$DIST"
GODOT="${GODOT:-godot}" python3 tools/export.py "$PLATFORM"
cp -r "$ROOT/builds/$PLATFORM" "$STAGE/$GAME_NAME"

case "$PLATFORM" in
  windows)
    (cd "$STAGE" && zip -q -r -9 "$DIST/$SLUG-$LABEL-windows.zip" "$GAME_NAME")
    ;;
  linux)
    chmod 644 "$STAGE/$GAME_NAME/"*
    chmod 755 "$STAGE/$GAME_NAME/"*.x86_64 "$STAGE/$GAME_NAME/"*.so
    tar -czf "$DIST/$SLUG-$LABEL-linux.tar.gz" -C "$STAGE" "$GAME_NAME"
    ;;
  macos)
    cp "$STAGE/$GAME_NAME/"* "$DIST/"
    ;;
esac
ls -l "$DIST"
