// Client-side copy command & interactive Vietnamese Telex/VNI playground for viTek GitHub Pages.
(() => {
  'use strict';

  // --- Copy button (Invoker Commands + progressive fallback + VoiceOver repeat guard) ---
  const copyTimers = new WeakMap();
  let lastAnnouncement = '';

  function legacyCopy(text) {
    const previousFocus = document.activeElement;
    const field = Object.assign(document.createElement('textarea'), { value: text });
    field.setAttribute('readonly', '');
    field.style.cssText = 'position:fixed;inset-block-start:0;opacity:0';
    document.body.append(field);
    field.select();
    try {
      return document.execCommand('copy');
    } finally {
      field.remove();
      previousFocus?.focus({ preventScroll: true });
    }
  }

  function reportCopy(button, ok) {
    const tip = button.nextElementSibling;
    if (!tip) return;
    clearTimeout(copyTimers.get(button));
    button.removeAttribute('data-copied');
    button.removeAttribute('data-failed');
    let message = ok ? 'Đã sao chép' : 'Không sao chép được';
    if (message === lastAnnouncement) message += '\u00A0';
    lastAnnouncement = message;
    tip.textContent = '';
    void button.offsetWidth;
    button.setAttribute(ok ? 'data-copied' : 'data-failed', '');
    requestAnimationFrame(() => {
      tip.textContent = message;
    });
    copyTimers.set(button, setTimeout(() => {
      button.removeAttribute('data-copied');
      button.removeAttribute('data-failed');
      tip.textContent = '';
    }, 2000));
  }

  async function copyFromTarget(button, target) {
    if (!button || !target) return;
    const text = target.matches('input, textarea') ? target.value : target.innerText.trim();
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
      reportCopy(button, true);
    } catch {
      reportCopy(button, legacyCopy(text));
    }
  }

  document.addEventListener('command', (event) => {
    if (event.command === '--copy') {
      copyFromTarget(event.source, event.target);
    }
  }, true);

  if (!('CommandEvent' in window)) {
    document.addEventListener('click', (event) => {
      if (event.defaultPrevented) return;
      const button = event.target.closest('button[command^="--copy"]');
      if (!button) return;
      const target = document.getElementById(button.getAttribute('commandfor'));
      if (target) copyFromTarget(button, target);
    });
  }

  // --- Fetch latest GitHub release for download CTA ---
  const downloadLink = document.getElementById('download-dmg');
  const releasePill = document.getElementById('release-pill');
  fetch('https://api.github.com/repos/luongbinhf/viTek/releases/latest', {
    headers: { Accept: 'application/vnd.github+json' },
  })
    .then((res) => (res.ok ? res.json() : null))
    .then((data) => {
      if (!data || !data.tag_name) return;
      if (releasePill) releasePill.textContent = `Phiên bản ${data.tag_name}`;
      const dmg = Array.isArray(data.assets) ? data.assets.find((a) => a.name && a.name.endsWith('.dmg')) : null;
      if (downloadLink && dmg?.browser_download_url) {
        downloadLink.href = dmg.browser_download_url;
        downloadLink.textContent = `Tải viTek ${data.tag_name} (.DMG)`;
      }
    })
    .catch(() => {});

  // --- Lightweight client-side Vietnamese Telex & VNI playground ---
  const englishKeep = new Set([
    'reset', 'server', 'test', 'best', 'last', 'list', 'user', 'data', 'hello', 'boss', 'offer', 'office',
    'error', 'class', 'look', 'free', 'with', 'window', 'word', 'what', 'hello', 'issue', 'issues',
  ]);
  const tones = {
    a: ['a', 'á', 'à', 'ả', 'ã', 'ạ'],
    ă: ['ă', 'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'],
    â: ['â', 'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'],
    e: ['e', 'é', 'è', 'ẻ', 'ẽ', 'ẹ'],
    ê: ['ê', 'ế', 'ề', 'ể', 'ễ', 'ệ'],
    i: ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị'],
    o: ['o', 'ó', 'ò', 'ỏ', 'õ', 'ọ'],
    ô: ['ô', 'ố', 'ồ', 'ổ', 'ỗ', 'ộ'],
    ơ: ['ơ', 'ớ', 'ờ', 'ở', 'ỡ', 'ợ'],
    u: ['u', 'ú', 'ù', 'ủ', 'ũ', 'ụ'],
    ư: ['ư', 'ứ', 'ừ', 'ử', 'ữ', 'ự'],
    y: ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'],
  };
  const decodeVowel = new Map();
  for (const [base, forms] of Object.entries(tones)) {
    forms.forEach((ch, idx) => {
      decodeVowel.set(ch, { base, tone: idx, upper: false });
      decodeVowel.set(ch.toUpperCase(), { base, tone: idx, upper: true });
    });
  }

  const telexTone = { s: 1, f: 2, r: 3, x: 4, j: 5, z: 0 };
  const vniTone = { '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '0': 0 };

  let vietnameseEnabled = true;
  let modernTone = true;

  function applyToneAt(chars, idx, tone) {
    const info = decodeVowel.get(chars[idx]);
    if (!info) return false;
    const nextTone = info.tone === tone ? 0 : tone;
    const glyph = tones[info.base][nextTone];
    chars[idx] = info.upper ? glyph.toUpperCase() : glyph;
    return true;
  }

  function transformWord(raw, allowRestore) {
    if (!vietnameseEnabled || !raw || raw.length > 16) return raw;
    if (raw.includes('.') || raw.includes('_') || raw.includes('/') || raw.includes('@')) return raw;
    if (/[a-z][A-Z]/.test(raw) && !/[sfrxjzw]/i.test(raw.slice(-1))) return raw;
    if (allowRestore && englishKeep.has(raw.toLowerCase())) return raw;

    const chars = Array.from(raw);
    let tone = 0;
    const out = [];

    for (let i = 0; i < chars.length; i += 1) {
      const ch = chars[i];
      const lower = ch.toLowerCase();
      const upper = ch !== lower;

      if (lower === 'd' && out.length > 0 && out[out.length - 1].toLowerCase() === 'd') {
        out[out.length - 1] = out[out.length - 1] === 'D' ? 'Đ' : 'đ';
        continue;
      }
      if ((lower === 'a' || lower === 'e' || lower === 'o') && out.some((c) => decodeVowel.get(c)?.base === lower && decodeVowel.get(c)?.tone === 0)) {
        const prevIdx = out.findLastIndex((c) => decodeVowel.get(c)?.base === lower);
        if (prevIdx >= 0 && out.slice(prevIdx + 1).every((c) => /^[a-zà-ỹ]$/i.test(c))) {
          const circum = lower === 'a' ? 'â' : (lower === 'e' ? 'ê' : 'ô');
          out[prevIdx] = out[prevIdx] === out[prevIdx].toUpperCase() ? circum.toUpperCase() : circum;
          continue;
        }
      }
      if (lower === '6' && out.some((c) => ['a', 'e', 'o'].includes(decodeVowel.get(c)?.base))) {
        const idx = out.findLastIndex((c) => ['a', 'e', 'o'].includes(decodeVowel.get(c)?.base));
        const info = decodeVowel.get(out[idx]);
        const nextBase = info.base === 'a' ? 'â' : (info.base === 'e' ? 'ê' : 'ô');
        const g = tones[nextBase][info.tone];
        out[idx] = info.upper ? g.toUpperCase() : g;
        continue;
      }
      if ((lower === 'w' || lower === '7' || lower === '8')) {
        const targets = lower === '8' ? ['a'] : (lower === '7' ? ['o', 'u'] : ['a', 'o', 'u']);
        const idx = out.findLastIndex((c) => targets.includes(decodeVowel.get(c)?.base));
        if (idx >= 0) {
          const info = decodeVowel.get(out[idx]);
          const nextBase = info.base === 'a' ? 'ă' : (info.base === 'o' ? 'ơ' : 'ư');
          const g = tones[nextBase][info.tone];
          out[idx] = info.upper ? g.toUpperCase() : g;
          continue;
        }
        if (lower === 'w') {
          out.push(upper ? 'Ư' : 'ư');
          continue;
        }
      }
      if (lower === '9' && out.length > 0 && out[0].toLowerCase() === 'd') {
        out[0] = out[0] === 'D' ? 'Đ' : 'đ';
        continue;
      }
      if (telexTone[lower] !== undefined || vniTone[lower] !== undefined) {
        const hasVowel = out.some((c) => decodeVowel.has(c));
        if (hasVowel) {
          tone = telexTone[lower] ?? vniTone[lower];
          continue;
        }
      }
      out.push(ch);
    }

    if (tone > 0) {
      const vowelIndices = [];
      for (let i = 0; i < out.length; i += 1) {
        if (decodeVowel.has(out[i])) vowelIndices.push(i);
      }
      if (vowelIndices.length > 0) {
        let target = vowelIndices[0];
        const marked = vowelIndices.find((i) => ['ă', 'â', 'ê', 'ô', 'ơ', 'ư'].includes(decodeVowel.get(out[i])?.base));
        if (marked !== undefined) {
          target = marked;
        } else if (vowelIndices.length === 2) {
          const hasCoda = vowelIndices[1] < out.length - 1;
          const v0 = decodeVowel.get(out[vowelIndices[0]]).base;
          const v1 = decodeVowel.get(out[vowelIndices[1]]).base;
          const keepSecond = modernTone && ((v0 === 'o' && (v1 === 'a' || v1 === 'e')) || (v0 === 'u' && v1 === 'y'));
          target = (hasCoda || keepSecond) ? vowelIndices[1] : vowelIndices[0];
        } else if (vowelIndices.length >= 3) {
          target = vowelIndices[1];
        }
        applyToneAt(out, target, tone);
      }
    }
    return out.join('');
  }

  const inputEl = document.getElementById('playground-input');
  const toggleLangBtn = document.getElementById('toggle-lang');
  const toggleToneBtn = document.getElementById('toggle-tone');
  const clearBtn = document.getElementById('clear-playground');
  let rawBuffer = '';

  function renderPlayground() {
    if (!inputEl) return;
    const parts = rawBuffer.split(/(\s+)/);
    const rendered = parts.map((part, idx) => {
      if (/^\s+$/.test(part) || !part) return part;
      const isFinished = idx < parts.length - 1;
      return transformWord(part, isFinished);
    });
    inputEl.value = rendered.join('');
  }

  if (inputEl) {
    inputEl.addEventListener('keydown', (event) => {
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      if (event.key === 'Escape') {
        event.preventDefault();
        inputEl.value = rawBuffer;
        return;
      }
      if (event.key === 'Backspace') {
        event.preventDefault();
        rawBuffer = rawBuffer.slice(0, -1);
        renderPlayground();
        return;
      }
      if (event.key === 'Enter') {
        event.preventDefault();
        rawBuffer += '\n';
        renderPlayground();
        return;
      }
      if (event.key.length === 1) {
        event.preventDefault();
        rawBuffer += event.key;
        renderPlayground();
      }
    });

    inputEl.addEventListener('input', () => {
      rawBuffer = inputEl.value;
    });
  }

  // --- Bilingual VI <-> EN switch for GitHub Pages UI ---
  const translations = {
    vi: {
      skip: 'Bỏ qua điều hướng, tới nội dung chính',
      navAdvantages: 'Ưu điểm',
      navFeatures: 'Tính năng',
      navInstall: 'Cài đặt',
      perfPill: '0,88 µs p50 · Apple Silicon',
      heroTitle: 'Bộ gõ tiếng Việt <span class="gradient-text">100% Swift Native</span> cho hệ sinh thái Apple',
      heroLead: 'Lõi Swift 6 dùng chung cho <strong>macOS 14+</strong> và <strong>iOS / iPadOS 26+</strong>. Tự nhận Telex &amp; VNI theo từng từ, không cần quyền Trợ năng để gõ, không thu thập dữ liệu.',
      ctaDownload: 'Tải viTek cho macOS (.DMG)',
      ctaGithub: 'Xem mã nguồn trên GitHub',
      playHeading: 'Gõ thử Telex & VNI trực tiếp',
      playHint: 'Thử gõ Telex, VNI và từ tiếng Anh / code trong cùng một câu.',
      presetMix: 'Mẫu chuẩn',
      presetTone: 'Dấu mới/cũ',
      presetCode: 'Pha Việt–Anh',
      presetClear: 'Xoá',
      playNote: 'Nhấn <kbd>Esc</kbd> khi đang gõ một từ để hoàn tác ngay về phím gốc.',
      advTitle: 'Vì sao chọn viTek? — 6 Ưu điểm cốt lõi',
      adv1Title: '100% Swift 6 Native',
      adv1Desc: 'Một lõi thuần Swift dùng chung cho macOS, iOS và iPadOS; kiểm tra strict concurrency 0 cảnh báo.',
      adv2Title: 'Không cần Trợ năng để gõ',
      adv2Desc: 'Không cài global CGEventTap trên macOS và chạy sạch trên iOS kể cả khi tắt Truy cập đầy đủ.',
      adv3Title: 'Bảo vệ Tiếng Anh & Code',
      adv3Desc: 'Khử mơ hồ ngữ cảnh (been, soon, noon, lose) và Smart Bypass cho camelCase, snake_case, URL.',
      adv4Title: 'Ổn định trên Web & Electron',
      adv4Desc: 'DocumentSession xác minh vùng sửa trước khi chèn, không gửi Backspace giả trên Chrome và VS Code.',
      adv5Title: 'Tốc độ dưới micro-giây',
      adv5Desc: 'Chỉ mục vần O(1) đạt 0,88 µs p50 phím và 20,5 µs p50 gợi ý cục bộ trên Apple Silicon.',
      adv6Title: 'MIT Mở & Dữ liệu sạch',
      adv6Desc: 'Nguồn gốc sạch 100%, không sao chép từ bộ gõ khác, hỗ trợ cập nhật 1 chạm xác minh SHA-256.',
      featTitle: '4 Nhóm Tính năng Chuẩn hoá',
      feat1Title: '1. Bộ gõ Song ngữ & ANE Thông minh',
      feat1Desc: 'Tự nhận Telex & VNI từng từ, đổi mượt uô ↔ ươ, gõ nhanh viw/yw/uyw, mô hình ANE Core ML 20 KB nhận diện ngữ cảnh câu song ngữ ngoài luồng phím nóng và HUD Liquid Glass VI ↔ EN.',
      feat2Title: '2. Gõ tắt Thông minh, Ngữ nghĩa & Clipboard v2',
      feat2Desc: 'Tự động gợi ý tạo gõ tắt từ cụm hay gõ, tiên đoán Trigram + SemanticRanker (⌥ Space / ⌥ 1–5), Clipboard Liquid Glass Swift 27 (⌃⌥V macOS / 📋 iOS, tìm ngữ nghĩa không dấu) & đồng bộ iCloud.',
      feat3Title: '3. Tác vụ Nhanh ⌃⌥A & Apple Intelligence',
      feat3Desc: 'Bảng nổi ⌃⌥A tại con trỏ thay trực tiếp văn bản đang chọn bằng 5 chế độ Apple Intelligence @Generable trên thiết bị (Khôi phục dấu, Sửa đồng âm, Công sở) cùng TextConverter Unicode NFC.',
      feat4Title: '4. Bàn phím iOS, iPadOS & Màn hình Gập (Duo)',
      feat4Desc: 'Tự nhận diện tư thế KeyboardPosture: gõ một tay, Split Keyboard và Cầu nối trung tâm 3 chế độ (Rê con trỏ 2D, Numpad, Clipboard nhanh), vuốt xuống gõ số/ký hiệu & Magic Keyboard.',
      benchTitle: 'Hiệu năng đo thực tế trên Apple Silicon',
      benchCore: 'Lõi gõ phím viTek (p99)',
      benchPred: 'Gợi ý từ & Emoji cục bộ (p99)',
      benchFrame: 'Ngân sách 1 khung hình 120Hz (8.330 µs)',
      dmgTitle: 'Cài đặt macOS trực quan & Bắt đầu nhanh',
      dmgDesc: 'Khung cài đặt <code>.DMG</code> thiết kế trực quan phong cách Apple / Docker / GitHub: kéo <strong>Cài viTek</strong> vào <strong>Applications</strong>, mở lên để cài nguyên tử vào <code>~/Library/Input Methods</code> và bật nguồn nhập tức thì.',
      linkMac: 'Hướng dẫn macOS (DMG & Homebrew) →',
      linkIOS: 'Hướng dẫn iOS / iPadOS & TestFlight →',
      dmgCaption: 'Khung kéo thả DMG Retina đi kèm linh vật Cú Lạc viTek.',
      footerLicense: '<strong>viTek</strong> — Phát hành mã nguồn mở theo <a href="https://github.com/luongbinhf/viTek/blob/main/LICENSE">Giấy phép MIT</a>.',
      footerSec: 'Bảo mật',
      footerContrib: 'Đóng góp',
    },
    en: {
      skip: 'Skip navigation, go to main content',
      navAdvantages: 'Advantages',
      navFeatures: 'Features',
      navInstall: 'Install',
      perfPill: '0.88 µs p50 · Apple Silicon',
      heroTitle: '100% <span class="gradient-text">Swift Native</span> Vietnamese Input Method for Apple',
      heroLead: 'Shared pure Swift 6 core for <strong>macOS 14+</strong> and <strong>iOS / iPadOS 26+</strong>. Automatic per-word Telex &amp; VNI detection, zero Accessibility required to type, zero telemetry.',
      ctaDownload: 'Download viTek for macOS (.DMG)',
      ctaGithub: 'View Source on GitHub',
      playHeading: 'Live Telex & VNI Playground',
      playHint: 'Mix Telex, VNI, and English/code tokens freely inside a single sentence.',
      presetMix: 'Mix Sample',
      presetTone: 'Tone Style',
      presetCode: 'Mixed Code',
      presetClear: 'Clear',
      playNote: 'Press <kbd>Esc</kbd> mid-word to immediately revert to the raw typed keys.',
      advTitle: 'Why viTek? — 6 Core Advantages',
      adv1Title: '100% Swift 6 Native',
      adv1Desc: 'One shared pure-Swift core across macOS, iOS, and iPadOS under strict concurrency with zero warnings.',
      adv2Title: 'No Accessibility Required',
      adv2Desc: 'Zero global CGEventTap keyloggers on macOS; runs offline on iOS even with Full Access turned off.',
      adv3Title: 'English & Code Protection',
      adv3Desc: 'Context disambiguation (been, soon, noon, lose) and Smart Token Bypass for camelCase, snake_case, and URLs.',
      adv4Title: 'Rock-Solid on Web & Electron',
      adv4Desc: 'DocumentSession verifies UTF-16 ranges before editing — no synthetic Backspace hacks in Chrome or VS Code.',
      adv5Title: 'Sub-Microsecond Speed',
      adv5Desc: 'O(1) rime indexing achieves 0.88 µs keystroke p50 and 20.5 µs local prediction p50 on Apple Silicon.',
      adv6Title: 'MIT Open Source & SHA-256',
      adv6Desc: '100% clean-room provenance with zero copied code/wordlists, plus 1-click SHA-256 verified updates.',
      featTitle: '4 Standardized Feature Groups',
      feat1Title: '1. Smart Bilingual & ANE Engine',
      feat1Desc: 'Per-word Telex & VNI detection, smooth uô ↔ ươ switching, viw/yw/uyw Quick Telex, 20 KB ANE Core ML sentence context disambiguation, and 0 ms VI ↔ EN Liquid Glass HUD.',
      feat2Title: '2. Smart Macros, Semantic Ranking & Clipboard v2',
      feat2Desc: 'Collision-free shortcut mining from repeated phrases, Trigram + SemanticRanker prediction (⌥ Space / ⌥ 1–5), Swift 27 Liquid Glass Clipboard (⌃⌥V macOS / 📋 iOS), and iCloud sync.',
      feat3Title: '3. Cursor Quick Actions (⌃⌥A) & Apple Intelligence',
      feat3Desc: 'Floating ⌃⌥A palette replacing selected text in-place with 5 on-device @Generable Apple Intelligence modes (Restore Diacritics, Homophone Proofreader, Professional) and Unicode NFC tools.',
      feat4Title: '4. Adaptive iOS, iPadOS & Foldable (Duo) Keyboard',
      feat4Desc: 'Posture-aware KeyboardPosture layout: One-Handed mode, Split Keyboard, and 3-mode Center Bridge (2D trackpad, 3×4 numpad, quick clipboard), flick-down symbols, and Magic Keyboard support.',
      benchTitle: 'Measured Apple Silicon Performance',
      benchCore: 'viTek Core Engine (p99)',
      benchPred: 'Local Word & Emoji Prediction (p99)',
      benchFrame: '120Hz ProMotion Frame Budget (8,330 µs)',
      dmgTitle: 'Visual macOS Installer & Quick Start',
      dmgDesc: 'Intuitive Apple / Docker / GitHub style <code>.DMG</code>: drag <strong>Cài viTek</strong> into <strong>Applications</strong> and launch once to atomically install into <code>~/Library/Input Methods</code>.',
      linkMac: 'macOS Guide (DMG & Homebrew) →',
      linkIOS: 'iOS / iPadOS & TestFlight Guide →',
      dmgCaption: 'Retina drag-and-drop DMG installer featuring the viTek Lac Owl mascot.',
      footerLicense: '<strong>viTek</strong> — Open source under the <a href="https://github.com/luongbinhf/viTek/blob/main/LICENSE">MIT License</a>.',
      footerSec: 'Security',
      footerContrib: 'Contributing',
    },
  };

  let pageLang = 'vi';
  const siteLangBtn = document.getElementById('site-lang-toggle');
  siteLangBtn?.addEventListener('click', () => {
    pageLang = pageLang === 'vi' ? 'en' : 'vi';
    document.documentElement.lang = pageLang;
    siteLangBtn.textContent = pageLang === 'vi' ? 'EN' : 'VI';
    const dict = translations[pageLang];
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (key && dict[key]) el.innerHTML = dict[key];
    });
  });

  toggleLangBtn?.addEventListener('click', () => {
    vietnameseEnabled = !vietnameseEnabled;
    toggleLangBtn.textContent = vietnameseEnabled ? 'VI' : 'EN';
    toggleLangBtn.classList.toggle('chip-active', vietnameseEnabled);
    toggleLangBtn.setAttribute('aria-pressed', String(vietnameseEnabled));
    renderPlayground();
  });

  toggleToneBtn?.addEventListener('click', () => {
    modernTone = !modernTone;
    toggleToneBtn.textContent = modernTone ? 'Dấu mới: hoà' : 'Dấu cũ: hòa';
    toggleToneBtn.setAttribute('aria-pressed', String(modernTone));
    renderPlayground();
  });

  document.querySelectorAll('.preset-btn[data-keys]').forEach((btn) => {
    btn.addEventListener('click', () => {
      rawBuffer = btn.getAttribute('data-keys') || '';
      renderPlayground();
      inputEl?.focus();
    });
  });

  clearBtn?.addEventListener('click', () => {
    rawBuffer = '';
    renderPlayground();
    inputEl?.focus();
  });
})();
