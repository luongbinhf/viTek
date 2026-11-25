#!/usr/bin/env bash
# Build the input method (Debug, ad-hoc signed) and install it for the current user.
# First install needs a log out/in, then add it under System Settings > Keyboard > Input Sources.
# Updates leave the selected input session before stopping the old server, atomically replace the
# bundle, and verify the new server with a nonce/version handshake. A client that retains a dead
# connection may still need to be reopened; neither the menu agent nor the server is force-killed.
#
#   scripts/install_dev.sh              build + install into ~/Library/Input Methods
#   CONFIGURATION=Release scripts/install_dev.sh    optimized build for daily use
#   INSTALL_DIR=/tmp/im scripts/install_dev.sh   install elsewhere (testing the script)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${INSTALL_DIR:-$HOME/Library/Input Methods}"
# ".noindex" keeps Spotlight from finding the build product: privacy permissions look the app up
# by bundle identifier and could otherwise attach a grant to this copy instead of the installed one.
derived="$root/build/DerivedData.noindex"
app_name="viTek.app"
configuration="${CONFIGURATION:-Debug}"
case "$configuration" in
  Debug|Release) ;;
  *) echo "install_dev.sh: CONFIGURATION must be Debug or Release" >&2; exit 1 ;;
esac

command -v xcodegen >/dev/null || { echo "install_dev.sh: xcodegen not found (brew install xcodegen)" >&2; exit 1; }

cd "$root"
xcodegen generate --spec Apps/macOS/project.yml
xcodebuild -project Apps/macOS/viTek.xcodeproj -scheme viTek -configuration "$configuration" \
  -derivedDataPath "$derived" build

built="$derived/Build/Products/$configuration/$app_name"
[[ -d "$built" ]] || { echo "install_dev.sh: build product not found at $built" >&2; exit 1; }

# Sign a staging copy before touching the installed bundle or stopping the current session.
staging="$(mktemp -d "${TMPDIR:-/tmp}/vitek-install.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$built" "$staging/$app_name"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$staging/$app_name/Contents/Info.plist")"
codesign --force --sign - --preserve-metadata=entitlements \
  -r="designated => identifier \"$bundle_id\"" "$staging/$app_name"
codesign --verify --deep --strict "$staging/$app_name"

xcrun swiftc -swift-version 6 \
  Apps/macOS/Installer/Installation.swift Apps/Shared/InputMethodConnection.swift \
  scripts/InstallInputMethod.swift -o "$staging/install-input-method"

activation=skip
if [[ -z "${INSTALL_DIR:-}" ]]; then
  lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  for product in "$root"/build/*/Build/Products/*/"$app_name"; do
    [[ -d "$product" ]] && "$lsregister" -u "$product" 2>/dev/null || true
  done
  activation=activate
fi
"$staging/install-input-method" "$staging/$app_name" "$install_dir/$app_name" "$activation"
echo "viTek $(scripts/version.sh show)"
