cask "vitek" do
  version "20261125.1.002"
  sha256 :no_check

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
