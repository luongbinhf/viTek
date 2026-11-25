import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VitekEngine
import VitekSession

// MARK: Bắt đầu

struct WelcomePage: View {
    private var settings = SettingsStore.shared
    private var navigation = SettingsNavigation.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 18) {
                    BrandMascotView(size: 84)
                        .shadow(color: Color.blue.opacity(0.14), radius: 8, y: 3)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Xin chào từ viTek")
                                .font(.title3.weight(.semibold))
                            Text("MIT Open Source")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        Text("Bộ gõ tiếng Việt 100% Swift Native — tự nhận Telex & VNI, bảo vệ từ tiếng Anh và xử lý hoàn toàn trên máy.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            KeyCap("⌥ ⌥")
                            Text("Đổi VI ↔ EN")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("·").foregroundStyle(.tertiary)
                            KeyCap("Esc")
                            Text("Hoàn tác về phím gốc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                LabeledContent("1. Chọn nguồn nhập") { KeyCap("viTek") }
                Text("Mở menu nguồn nhập trên thanh menu, hoặc nhấn 🌐 hay ⌃ Space để chuyển sang viTek.")
                    .foregroundStyle(.secondary)
            }
            Section("2. Gõ tiếng Việt") {
                LabeledContent("Telex") { Example(keys: "vieetj", result: "việt") }
                LabeledContent("VNI") { Example(keys: "vie65t", result: "việt") }
            }
            Section("3. Viết xen tiếng Anh") {
                Example(keys: "reset server", result: "reset server")
                Text("Bạn có thể gõ cả hai ngôn ngữ trong cùng một câu.")
                    .foregroundStyle(.secondary)
            }
            Section("Cài đặt hiện tại") {
                setting(.typing, value: settings.toneStyle == .modern ? "Dấu kiểu mới · hoà" : "Dấu kiểu cũ · hòa")
                setting(.shortcuts, value: settings.shortcutsEnabled ? "\(settings.shortcutTable.count) gõ tắt" : "Đã tắt")
                setting(.dictionary, value: settings.keepEnglishWords ? "Giữ từ tiếng Anh" : "Đã tắt")
            }
        }
        .settingsForm()
    }

    private func setting(_ page: SettingsPage, value: String) -> some View {
        Button { navigation.page = page } label: {
            HStack {
                Label(page.title, systemImage: page.symbol)
                Spacer()
                Text(value).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Keys and the text they give, side by side.
struct Example: View {
    let keys: String
    let result: String

    var body: some View {
        HStack(spacing: 8) {
            Text(keys).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary).fixedSize()
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Text(result).font(.body.weight(.medium)).fixedSize()
        }
    }
}

// MARK: Kiểu gõ

/// Chrome and Electron apps tell viTek where the caret is only through the Accessibility API; without
/// that permission they get no suggestion bar.
struct CaretAccessRow: View {
    @State private var allowed = AccessibilityCaret.isAllowed

    var body: some View {
        LabeledContent {
            if allowed {
                Label("Đã cấp", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Cấp quyền…") { AccessibilityCaret.requestAccess() }
                    .glassButton()
            }
        } label: {
            Text("Thanh gợi ý theo con trỏ trong Chrome, Claude, Slack, VS Code")
            Text("Cần quyền Trợ năng: các ứng dụng này chỉ báo vị trí con trỏ qua Trợ năng. Chưa cấp thì không hiện thanh gợi ý trong chúng.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            allowed = AccessibilityCaret.isAllowed
        }
    }
}

struct TypingPage: View {
    @Bindable private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                DisclosureGroup("Bảng phím Telex") { KeyGuide(method: .telex) }
                DisclosureGroup("Bảng phím VNI") { KeyGuide(method: .vni) }
            }
            Section {
                Picker("Đặt dấu", selection: $settings.toneStyle) {
                    Text("Kiểu mới: hoà, khoẻ, thuý").tag(ToneStyle.modern)
                    Text("Kiểu cũ: hòa, khỏe, thúy").tag(ToneStyle.traditional)
                }
                Toggle("Nhấn đúp phím ⌥ Option để chuyển nhanh Việt ↔ Anh",
                       isOn: $settings.quickToggleOptionDoubleTap)
                Toggle("Hiện chỉ báo nhỏ khi chuyển nhanh Việt ↔ Anh",
                       isOn: $settings.showModeSwitchHUD)
            }
            Section {
                Toggle("Gợi ý từ", isOn: $settings.showSuggestions)
                HStack(spacing: 10) {
                    KeyCap("⌥ Space")
                    Text("chọn gợi ý đầu")
                    Text("·").foregroundStyle(.tertiary)
                    KeyCap("⌥ 1…5")
                    Text("chọn theo thứ tự")
                }
                .foregroundStyle(.secondary)
                if settings.showSuggestions {
                    CaretAccessRow()
                }
            } footer: {
                Footnote("Gợi ý lấy từ mô hình tiếng Việt có sẵn trong macOS, chạy ngay trên máy. "
                         + "Nếu thấy chữ xám chồng lên chữ đang gõ, hãy tắt \"Show inline predictive text\" "
                         + "trong System Settings → Keyboard → Input Sources → Edit.")
            }
            Section {
                Toggle("Gạch chân chữ đang gõ", isOn: $settings.underlineComposition)
            } footer: {
                Footnote("viTek ưu tiên chèn chữ đã chốt để tìm kiếm và gợi ý của ứng dụng phản hồi ngay. "
                         + "Chrome và VS Code có thể vẫn vẽ một vạch dưới chữ đang soạn cho đến khi bạn chốt từ bằng phím cách.")
            }
            Section {
                Toggle("Sửa từ vừa gõ", isOn: $settings.editPreviousWord)
                Example(keys: "viêt| + j", result: "việt")
            } footer: {
                Footnote("Con trỏ đứng ngay sau một từ, gõ phím dấu là sửa được từ đó, kể cả sau khi đã bấm dấu cách rồi xoá đi. "
                         + "Tắt nếu một ứng dụng nào đó hiển thị sai.")
            }
            Section {
                Toggle("Kiểm tra chính tả", isOn: $settings.spellCheck)
                Toggle("Trả lại phím đã gõ khi từ không phải tiếng Việt (server, express)",
                       isOn: $settings.restoreInvalidWords)
                    .disabled(!settings.spellCheck)
            } footer: {
                Footnote("Khi tắt kiểm tra chính tả, phím dấu luôn thêm dấu vào chữ gần nhất có thể nhận.")
            }
            Section {
                Toggle("Gõ nhanh iê bằng w (viw → viê, viwtj → việt)", isOn: $settings.quickTelexW)
                Toggle("w đứng riêng gõ ra ư (tw → tư)", isOn: $settings.standaloneW)
                Toggle("[ và ] gõ ra ơ và ư", isOn: $settings.bracketVowels)
                Toggle("Gõ tắt phụ âm đầu (cc→ch, gg→gi, kk→kh, nn→ng, pp→ph, qq→qu, tt→th)",
                       isOn: $settings.quickStartConsonants)
                Toggle("Gõ tắt phụ âm cuối (g→ng, h→nh, k→ch)",
                       isOn: $settings.quickEndConsonants)
            } header: {
                Text("Telex")
            } footer: {
                Footnote("Gõ tắt phụ âm giúp giảm số phím nhưng có thể trùng với một số từ tiếng Anh ngắn (vd: bag, cash, task).")
            }
        }
        .settingsForm()
    }
}

/// The modifier keys of an input method, in two columns.
struct KeyGuide: View {
    let method: InputMethod

    private var rows: [(keys: String, result: String)] {
        switch method {
        case .telex:
            [("s", "sắc  á"), ("f", "huyền  à"), ("r", "hỏi  ả"), ("x", "ngã  ã"), ("j", "nặng  ạ"),
             ("aa ee oo", "â ê ô"), ("aw ow uw", "ă ơ ư"), ("w", "ư"), ("dd", "đ"), ("z", "xoá dấu")]
        case .vni:
            [("1", "sắc  á"), ("2", "huyền  à"), ("3", "hỏi  ả"), ("4", "ngã  ã"), ("5", "nặng  ạ"),
             ("6", "â ê ô"), ("7", "ơ ư"), ("8", "ă"), ("9", "đ"), ("0", "xoá dấu")]
        }
    }

    var body: some View {
        let half = (rows.count + 1) / 2
        HStack(alignment: .top, spacing: 32) {
            column(rows.prefix(half))
            column(rows.dropFirst(half))
        }
    }

    private func column(_ rows: ArraySlice<(keys: String, result: String)>) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(Array(rows), id: \.keys) { row in
                GridRow {
                    KeyCap(row.keys)
                    Text(row.result)
                }
            }
        }
    }
}

