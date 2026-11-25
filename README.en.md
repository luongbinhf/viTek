<div align="center">

<p>
  <img src="assets/brand/vitek-logo.png" alt="viTek Logo" width="96" height="96">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/brand/vitek-mascot.png" alt="viTek Lac Owl Mascot" width="112" height="112">
</p>

# viTek

**100% Swift 6 Native Vietnamese Input Method · MIT Open Source for Apple Silicon, iPhone & iPad**

**[🇻🇳 Tiếng Việt](README.md)** | **🇬🇧 English**

[Website & Live Demo](https://luongbinhf.github.io/viTek/) · [Releases](https://github.com/luongbinhf/viTek/releases) · [Docs](docs/README.md) · [Security](SECURITY.md) · [Changelog](CHANGELOG.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-0B66E4.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B%20%7C%20iOS%20%26%20iPadOS%2026%2B-053A8F.svg)](#getting-started)
[![Swift](https://img.shields.io/badge/Swift-6.0%20Strict-F05138.svg)](Package.swift)
[![Release](https://img.shields.io/badge/Release-20261125.1.003-F7B529.svg)](https://github.com/luongbinhf/viTek/releases)
[![Live Demo](https://img.shields.io/badge/GitHub%20Pages-Try%20Live-16A34A.svg)](https://luongbinhf.github.io/viTek/)

</div>

---

**viTek** is a **100% Swift 6 Native** Vietnamese input method built exclusively for **macOS 14+** and **iOS / iPadOS 26+**. The orthography engine (`VitekEngine`) and editing session (`VitekSession`) run completely on-device — zero FFI bridges, zero Accessibility permission required for typing, and zero telemetry.

Try typing `vieetj vie65t reset server userName github.com ` → expected result: **`việt việt reset server userName github.com `**.

## Why viTek? (6 Core Advantages)

1. **100% Swift 6 Native — Zero FFI Bridges:** One shared pure-Swift core across macOS, iOS, and iPadOS, compiled under `SWIFT_STRICT_CONCURRENCY = complete` with zero warnings.
2. **Type Without Accessibility (macOS) & Without Full Access (iOS):** Never installs a global `CGEventTap` keylogger; iOS keyboard runs completely offline with `RequestsOpenAccess = false`.
3. **Smart English & Code Protection:** Protects **304+ everyday English words**, disambiguates sentence context (`been`, `soon`, `noon`, `lose`, `as`/`á`), and applies **Smart Token Bypass** for `camelCase`, `snake_case`, URLs, emails, and `self.view`.
4. **Rock-Solid in Browsers & Electron:** `DocumentSession` verifies UTF-16 ranges before replacing text, supports Chrome/Safari/Spotlight inline autocomplete, and avoids synthetic Backspace hacks.
5. **Sub-Microsecond Speed on Apple Silicon:** Core engine latency **0.88 µs** p50 (**2.54 µs** p99); local word & emoji prediction **20.5 µs** p50 (**72.9 µs** p99) — over 100× faster than a 120Hz frame.
6. **MIT Open Source, Clean Data & SHA-256 Updates:** Strict clean-room provenance ([SOURCES.md](SOURCES.md)) and 1-click **SHA-256 verified** updates from GitHub Releases.

## Key Features

| Group | Capabilities |
|---|---|
| **1. Smart Bilingual Typing** | Per-word **Telex & VNI auto-detection** · Instant **`VI ↔ EN`** toggle (`⌥⌥` with macOS **Liquid Glass HUD** / `VI/EN` key on iOS) · Free tone placement, Modern (`hoà`) / Traditional (`hòa`) orthography, optional quick consonants · Post-word mark editing · Instant **`Esc`** raw-key undo · Per-app English auto-switch (Terminal, iTerm2, Warp, Ghostty, Alacritty, Kitty) & **Apple Focus Filter** |
| **2. Macros, Trigrams, Clipboard & iCloud** | Case-preserving text shortcuts (`ko` / `Ko` / `KO`), multi-line templates, dynamic **`{{date}}` / `{{time}}` / `{{datetime}}`**, **live shortcut expansion hints** while typing · Adaptive **1–3 word (`Trigram`) personal prediction** with **`⌥ Space` / `⌥ 1–5`** quick accept & bilingual Emoji search · **Clipboard Manager** (`⌃⌥V` Liquid Glass macOS popup & iOS **`📋`** picker, accent-insensitive search, pinned snippets, password-manager exclusion) · **iCloud sync** for settings, macros, pinned snippets & personal vocabulary |
| **3. Text Tools & Apple Ecosystem** | Pure-Swift `TextConverter` with auto legacy font repair (**`VNI Windows` / `TCVN3` → `Unicode NFC`**), accent stripping, and **`UPPER` / `lower` / `Title Case`** across macOS menu, Clipboard Manager, iOS **`Aa`** button, and **Apple Shortcuts** · **Apple Intelligence** (`FoundationModels`), Interactive Widgets & Control Center |
| **4. Adaptive iOS & iPadOS Keyboard** | Portrait **Left/Right One-Handed mode** · Landscape & iPad **Split Keyboard** · Flick-down keys for numbers & symbols · **Hardware / Magic Keyboard support** (`pressesBegan`) · URL/Email convenience keys, contextual Return key, continuous `⌫` hold-delete, Spacebar trackpad |

## Getting Started

<div align="center">
  <img src="assets/brand/dmg-background@2x.png" alt="viTek Visual macOS DMG Installer" width="600">
</div>

- **macOS (Homebrew Cask):**
  ```sh
  brew tap luongbinhf/vitek https://github.com/luongbinhf/viTek
  brew install --cask luongbinhf/vitek/vitek
  ```
- **macOS (Visual .DMG):** Download `viTek-20261125.1.003.dmg` from [GitHub Releases](https://github.com/luongbinhf/viTek/releases), drag **Cài viTek** to `Applications`, and open it once to register **viTek** (`🌐` or `⌃ Space`). See [macOS Install Guide](docs/INSTALL.md).
- **Build from Source (macOS):** Run `CONFIGURATION=Release scripts/install_dev.sh` (Apple Silicon, Xcode with macOS 26+ SDK, XcodeGen).
- **iPhone & iPad:** Run `xcodegen generate --spec Apps/iOS/project.yml`, build or follow [App Store / TestFlight Guide](docs/APPSTORE.md), and enable **viTek** in **Settings → General → Keyboard → Keyboards**.

## Versioning (`YYYYMMDD.X.YYY`) & Verification

- **Format:** `YYYYMMDD` (release date) · `X` (major release counter) · `YYY` (3-digit padded build for macOS/GitHub Releases, e.g. **`20261125.1.003`**; unpadded **`20261125.1.3`** for iOS App Store Connect).

```sh
scripts/version.sh check                  # Verify macOS, iOS & Casks/vitek.rb versions match
swift test                                # Run full unit test suite
swift run vitek "Tooi yeeu tieengs Vieetj"
swift run -c release vitek-bench          # Core engine benchmark (0.88 µs p50 / 2.54 µs p99)
swift run -c release vitek-prediction-bench # Prediction benchmark (20.5 µs p50 / 72.9 µs p99)
scripts/release.sh --local                # Build local test DMG
```

## Repository Structure

| Path | Responsibility |
|---|---|
| `Sources/VitekEngine` | Vietnamese orthography, Telex/VNI, bilingual disambiguation & Smart Bypass (pure Swift) |
| `Sources/VitekSession` | `DocumentSession`, `InputSession`, macros, predictions, `EmojiSuggestions`, `PersonalFrequency`, `TextConverter` |
| `Sources/vitek-*` | CLI (`vitek`), keystroke & prediction benchmarks, wordlist generator |
| `Apps/macOS` | InputMethodKit host (`viTek`), `VI ↔ EN` Liquid Glass HUD, Settings window, SHA-256 updater & `viTekInstaller` |
| `Apps/iOS` | `viTekMobile` host app, `viTekKeyboard` (`Aa` tools, hardware keyboard, Split/One-Handed UI), `viTekWidgets`, `UITests` |
| `Apps/Shared` | Apple Intelligence (`WritingView`), `AppIntents`, `CloudSettingsSync`, `IOSKeyboardSettings`, `BrandMascot`, Privacy Manifest |
| `Tests` | Engine/Session/Repository tests, Cocoa harness, Installer smoke test & macOS compatibility tests |
| `Casks` & `site` | Homebrew Cask (`Casks/vitek.rb`) & interactive GitHub Pages landing site (`site/`) |
| `assets/brand` & `scripts` | Lac Owl mascot, squircle logos, Retina DMG background & build/release/versioning scripts |
| `docs` | Architecture, engine spec, UX, install, App Store guide, roadmap & compatibility matrix |

## Contributing & License

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), [PRIVACY.md](PRIVACY.md), and [Documentation Index](docs/README.md).

**viTek** is released under the **[MIT License](LICENSE)** (`Copyright © 2026 Binh Luong / viTek Contributors`).
