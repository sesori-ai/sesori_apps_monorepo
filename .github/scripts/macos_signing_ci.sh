#!/usr/bin/env bash
# Trusted manual CI only. Private material never enters the checkout or artifacts.
set -euo pipefail

case "$MACOS_DISTRIBUTION_MODE" in
  macos-signing-preflight|macos-packaging) ;;
  *) echo "Unsupported macOS distribution mode: $MACOS_DISTRIBUTION_MODE" >&2; exit 1 ;;
esac
for name in MACOS_CERT_P12_BASE64 MACOS_CERT_PASSWORD MACOS_KEYCHAIN_PASSWORD \
  APPLE_TEAM_ID APPLE_ID APPLE_APP_SPECIFIC_PASSWORD; do
  if [[ -z "${!name}" ]]; then
    echo "Required signing configuration is missing: $name" >&2
    exit 1
  fi
done
keychain="$RUNNER_TEMP/desktop-signing.keychain-db"
certificate="$RUNNER_TEMP/desktop-signing.p12"
probe="$RUNNER_TEMP/desktop-signing-probe"
history="$RUNNER_TEMP/desktop-notary-history.json"
profile=sesori-desktop-ci
identity="Developer ID Application: DigitalBlock Labs LTD ($APPLE_TEAM_ID)"
cleanup() {
  rm -f "$certificate" "$probe" "$probe.c" "$history"
  if [[ -f "$keychain" ]]; then
    security delete-keychain "$keychain"
  fi
}
trap cleanup EXIT
printf '%s' "$MACOS_CERT_P12_BASE64" | base64 --decode -o "$certificate"
security create-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$keychain"
security unlock-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$keychain"
security set-keychain-settings -lut 7200 "$keychain"
security import "$certificate" -k "$keychain" -P "$MACOS_CERT_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$MACOS_KEYCHAIN_PASSWORD" "$keychain" >/dev/null
# Required by codesign lookup on the qualified runners, even with --keychain.
security list-keychains -d user -s "$keychain" login.keychain
security find-identity -v -p codesigning "$keychain"
xcrun notarytool store-credentials "$profile" --keychain "$keychain" --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID"
unset MACOS_CERT_P12_BASE64 MACOS_CERT_PASSWORD MACOS_KEYCHAIN_PASSWORD APPLE_ID APPLE_APP_SPECIFIC_PASSWORD
xcrun notarytool history --keychain-profile "$profile" --keychain "$keychain" --output-format json > "$history"
echo 'Notarization profile authentication verified.'

if [[ "$MACOS_DISTRIBUTION_MODE" == macos-signing-preflight ]]; then
  printf 'int main(void) { return 0; }\n' > "$probe.c"
  xcrun clang "$probe.c" -o "$probe"
  codesign --sign "$identity" --keychain "$keychain" --timestamp --options runtime --force "$probe"
  codesign --verify --strict "$probe"
  "$probe"
  echo "Native $(uname -m) Developer ID timestamped/hardened probe signed, verified and executed."
  echo 'No product was submitted or published.'
else
  python .github/scripts/package_desktop_macos.py \
    --app build/desktop-bundle/Sesori.app --output build/desktop-macos-packaging \
    --arch "$TARGET_ARCH" --identity "$identity" --keychain "$keychain" --notary-profile "$profile"
  # The fixture uses the same identity/runtime/entitlements, but is not a notarized product.
  python - "$identity" "$keychain" "$TARGET_ARCH" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, '.github/scripts')
from package_desktop_macos import sign_app
sign_app(app=Path('build/desktop-platform-probe/Sesori.app').resolve(), arch=sys.argv[3],
         identity=sys.argv[1], keychain=Path(sys.argv[2]),
         log=Path('build/desktop-macos-packaging/platform-probe-signing.log'))
PY
fi