// MARK: Thói quen gõ

struct TypingHabitsPage: View {
    @Bindable private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                Text("viTek nhận dấu Telex và VNI theo từng từ. Với những từ như as hoặc too, viTek ưu tiên cách gõ gần đây của bạn trong từng ứng dụng.")
                LabeledContent("Ứng dụng đã học", value: String(settings.typingScores.count))
                Button("Xóa thói quen của mọi ứng dụng", role: .destructive) { settings.forgetTypingHabits() }
                    .disabled(settings.typingScores.isEmpty)
                LabeledContent("Từ/cụm cá nhân đã học", value: String(settings.personalFrequency.totalCount))
                Toggle("Đồng bộ từ vựng cá nhân đã học qua iCloud", isOn: $settings.syncPersonalVocabularyICloud)
                Button("Xóa từ đã học", role: .destructive) { settings.forgetPersonalFrequency() }
                    .disabled(settings.personalFrequency.isEmpty)
            } footer: {
                Footnote("Điểm ưu tiên Telex và VNI và bộ nhớ 1–3 từ cá nhân giúp xếp hạng gợi ý chính xác hơn theo ngữ cảnh của bạn.")
            }

            Section {
                if settings.excludedBundleIDs.isEmpty {
                    Text("Chưa có ứng dụng nào được đặt mặc định tiếng Anh.").foregroundStyle(.secondary)
                } else {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(appDisplayName(for: bundleID))
                            Spacer()
                            Text(bundleID).font(.caption).foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                settings.excludedBundleIDs.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Thêm ứng dụng…", action: pickExcludedApp)
            } header: {
                Text("Ứng dụng luôn gõ tiếng Anh")
            } footer: {
                Footnote("Tự động tạm tắt dấu tiếng Việt trong các ứng dụng này (ví dụ Terminal) mà không cần quyền Trợ năng.")
            }
        }
        .settingsForm()
    }

    private func appDisplayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        }
        return name
    }

    private func pickExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              !settings.excludedBundleIDs.contains(bundleID) else { return }
        settings.excludedBundleIDs.append(bundleID)
    }
}

