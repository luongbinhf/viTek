#!/usr/bin/env bash
# Single source of truth for the version is ./VERSION (YYYYMMDD.X.YYY, docs/ARCHITECTURE.md §8).
# Apps/macOS/Config/Version.xcconfig keeps YYYYMMDD.X.YYY; Apps/iOS/Config/Version.xcconfig uses
# App Store Connect compliant unpadded integers (YYYYMMDD.X.Y).
#
#   scripts/version.sh show
#   scripts/version.sh check
#   scripts/version.sh bump build|release|date
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$root/VERSION"
macos_xcconfig="$root/Apps/macOS/Config/Version.xcconfig"
ios_xcconfig="$root/Apps/iOS/Config/Version.xcconfig"
pattern='^[0-9]{8}\.[0-9]+\.[0-9]{3}$'

die() { echo "version.sh: $*" >&2; exit 1; }

read_version() {
  [[ -f "$version_file" ]] || die "missing $version_file"
  tr -d '[:space:]' < "$version_file"
}

ios_version_for() {
  local ymd minor build
  IFS=. read -r ymd minor build <<< "$1"
  printf '%d.%d.%d' "$((10#$ymd))" "$((10#$minor))" "$((10#$build))"
}

write_version() {
  local v="$1"
  [[ "$v" =~ $pattern ]] || die "refusing to write malformed version '$v'"
  local ios_v; ios_v="$(ios_version_for "$v")"
  mkdir -p "$(dirname "$macos_xcconfig")" "$(dirname "$ios_xcconfig")"
  printf '%s\n' "$v" > "$version_file"
  printf 'MARKETING_VERSION = %s\nCURRENT_PROJECT_VERSION = %s\n' "$v" "$v" > "$macos_xcconfig"
  printf 'MARKETING_VERSION = %s\nCURRENT_PROJECT_VERSION = %s\n' "$ios_v" "$ios_v" > "$ios_xcconfig"
}

cmd_check() {
  local v; v="$(read_version)"
  [[ "$v" =~ $pattern ]] || die "VERSION '$v' is not YYYYMMDD.X.YYY"
  [[ -f "$macos_xcconfig" ]] || die "missing $macos_xcconfig"
  [[ -f "$ios_xcconfig" ]] || die "missing $ios_xcconfig"
  local expected_mac expected_ios ios_v
  ios_v="$(ios_version_for "$v")"
  expected_mac="$(printf 'MARKETING_VERSION = %s\nCURRENT_PROJECT_VERSION = %s\n' "$v" "$v")"
  expected_ios="$(printf 'MARKETING_VERSION = %s\nCURRENT_PROJECT_VERSION = %s\n' "$ios_v" "$ios_v")"
  [[ "$(cat "$macos_xcconfig")" == "$expected_mac" ]] || die "$macos_xcconfig does not match VERSION $v"
  [[ "$(cat "$ios_xcconfig")" == "$expected_ios" ]] || die "$ios_xcconfig does not match iOS version $ios_v"
  echo "$v"
}

cmd_bump() {
  local kind="${1:-}"
  local v; v="$(cmd_check)"
  local ymd minor build today
  IFS=. read -r ymd minor build <<< "$v"
  today="$(date +%Y%m%d)"
  case "$kind" in
    build)
      if (( 10#$today > 10#$ymd )); then
        ymd="$today"
        build=1
      else
        build=$((10#$build + 1))
        (( build <= 999 )) || die "build counter overflow; bump release instead"
      fi
      ;;
    release)
      if (( 10#$today > 10#$ymd )); then
        ymd="$today"
      fi
      minor=$((10#$minor + 1))
      build=1
      ;;
    date)
      (( 10#$today > 10#$ymd )) || die "VERSION date is already $ymd"
      ymd="$today"
      build=1
      ;;
    *) die "usage: bump build|release|date" ;;
  esac
  local next; next="$(printf '%08d.%d.%03d' "$((10#$ymd))" "$((10#$minor))" "$((10#$build))")"
  write_version "$next"
  echo "$v -> $next"
}

case "${1:-}" in
  show)  read_version; echo ;;
  check) cmd_check ;;
  bump)  cmd_bump "${2:-}" ;;
  *)     die "usage: version.sh show|check|bump build|release|date" ;;
esac
