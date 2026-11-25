#!/bin/zsh
# Build only. Launch the resulting app through `open`, not its executable directly.
set -euo pipefail
root="${0:A:h:h}"
app="$root/build/QAInputDriver.noindex/viTekInputQA.app"
mkdir -p "$app/Contents/MacOS"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.luongbinhf.viTek.system-input-qa</string>
<key>CFBundleExecutable</key><string>viTekInputQA</string>
<key>CFBundleName</key><string>viTek Input QA</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  "$root/Tests/macOSCompatibility/SystemKeyboardQA.swift" \
  "$root/Tests/macOSCompatibility/FocusRaceQA.swift" \
  "$root/Tests/macOSCompatibility/DelayedSuggestionQA.swift" \
  "$root/Tests/macOSCompatibility/StressKeyboardQA.swift" \
  -o "$app/Contents/MacOS/viTekInputQA"
codesign --force --sign - \
  -r='designated => identifier "io.github.luongbinhf.viTek.system-input-qa"' "$app"
codesign --verify --strict "$app"
echo "$app"
