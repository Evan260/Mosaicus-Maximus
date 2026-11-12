#!/usr/bin/env bash
# Installs the pinned Godot for Linux from the official GitHub release, checking each download against its checksum:
#   bash .github/scripts/install_godot.sh editor      the headless-capable editor, as ~/godot/godot
#   bash .github/scripts/install_godot.sh templates   the Linux and macOS export templates this game exports with
# The Windows export uses the trimmed template in the repository, so no stock Windows template is installed.
set -euo pipefail

VERSION=4.7.2
EDITOR_SHA512=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
TEMPLATES_SHA512=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
RELEASE="https://github.com/godotengine/godot/releases/download/$VERSION-stable"
DOWNLOADS="${GODOT_DOWNLOADS:-${RUNNER_TEMP:-/tmp}/godot-downloads}"
EDITOR_DIR="$HOME/godot"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/$VERSION.stable"

fetch() {
  local file="$1" sum="$2"
  mkdir -p "$DOWNLOADS"
  if ! echo "$sum  $DOWNLOADS/$file" | sha512sum --check --status 2>/dev/null; then
    curl -fsSL --retry 3 -o "$DOWNLOADS/$file" "$RELEASE/$file"
    echo "$sum  $DOWNLOADS/$file" | sha512sum --check
  fi
}

case "${1:-}" in
  editor)
    fetch "Godot_v$VERSION-stable_linux.x86_64.zip" "$EDITOR_SHA512"
    rm -rf "$EDITOR_DIR"
    mkdir -p "$EDITOR_DIR"
    unzip -q -j "$DOWNLOADS/Godot_v$VERSION-stable_linux.x86_64.zip" -d "$EDITOR_DIR"
    mv "$EDITOR_DIR/Godot_v$VERSION-stable_linux.x86_64" "$EDITOR_DIR/godot"
    chmod +x "$EDITOR_DIR/godot"
    "$EDITOR_DIR/godot" --headless --version
    ;;
  templates)
    fetch "Godot_v$VERSION-stable_export_templates.tpz" "$TEMPLATES_SHA512"
    rm -rf "$TEMPLATE_DIR"
    mkdir -p "$TEMPLATE_DIR"
    unzip -q -j "$DOWNLOADS/Godot_v$VERSION-stable_export_templates.tpz" -d "$TEMPLATE_DIR" \
      templates/version.txt templates/icudt_godot.dat templates/linux_release.x86_64 templates/macos.zip
    rm -f "$DOWNLOADS/Godot_v$VERSION-stable_export_templates.tpz"
    ls -l "$TEMPLATE_DIR"
    ;;
  *)
    sed -n '2,5p' "$0"
    exit 1
    ;;
esac