// MARK: Gõ tắt

struct ShortcutsPage: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var addingShortcut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("Bật gõ tắt", isOn: $settings.shortcutsEnabled)
                Toggle("Gõ tắt cả khi tắt tiếng Việt", isOn: $settings.shortcutsInEnglishMode)
                    .disabled(!settings.shortcutsEnabled)
                Toggle("Đồng bộ iCloud", isOn: $settings.iCloudSyncEnabled)
                Spacer()
                Text("\(settings.shortcutTable.count) gõ tắt đang dùng").foregroundStyle(.secondary)
            }
            // Plain Text, not Footnote: a vertically fixed size here makes NavigationSplitView measure
            // the page at zero width and grow it past the window.
            Text("Gõ chữ tắt rồi bấm dấu cách hoặc dấu câu để thay bằng cụm đầy đủ (hỗ trợ biến {{date}}, {{time}}, {{datetime}}). "
                 + "Chữ hoa theo cách bạn gõ: ko → không, Ko → Không, KO → KHÔNG.")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Chữ tắt").frame(width: 140, alignment: .leading)
                    Text("Thay bằng")
                    Spacer()
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($settings.shortcuts) { $shortcut in
                            HStack(spacing: 12) {
                                TextField("vd. ko", text: $shortcut.abbreviation)
                                    .accessibilityLabel("Chữ tắt")
                                    .frame(width: 140)
                                TextField("vd. không", text: $shortcut.expansion)
                                    .accessibilityLabel("Cụm thay thế")
                                Button(role: .destructive) {
                                    let id = shortcut.id
                                    settings.shortcuts.removeAll { $0.id == id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Xóa gõ tắt \(shortcut.abbreviation)")
                                .help("Xóa dòng này")
                            }
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay {
                    if settings.shortcuts.isEmpty {
                        Text("Chọn “Thêm gõ tắt” để tạo chữ tắt đầu tiên.").foregroundStyle(.secondary)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
            HStack {
                Button {
                    addingShortcut = true
                } label: {
                    Label("Thêm gõ tắt", systemImage: "plus")
                }
                Spacer()
                Button("Nhập từ tệp…", action: importFile)
                Button("Xuất ra tệp…", action: exportFile)
                    .disabled(!settings.shortcutEntries.contains { !$0.abbreviation.isEmpty && !$0.expansion.isEmpty })
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .sheet(isPresented: $addingShortcut) {
            NewShortcutForm { entry in
                settings.importShortcuts([entry])
            }
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .commaSeparatedText]
        panel.message = "Hỗ trợ định dạng viTek (Tab/dấu cách), UniKey/OpenKey (chữ:thay bằng) và CSV."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        do {
            let parsed = ShortcutFile.parse(try String(contentsOf: url, encoding: .utf8))
            let result = settings.importShortcuts(parsed.entries)
            alert.messageText = "Đã nhập \(result.added) gõ tắt mới, cập nhật \(result.replaced) gõ tắt."
            if !parsed.rejectedLines.isEmpty {
                let lines = parsed.rejectedLines.prefix(10).map(String.init).joined(separator: ", ")
                alert.informativeText = "Bỏ qua \(parsed.rejectedLines.count) dòng không đúng định dạng: \(lines)"
                    + (parsed.rejectedLines.count > 10 ? "…" : "")
            }
        } catch {
            alert.alertStyle = .warning
            alert.messageText = "Không đọc được tệp."
            alert.informativeText = "Tệp phải là văn bản UTF-8. \(error.localizedDescription)"
        }
        alert.runModal()
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "viTek gõ tắt.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ShortcutFile.format(settings.shortcutEntries).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// Keep an unfinished new shortcut local until both fields are ready.
private struct NewShortcutForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var abbreviation = ""
    @State private var expansion = ""
    let save: (ShortcutEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thêm gõ tắt").font(.title2.bold())
            Form {
                TextField("Chữ tắt", text: $abbreviation, prompt: Text("vd. ko"))
                TextField("Thay bằng", text: $expansion, prompt: Text("vd. không"))
            }
            Text("Nhập chữ tắt đã có để cập nhật cụm thay thế.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lưu") {
                    save(ShortcutEntry(abbreviation: abbreviation, expansion: expansion))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(abbreviation.isEmpty || abbreviation.contains(where: \.isWhitespace) || expansion.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// MARK: Từ điển

struct DictionaryPage: View {
    @Bindable private var settings = SettingsStore.shared

    @State private var query = ""
    @State private var newWord = ""

    private var matches: [String] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? EnglishWords.all : EnglishWords.all.filter { $0.localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Giữ nguyên từ tiếng Anh thông dụng", isOn: $settings.keepEnglishWords)
            } footer: {
                Footnote(settings.keepEnglishWords
                    ? "Gõ test để giữ nguyên từ tiếng Anh, hoặc tets để viết tét. Tự động bỏ qua dấu cho camelCase, snake_case, URL và email."
                    : "Đã tắt giữ từ tiếng Anh. Bạn vẫn có thể tra danh sách bên dưới.")
            }
            Section("Từ ngoại lệ cá nhân") {
                HStack {
                    TextField("Thêm từ không đặt dấu (vd: viTek, NextJS)", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                    Button("Thêm") {
                        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !word.isEmpty, !word.contains(" "),
                              !settings.customEnglishWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame })
                        else { return }
                        settings.customEnglishWords.append(word)
                        newWord = ""
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newWord.contains(" "))
                }
                if !settings.customEnglishWords.isEmpty {
                    ForEach(settings.customEnglishWords, id: \.self) { word in
                        HStack {
                            Text(word).font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                settings.customEnglishWords.removeAll { $0 == word }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            Section("Tra từ tiếng Anh") {
                TextField("Tìm trong \(EnglishWords.all.count) từ", text: $query)
                    .textFieldStyle(.roundedBorder)
                let words = matches
                if words.isEmpty {
                    Text("Không tìm thấy từ phù hợp.").foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), alignment: .leading)], alignment: .leading, spacing: 6) {
                        ForEach(words, id: \.self) { Text($0).font(.system(.callout, design: .monospaced)) }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .settingsForm()
    }
}

// MARK: Clipboard

struct ClipboardPage: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var newPinned = ""
    @State private var query = ""

    private var filteredItems: [ClipboardItem] {
        settings.clipboardHistory.search(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Toggle("Lưu lịch sử Clipboard", isOn: $settings.clipboardHistoryEnabled)
                Toggle("Ghim qua iCloud", isOn: $settings.syncClipboardPinnedICloud)
                Toggle("Mục gần đây qua iCloud", isOn: $settings.syncClipboardRecentICloud)
                Spacer()
                HStack(spacing: 4) {
                    KeyCap("⌃ ⌥ V")
                    Text("mở dán nhanh")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                TextField("Thêm mẫu văn bản ghim cố định (vd: email, số tài khoản, chữ ký)…", text: $newPinned)
                    .textFieldStyle(.roundedBorder)
                Button("Ghim mẫu") {
                    let text = newPinned.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    settings.addPinnedClipboard(text)
                    newPinned = ""
                }
                .disabled(newPinned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextField("Tìm kiếm trong Clipboard (có dấu hoặc không dấu)…", text: $query)
                .textFieldStyle(.roundedBorder)

            let items = filteredItems
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items, id: \.text) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isPinned ? "pin.fill" : "doc.on.clipboard")
                                .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
                                .frame(width: 18)
                            Text(item.preview)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Chép") {
                                ClipboardMonitor.copyToPasteboard(item.text)
                            }
                            .buttonStyle(.borderless)
                            Menu("Chuyển mã") {
                                Button("Sửa lỗi font → Unicode") {
                                    ClipboardMonitor.copyToPasteboard(TextConverter.convert(item.text, mode: .autoToUnicode))
                                }
                                Button("Bỏ dấu tiếng Việt") {
                                    ClipboardMonitor.copyToPasteboard(TextConverter.convert(item.text, mode: .stripAccents))
                                }
                                Button("CHỮ HOA") {
                                    ClipboardMonitor.copyToPasteboard(TextConverter.convert(item.text, mode: .uppercase))
                                }
                                Button("Viết Hoa Đầu Từ") {
                                    ClipboardMonitor.copyToPasteboard(TextConverter.convert(item.text, mode: .titleCase))
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            Button {
                                settings.togglePinClipboard(item.text)
                            } label: {
                                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            }
                            .buttonStyle(.borderless)
                            .help(item.isPinned ? "Bỏ ghim" : "Ghim lên đầu")
                            Button(role: .destructive) {
                                settings.removeClipboard(item.text)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
            .overlay {
                if items.isEmpty {
                    Text(settings.clipboardHistory.isEmpty
                         ? "Chưa có mục Clipboard nào. Dữ liệu nhạy cảm từ trình quản lý mật khẩu luôn được bỏ qua."
                         : "Không tìm thấy mục phù hợp.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }

            HStack {
                Text("\(settings.clipboardHistory.pinnedItems.count) ghim · \(settings.clipboardHistory.unpinnedItems.count) gần đây")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Xoá mục chưa ghim") {
                    settings.clearUnpinnedClipboard()
                }
                .disabled(settings.clipboardHistory.unpinnedItems.isEmpty)
                Button("Xoá tất cả", role: .destructive) {
                    settings.clearAllClipboard()
                }
                .disabled(settings.clipboardHistory.isEmpty)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
}

// MARK: Giới thiệu

struct AboutPage: View {
    @AppStorage("diagnostics") private var diagnosticsEnabled = false
    @State private var connectionStatus: String?
    @State private var checkingConnection = false
    @State private var updateStatus: UpdateChecker.Status?
    @State private var checkingUpdate = false
    @State private var installingUpdate = false
    @State private var installProgress: String?
    @State private var installError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    MacAppIcon(size: 62)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("viTek").font(.title3.weight(.semibold))
                            Text("MIT Open Source")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        Text("Bộ gõ tiếng Việt 100% Swift Native cho macOS, iOS & iPadOS")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    BrandMascotView(size: 64)
                }
                .padding(.vertical, 4)
            }
            Section {
                LabeledContent("Phiên bản") { Text(version).monospacedDigit().textSelection(.enabled) }
                HStack {
                    Button(checkingUpdate ? "Đang kiểm tra…" : "Kiểm tra bản cập nhật…") {
                        checkUpdate()
                    }
                    .disabled(checkingUpdate || installingUpdate)
                    Spacer()
                    switch updateStatus {
                    case .upToDate:
                        Label("Đang dùng bản mới nhất", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    case .updateAvailable(let latest, let pageURL, let dmgURL, let sha256URL):
                        HStack(spacing: 8) {
                            if let dmgURL {
                                Button(installingUpdate ? (installProgress ?? "Đang cập nhật…") : "Cập nhật bản \(latest)") {
                                    installUpdate(dmgURL: dmgURL, sha256URL: sha256URL)
                                }
                                .disabled(installingUpdate)
                            }
                            Button("Mở trang tải…") {
                                NSWorkspace.shared.open(pageURL)
                            }
                            .disabled(installingUpdate)
                        }
                    case .failed(let message):
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    case nil:
                        EmptyView()
                    }
                }
                if let installError {
                    Text(installError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                LabeledContent("Nguồn nhập") { Text("Vietnamese → viTek") }
                LabeledContent("Đổi nguồn nhập") { Text("🌐 hoặc ⌃ Space") }
            }
            Section("Kết nối & Chẩn đoán") {
                HStack {
                    Button(checkingConnection ? "Đang kiểm tra…" : "Kiểm tra kết nối bộ gõ") {
                        checkConnection()
                    }
                    .disabled(checkingConnection)
                    if let connectionStatus {
                        Spacer()
                        Text(connectionStatus)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Ghi nhật ký chẩn đoán (không ghi chữ đang gõ)", isOn: $diagnosticsEnabled)
                Button("Mở thư mục nhật ký") {
                    let dir = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Logs/viTek")
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(dir)
                }
            }
            Section("Mã nguồn mở & Giấy phép") {
                HStack(spacing: 12) {
                    if let repoURL = URL(string: "https://github.com/luongbinhf/viTek") {
                        Link(destination: repoURL) {
                            Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    if let issuesURL = URL(string: "https://github.com/luongbinhf/viTek/issues") {
                        Link(destination: issuesURL) {
                            Label("Báo lỗi & Đóng góp", systemImage: "ladybug")
                        }
                    }
                    if let licenseURL = URL(string: "https://github.com/luongbinhf/viTek/blob/main/LICENSE") {
                        Link(destination: licenseURL) {
                            Label("Giấy phép MIT", systemImage: "doc.text")
                        }
                    }
                }
                Text("Copyright © 2026 Binh Luong (viTek Contributors). Phát hành mã nguồn mở theo giấy phép MIT.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsForm()
    }

    private func checkConnection() {
        checkingConnection = true
        connectionStatus = nil
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? version
        let bundleURL = Bundle.main.bundleURL
        Task { @MainActor in
            defer { checkingConnection = false }
            let ok = (try? await InputMethodConnection.check(version: bundleVersion, bundleURL: bundleURL, timeout: .seconds(3))) ?? false
            connectionStatus = ok ? "Đang hoạt động · \(bundleVersion)" : "Chưa phản hồi (hãy chọn lại viTek)"
        }
    }

    private func checkUpdate() {
        checkingUpdate = true
        updateStatus = nil
        installError = nil
        let current = version
        Task { @MainActor in
            defer { checkingUpdate = false }
            updateStatus = await UpdateChecker.check(currentVersion: current)
        }
    }

    private func installUpdate(dmgURL: URL, sha256URL: URL?) {
        installingUpdate = true
        installError = nil
        installProgress = "Đang tải bản cập nhật…"
        Task { @MainActor in
            defer {
                installingUpdate = false
                installProgress = nil
            }
            do {
                try await UpdateChecker.downloadAndLaunchInstaller(dmgURL: dmgURL, sha256URL: sha256URL) { message in
                    installProgress = message
                }
            } catch {
                installError = error.localizedDescription
            }
        }
    }
}
