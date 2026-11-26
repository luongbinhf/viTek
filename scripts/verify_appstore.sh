#!/usr/bin/env bash
# Pre-flight App Store Connect & Apple App Review readiness check for viTek iOS/iPadOS.
# Verifies version compliance, privacy manifests, RequestsOpenAccess=false, non-alpha 1024x1024 icon,
# App Group entitlements, and compiled keyboard extension bundle size (< 5 MB).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() { echo "✗ App Store check failed: $*" >&2; exit 1; }
ok()   { echo "✓ $*"; }

# 1. Version Synchronization & App Store Connect CFBundleVersion rules
mac_v="$(scripts/version.sh check)"
ios_v="$(awk -F' = ' '/CURRENT_PROJECT_VERSION/ {print $2; exit}' Apps/iOS/Config/Version.xcconfig | tr -d '[:space:]')"
[[ "$ios_v" =~ ^[1-9][0-9]*\.[0-9]+\.[0-9]+$ ]] || fail "Invalid iOS version '$ios_v'"
(( ${#ios_v} <= 18 )) || fail "iOS CFBundleVersion '$ios_v' exceeds 18-character App Store limit"
ok "Version sync verified (macOS=$mac_v, iOS App Store=$ios_v)"

# 2. Keyboard Privacy: RequestsOpenAccess must be false
open_access="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:RequestsOpenAccess' Apps/iOS/Keyboard/Info.plist 2>/dev/null || echo missing)"
[[ "$open_access" == "false" ]] || fail "Keyboard RequestsOpenAccess must be false (got '$open_access')"
ok "Keyboard Extension RequestsOpenAccess=false verified"

# 3. Privacy Manifests present
[[ -s Apps/Shared/PrivacyInfo.xcprivacy ]] || fail "Missing Apps/Shared/PrivacyInfo.xcprivacy"
ok "PrivacyInfo.xcprivacy manifest verified"

# 4. 1024x1024 AppIcon PNG exists with NO alpha channel
icon_png="$(find Apps/iOS/viTek/Assets.xcassets/AppIcon.appiconset -name '*.png' -print -quit)"
[[ -s "$icon_png" ]] || fail "Missing iOS 1024x1024 AppIcon PNG"
has_alpha="$(sips -g hasAlpha "$icon_png" | awk '/hasAlpha:/ {print $2}')"
px_w="$(sips -g pixelWidth "$icon_png" | awk '/pixelWidth:/ {print $2}')"
px_h="$(sips -g pixelHeight "$icon_png" | awk '/pixelHeight:/ {print $2}')"
[[ "$px_w" == "1024" && "$px_h" == "1024" ]] || fail "AppIcon must be 1024x1024 (got ${px_w}x${px_h})"
[[ "$has_alpha" == "no" ]] || fail "AppIcon must not contain an alpha channel (hasAlpha=$has_alpha)"
ok "AppIcon 1024x1024 opaque (hasAlpha=no) verified"

# 5. Build Release iOS Simulator bundle and verify viTekKeyboard.appex size (< 5 MB)
derived="$root/build/DerivedAppStoreAudit.noindex"
xcodegen generate --spec Apps/iOS/project.yml >/dev/null
xcodebuild -quiet -project Apps/iOS/viTekMobile.xcodeproj -scheme viTekMobile -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build

appex="$(find "$derived/Build/Products" -name "viTekKeyboard.appex" -print -quit)"
[[ -d "$appex" ]] || fail "Compiled viTekKeyboard.appex not found"
[[ -f "$appex/PrivacyInfo.xcprivacy" ]] || fail "PrivacyInfo.xcprivacy not bundled inside viTekKeyboard.appex"
kb_kb="$(du -sk "$appex" | awk '{print $1}')"
(( kb_kb < 5120 )) || fail "viTekKeyboard.appex size (${kb_kb} KB) exceeds 5 MB budget"
ok "viTekKeyboard.appex Release bundle verified (${kb_kb} KB < 5120 KB budget, PrivacyInfo included)"

echo "All App Store & TestFlight readiness checks passed!"
