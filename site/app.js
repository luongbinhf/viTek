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
