#!/usr/bin/env bash
# Makes the Apple credentials the Mac build is signed and notarized with, inside WSL. Run each step from Windows with
#   wsl bash tools/steam/apple_setup.sh <step> ...
# Steps, in order (docs/Steam-publishing.md walks through the Apple website parts):
#   csr <folder>                          a private key and a certificate request; the request is copied to <folder>
#   p12 <developer_id.cer>                turns the certificate Apple issues for that request into the signing file
#   api-key <issuer id> <key id> <.p8>    stores the App Store Connect key that notarization logs in with
#   import-p12 <file.p12>                 instead of csr and p12: takes a Developer ID exported from a Mac's keychain
# Windows paths such as C:\Users\me\Downloads work for the folder and file arguments.
# The private key and passwords stay in ~/mosaicus-steam/apple inside WSL, readable only by this user.
set -euo pipefail

APPLE="$HOME/mosaicus-steam/apple"
RCODESIGN="$HOME/mosaicus-steam/bin/rcodesign"
mkdir -p "$APPLE"
chmod 700 "$APPLE"

to_wsl() {
  case "$1" in
    [A-Za-z]:\\*|[A-Za-z]:/*) wslpath -a "$1" ;;
    *) echo "$1" ;;
  esac
}

case "${1:-}" in
  csr)
    out=$(to_wsl "${2:?give the folder to put the request in}")
    if [ -f "$APPLE/developer_id.key" ]; then
      echo "A key already exists in $APPLE; delete it first to start over." >&2
      exit 1
    fi
    openssl req -new -newkey rsa:2048 -nodes -keyout "$APPLE/developer_id.key" -out "$APPLE/developer_id.csr" \
      -subj "/CN=Mosaicus Maximus Developer ID" 2>/dev/null
    chmod 600 "$APPLE/developer_id.key"
    cp "$APPLE/developer_id.csr" "$out/developer_id.csr"
    echo "Certificate request written to $out/developer_id.csr"
    ;;
  p12)
    cer=$(to_wsl "${2:?give the developer_id.cer file Apple issued}")
    openssl x509 -inform DER -in "$cer" -out "$APPLE/developer_id.pem"
    openssl rand -hex 24 > "$APPLE/p12_password"
    chmod 600 "$APPLE/p12_password"
    openssl pkcs12 -export -inkey "$APPLE/developer_id.key" -in "$APPLE/developer_id.pem" \
      -out "$APPLE/developer_id.p12" -passout "file:$APPLE/p12_password"
    chmod 600 "$APPLE/developer_id.p12"
    openssl x509 -in "$APPLE/developer_id.pem" -noout -subject
    echo "Signing file ready: $APPLE/developer_id.p12"
    ;;
  import-p12)
    p12=$(to_wsl "${2:?give the .p12 file exported from Keychain Access}")
    read -r -s -p "Password the .p12 was exported with: " password
    echo
    printf '%s' "$password" > "$APPLE/p12_password"
    chmod 600 "$APPLE/p12_password"
    cp "$p12" "$APPLE/developer_id.p12"
    chmod 600 "$APPLE/developer_id.p12"
    openssl pkcs12 -in "$APPLE/developer_id.p12" -nokeys -clcerts -passin "file:$APPLE/p12_password" | openssl x509 -noout -subject
    echo "Signing file ready: $APPLE/developer_id.p12. The .p12 can now be deleted from Windows."
    ;;
  api-key)
    p8=$(to_wsl "${4:?give the issuer id, the key id and the .p8 file}")
    "$RCODESIGN" encode-app-store-connect-api-key -o "$APPLE/api_key.json" "$2" "$3" "$p8"
    chmod 600 "$APPLE/api_key.json"
    echo "Notarization key ready: $APPLE/api_key.json. The .p8 file can now be deleted from Windows."
    ;;
  *)
    sed -n '2,11p' "$0"
    exit 1
    ;;
esac
