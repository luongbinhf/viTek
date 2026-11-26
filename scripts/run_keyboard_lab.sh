#!/usr/bin/env bash
# End-to-end iOS software keyboard verification runner (`KeyboardLab`).
# Builds viTekMobile + viTekKeyboard, registers the keyboard extension on an available iPhone Simulator,
# runs all software keyboard typing tests in Apps/iOS/KeyboardTests, and optionally saves a screenshot.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

sim_id="${SIMULATOR_ID:-$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $2; exit}')}"
[[ -n "$sim_id" ]] || { echo "No available iPhone Simulator found." >&2; exit 1; }

echo "Booting Simulator $sim_id..."
xcrun simctl boot "$sim_id" 2>/dev/null || true
xcrun simctl bootstatus "$sim_id" -b

derived="$root/build/DerivedKeyboardLab.noindex"
xcodegen generate --spec Apps/iOS/project.yml
xcodebuild -quiet -project Apps/iOS/viTekMobile.xcodeproj -scheme viTekMobile -configuration Debug \
  -destination "platform=iOS Simulator,id=$sim_id" \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO build

app_path="$(find "$derived/Build/Products" -name "viTekMobile.app" -print -quit)"
[[ -d "$app_path" ]] || { echo "viTekMobile.app not found in $derived" >&2; exit 1; }

echo "Installing viTekMobile.app & enabling viTekKeyboard extension..."
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false || true
xcrun simctl install "$sim_id" "$app_path"
xcrun simctl spawn "$sim_id" defaults write -g AppleKeyboards -array \
  "io.github.luongbinhf.viTek.mobile.keyboard" \
  "en_US@sw=QWERTY;hw=Automatic"
xcrun simctl spawn "$sim_id" defaults write -g AppleKeyboardsExpanded -int 1
xcrun simctl spawn "$sim_id" defaults write com.apple.keyboard.preferences KeyboardLastUsed -string "io.github.luongbinhf.viTek.mobile.keyboard"

xcodegen generate --spec Apps/iOS/KeyboardTests/project.yml
xcodebuild -quiet -project Apps/iOS/KeyboardTests/KeyboardLab.xcodeproj -scheme KeyboardLab \
  -destination "platform=iOS Simulator,id=$sim_id" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test

echo "KeyboardLab software keyboard UI tests passed on Simulator $sim_id!"
