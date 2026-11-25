#!/usr/bin/env bash
# Archives viTekMobile (including viTekKeyboard and viTekWidgets) for TestFlight / App Store Connect.
#
# Usage:
#   # 1. Verify unsigned iOS device Release archive locally (no Apple Developer credentials required):
#   scripts/archive_ios.sh --dry-run
#
#   # 2. Signed archive ready to open & distribute in Xcode Organizer:
#   DEVELOPMENT_TEAM=XXXXXXXXXX scripts/archive_ios.sh
#
#   # 3. Signed archive + direct upload to App Store Connect / TestFlight via API Key:
#   DEVELOPMENT_TEAM=XXXXXXXXXX \
#   ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
#   ASC_KEY_ID=XXXXXXXXXX \
#   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
#   scripts/archive_ios.sh --upload
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

mode="archive"
for arg in "$@"; do
  case "$arg" in
    --dry-run) mode="dry-run" ;;
    --upload)  mode="upload" ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "archive_ios.sh: unknown option '$arg'" >&2
      exit 1
      ;;
  esac
done

version="$(scripts/version.sh check)"
xcodegen generate --spec Apps/iOS/project.yml

archive="$root/build/viTekMobile-$version.xcarchive"
rm -rf "$archive"

if [[ "$mode" == "dry-run" ]]; then
  xcodebuild -project Apps/iOS/viTekMobile.xcodeproj \
    -scheme viTekMobile \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    archive
  echo "Verified unsigned iOS device archive: $archive"
  exit 0
fi

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your 10-character Apple Developer Team ID}"

auth_args=()
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  auth_args=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

xcodebuild -project Apps/iOS/viTekMobile.xcodeproj \
  -scheme viTekMobile \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  "${auth_args[@]}" \
  archive

echo "Archived: $archive"

if [[ "$mode" == "upload" ]]; then
  export_plist="$(mktemp -t vitek-export-options.XXXXXX.plist)"
  trap 'rm -f "$export_plist"' EXIT
  cp Apps/iOS/ExportOptions.plist "$export_plist"
  /usr/libexec/PlistBuddy -c "Add :teamID string $DEVELOPMENT_TEAM" "$export_plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :teamID $DEVELOPMENT_TEAM" "$export_plist"

  export_dir="$root/dist/ios-$version"
  rm -rf "$export_dir"

  xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportPath "$export_dir" \
    -exportOptionsPlist "$export_plist" \
    -allowProvisioningUpdates \
    "${auth_args[@]}"

  echo "Uploaded viTekMobile $version to App Store Connect."
else
  echo "Open in Xcode Organizer to upload:"
  echo "  open \"$archive\""
fi
