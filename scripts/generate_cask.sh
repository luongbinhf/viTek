#!/usr/bin/env bash
# Generates a Homebrew Cask definition (Casks/vitek.rb) for a given viTek release version.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: scripts/generate_cask.sh <version> [sha256]" >&2
  exit 2
fi

version="$1"
if [[ $# -eq 2 && -n "$2" ]]; then
  sha_line="sha256 \"$2\""
else
  sha_line="sha256 :no_check"
fi

cat <<EOF
cask "vitek" do
  version "$version"
  $sha_line

  url "https://github.com/luongbinhf/viTek/releases/download/#{version}/viTek-#{version}.dmg"
  name "viTek"
  desc "100% Swift 6 Native Vietnamese input method for macOS"
  homepage "https://github.com/luongbinhf/viTek"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Cài viTek.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Cài viTek.app"],
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Input Methods/viTek.app",
    "~/Library/Preferences/io.github.luongbinhf.inputmethod.viTek.plist",
    "~/Library/Logs/viTek",
  ]

  caveats <<~EOS
    Mở "Cài viTek" trong Applications một lần để đăng ký và kích hoạt nguồn nhập tiếng Việt viTek.
  EOS
end
EOF
