#!/usr/bin/env bash
# Captures both clean raw screenshots and minimal marketing-framed screenshots
# for App Store Connect on iPhone 6.9" (1320x2868) and iPad Pro 13" (2064x2752).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

out_root="${1:-$root/dist/appstore-screenshots}"
derived="$root/build/DerivedScreenshots.noindex"
bundle_id="io.github.luongbinhf.viTek.mobile"
kb_id="io.github.luongbinhf.viTek.mobile.keyboard"

echo "==> Generating & building viTekMobile for iOS Simulator..."
xcodegen generate --spec Apps/iOS/project.yml
xcodebuild -quiet -project Apps/iOS/viTekMobile.xcodeproj -scheme viTekMobile -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO build

app_path="$(find "$derived/Build/Products" -name "viTekMobile.app" -print -quit)"
[[ -d "$app_path" ]] || { echo "viTekMobile.app not found" >&2; exit 1; }

runtime_id="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
data = json.load(sys.stdin)
for r in data["runtimes"]:
    if r.get("isAvailable") and "iOS" in r.get("name", ""):
        print(r["identifier"]); break
')"
[[ -n "$runtime_id" ]] || { echo "No available iOS Simulator runtime found" >&2; exit 1; }

ensure_simulator() {
  local name="$1"
  local device_type="$2"
  local existing
  existing="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for rt, devs in data['devices'].items():
    for d in devs:
        if d['name'] == '$name' and d.get('isAvailable'):
            print(d['udid']); sys.exit(0)
")"
  if [[ -n "$existing" ]]; then
    echo "$existing"
  else
    xcrun simctl create "$name" "$device_type" "$runtime_id"
  fi
}

strip_alpha_png() {
  local file="$1"
  local tmp="${file}.rgb.png"
  python3 - "$file" "$tmp" <<'PY'
import subprocess, sys
src, dst = sys.argv[1], sys.argv[2]
# sips -s format png does not strip alpha reliably; use CoreGraphics via swift or Quartz
PY
  swift - "$file" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let img = NSImage(contentsOf: url),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let cs = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    exit(1)
}
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
guard let out = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: url)
SWIFT
}

capture_device() {
  local label="$1"       # iphone-6.9 or ipad-13
  local kind="$2"        # iphone or ipad
  local sim_name="$3"
  local dev_type="$4"

  echo "==> Preparing Simulator: $sim_name ($label)..."
  local udid
  udid="$(ensure_simulator "$sim_name" "$dev_type")"
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false || true
  /usr/libexec/PlistBuddy -c "Delete :DevicePreferences:${udid}:ConnectHardwareKeyboard" "$HOME/Library/Preferences/com.apple.iphonesimulator.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :DevicePreferences:${udid}:ConnectHardwareKeyboard bool false" "$HOME/Library/Preferences/com.apple.iphonesimulator.plist" 2>/dev/null || true
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b

  # Clean status bar (9:41, 100% battery, full Wi-Fi/cellular) & Vietnamese locale
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 \
    --operatorName "" || true

  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "vi-VN" "en-US"
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "vi_VN"
  xcrun simctl spawn "$udid" defaults write -g AppleKeyboards -array "$kb_id" "en_US@sw=QWERTY;hw=Automatic"
  xcrun simctl spawn "$udid" defaults write -g AppleKeyboardsExpanded -int 1
  xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences KeyboardLastUsed -string "$kb_id"
  xcrun simctl spawn "$udid" defaults write com.apple.Preferences AutomaticMinimizationEnabled -bool false

  xcrun simctl uninstall "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl install "$udid" "$app_path"

  local raw_dir="$out_root/raw/$label"
  local framed_dir="$out_root/framed/$label"
  mkdir -p "$raw_dir" "$framed_dir"

  # Warm up app & seed realistic Vietnamese clipboard items
  xcrun simctl launch "$udid" "$bundle_id" -seedDemoClipboard >/dev/null
  sleep 3.5

  # 2. Clean home screen (without keyboard)
  xcrun simctl io "$udid" screenshot "$raw_dir/02_home.png" >/dev/null

  # 1. Keyboard open over live typing sandbox (auto-focused)
  xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl launch "$udid" "$bundle_id" -focusSandbox -seedDemoClipboard >/dev/null
  sleep 4.5
  xcrun simctl io "$udid" screenshot "$raw_dir/01_keyboard.png" >/dev/null

  # 3. AI Writing tab
  xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl launch "$udid" "$bundle_id" -tab writing -seedDemoClipboard >/dev/null
  sleep 2.2
  xcrun simctl io "$udid" screenshot "$raw_dir/03_writing.png" >/dev/null

  # 4. Clipboard tab (with seeded realistic Vietnamese samples)
  xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl launch "$udid" "$bundle_id" -tab clipboard -seedDemoClipboard >/dev/null
  sleep 2.2
  xcrun simctl io "$udid" screenshot "$raw_dir/04_clipboard.png" >/dev/null

  # 5. Settings tab
  xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl launch "$udid" "$bundle_id" -tab settings -seedDemoClipboard >/dev/null
  sleep 2.2
  xcrun simctl io "$udid" screenshot "$raw_dir/05_settings.png" >/dev/null

  # Strip alpha from raw PNGs so App Store Connect accepts them directly
  for f in "$raw_dir"/*.png; do
    strip_alpha_png "$f"
  done

  # Generate framed marketing versions
  swift "$root/scripts/frame_appstore_screenshots.swift" "$kind" "$raw_dir" "$framed_dir"

  xcrun simctl shutdown "$udid" 2>/dev/null || true
  echo "✓ Completed $label -> $raw_dir & $framed_dir"
}

capture_device "iphone-6.9" "iphone" "viTek AppStore iPhone 6.9" "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max"
capture_device "ipad-13" "ipad" "viTek AppStore iPad 13" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB"

echo ""
echo "All App Store screenshots generated in: $out_root"
ls -lh "$out_root"/raw/*/*.png "$out_root"/framed/*/*.png
