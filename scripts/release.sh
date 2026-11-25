#!/usr/bin/env bash
# Public release: DEVELOPER_ID_APPLICATION, DEVELOPMENT_TEAM and NOTARY_PROFILE.
# --local builds an ad-hoc signed DMG suffixed -local for this Mac.
# --adhoc builds an ad-hoc signed DMG with canonical filename (viTek-<version>.dmg).
# SKIP_NOTARIZE=1 skips only notarization.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
version="$(scripts/version.sh check)"
name="viTek-$version"
dist="$root/dist"
mode="${1:-}"
case "$mode" in
  --local)
    name="$name-local"
    derived="$root/build/DerivedData.noindex"
    signing=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-)
    ;;
  --adhoc)
    derived="$root/build/DerivedRelease.noindex"
    signing=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-)
    ;;
  "")
    : "${DEVELOPER_ID_APPLICATION:?set DEVELOPER_ID_APPLICATION or use --local/--adhoc}"
    derived="$root/build/DerivedRelease.noindex"
    signing=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" OTHER_CODE_SIGN_FLAGS=--timestamp)
    if [[ "${SKIP_NOTARIZE:-0}" != 1 ]]; then
      : "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM}"
      : "${NOTARY_PROFILE:?set NOTARY_PROFILE}"
    fi
    [[ -z "${DEVELOPMENT_TEAM:-}" ]] || signing+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
    ;;
  *) echo "usage: scripts/release.sh [--local|--adhoc]" >&2; exit 2 ;;
esac

xcodegen generate --spec Apps/macOS/project.yml
xcodebuild -quiet -project Apps/macOS/viTek.xcodeproj -scheme viTekInstaller -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived" "${signing[@]}" build

mkdir -p "$dist"
stage="$(mktemp -d "$dist/.stage.XXXXXX")"
device=""
cleanup() {
  if [[ -n "$device" ]]; then
    hdiutil detach "$device" -quiet 2>/dev/null || hdiutil detach -force "$device" -quiet 2>/dev/null || true
  fi
  rm -rf "$stage"
}
trap cleanup EXIT

volume="$stage/volume"
mkdir "$volume"
installer="$volume/Cài viTek.app"
ditto "$derived/Build/Products/Release/viTekInstaller.app" "$installer"
payload="$installer/Contents/Helpers/viTek.app"
if [[ "$mode" == --local || "$mode" == --adhoc ]]; then
  # Match install_dev.sh so an existing development Accessibility grant survives the update.
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$payload/Contents/Info.plist")"
  codesign --force --sign - --preserve-metadata=entitlements,flags \
    -r="designated => identifier \"$bundle_id\"" "$payload"
  codesign --force --sign - --preserve-metadata=entitlements,flags "$installer"
fi
for app in "$installer" "$payload"; do
  icon="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app/Contents/Info.plist")"
  [[ -s "$app/Contents/Resources/${icon%.icns}.icns" ]] || { echo "Missing icon: $app" >&2; exit 1; }
  codesign --verify --deep --strict "$app"
done

# Docker / GitHub / Google-style drag-and-drop installer staging
ln -s /Applications "$volume/Applications"
if [[ -s "$root/assets/brand/dmg-background.tiff" ]]; then
  mkdir -p "$volume/.background"
  cp "$root/assets/brand/dmg-background.tiff" "$volume/.background/background.tiff"
fi

volname="viTek"
dmg="$stage/$name.dmg"
# Give extra headroom so Finder can write .DS_Store cleanly before UDZO compression.
hdiutil create -volname "$volname" -srcfolder "$volume" -fs HFS+ -format UDRW -size 48m "$stage/edit.dmg" >/dev/null

# Attach with Finder visibility when interactive so AppleScript can lay out the 660x440 window.
attach_flags=(-readwrite -noverify)
if [[ "${CI:-}" == "true" ]]; then
  attach_flags+=(-nobrowse)
fi
attach_out="$(hdiutil attach "${attach_flags[@]}" "$stage/edit.dmg")"
device="$(printf '%s\n' "$attach_out" | awk '/\/Volumes\// {print $1; exit}')"
mount_dir="$(printf '%s\n' "$attach_out" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
mounted_vol="$(basename "$mount_dir")"

if [[ -d "$mount_dir/.background" ]]; then
  SetFile -a V "$mount_dir/.background"
fi

styled=0
if [[ "${CI:-}" != "true" ]] && [[ -f "$mount_dir/.background/background.tiff" ]]; then
  if osascript <<EOF >/dev/null 2>&1
tell application "Finder"
  tell disk "$mounted_vol"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 588}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 108
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "Cài viTek.app" of container window to {180, 236}
    set position of item "Applications" of container window to {480, 236}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
  then
    styled=1
  fi
fi

# Apply custom volume icon after Finder closes so Finder does not strip or reset it.
cp "$installer/Contents/Resources/AppIcon.icns" "$mount_dir/.VolumeIcon.icns"
SetFile -a V "$mount_dir/.VolumeIcon.icns"
SetFile -a C "$mount_dir"
[[ -s "$mount_dir/.VolumeIcon.icns" ]]
[[ "$(GetFileInfo -aC "$mount_dir")" == 1 ]]

# Fallback for headless CI runners: reuse pre-baked Finder layout .DS_Store if committed.
if [[ "$styled" == 0 ]] && [[ -s "$root/assets/brand/dmg-ds-store" ]]; then
  cp "$root/assets/brand/dmg-ds-store" "$mount_dir/.DS_Store"
fi
if [[ "${SAVE_DMG_DS_STORE:-0}" == 1 ]] && [[ -s "$mount_dir/.DS_Store" ]]; then
  cp "$mount_dir/.DS_Store" "$root/assets/brand/dmg-ds-store"
fi

chmod -Rf go-w "$mount_dir" 2>/dev/null || true
sync
hdiutil detach "$device" -quiet
device=""

hdiutil convert "$stage/edit.dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg" >/dev/null
if [[ "$mode" != --local && "$mode" != --adhoc ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$dmg"
  if [[ "${SKIP_NOTARIZE:-0}" != 1 ]]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
  fi
fi

(cd "$stage" && shasum -a 256 "$name.dmg" > "$name.dmg.sha256")
mv "$dmg" "$dmg.sha256" "$dist/"
echo "Built $dist/$name.dmg (styled=$styled)"
