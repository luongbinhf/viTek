import SwiftUI
import UIKit
import VitekEngine
import VitekSession

@main
struct ViTekApp: App {
    @Bindable private var route = WritingRoute.shared

    private var selectedTab: Binding<WritingRoute.Destination> {
        Binding(
            get: { route.destination == .settings ? .settings : .keyboard },
            set: { route.destination = $0 }
        )
    }

    private var showingWritingSheet: Binding<Bool> {
        Binding(
            get: { route.destination == .writing },
            set: { if !$0 { route.destination = .keyboard } }
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: selectedTab) {
                Tab("Bàn phím", systemImage: "keyboard", value: WritingRoute.Destination.keyboard) {
                    KeyboardGuide()
                }
                Tab("Cài đặt", systemImage: "gearshape", value: WritingRoute.Destination.settings) {
                    KeyboardSettingsView()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .sheet(isPresented: showingWritingSheet) {
                WritingView()
            }
            .onOpenURL { route.handle($0) }
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-tab"), args.indices.contains(idx + 1) {
                    switch args[idx + 1] {
                    case "keyboard": route.destination = .keyboard
                    case "writing": route.destination = .writing
                    case "settings": route.destination = .settings
                    default: break
                    }
                }
                CloudSettingsSync.shared.start()
                await VitekFocusFilter.refreshCurrent()
            }
        }
    }
}

// MARK: - Reusable iOS 26 Settings Icon Badge

private struct SettingsBadgeIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Tab 1: Bàn phím (Minimal Setup & Live Typing Test)

private struct KeyboardGuide: View {
    @Environment(\.openURL) private var openURL
    @State private var sample = ProcessInfo.processInfo.arguments.contains("-focusSandbox")
        ? "Tôi yêu tiếng Việt — gõ Telex & VNI mượt mà cùng viTek"
        : ""
    @FocusState private var sandboxFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Thử gõ vieetj", text: $sample, axis: .vertical)
                        .focused($sandboxFocused)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Gõ thử")
                } footer: {
                    Text("Tự nhận Telex (vieetj → việt) và VNI (vie65t → việt). Chạm 🌐 để chuyển sang viTek tại mọi ô nhập liệu.")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("Mở Cài đặt Bàn phím", systemImage: "keyboard.badge.ellipsis")
                            .font(.body.weight(.semibold))
                    }
                    LabeledContent("1. Thêm bàn phím", value: "Bàn phím → viTek")
                    LabeledContent("2. Quyền riêng tư", value: "Không cần Truy cập đầy đủ")
                } header: {
                    Text("Kích hoạt bàn phím")
                } footer: {
                    Text("viTek chạy hoàn toàn trên thiết bị để hỗ trợ gõ tiếng Việt trong mọi ứng dụng.")
                }
            }
            .navigationTitle("viTek")
            .task {
                if ProcessInfo.processInfo.arguments.contains("-focusSandbox") {
                    try? await Task.sleep(for: .milliseconds(500))
                    sandboxFocused = true
                }
            }
        }
    }
}

// MARK: - Tab 4: Cài đặt (Apple iOS 26 Icon-Grouped Settings)

private struct KeyboardSettingsView: View {
    @Bindable private var settings = IOSKeyboardSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $settings.toneStyle) {
                        Text("Kiểu mới (hoà, thuý)").tag(ToneStyle.modern)
                        Text("Kiểu cũ (hòa, thúy)").tag(ToneStyle.traditional)
                    } label: {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "textformat", tint: .blue)
                            Text("Kiểu đặt dấu")
                        }
                    }

                    Toggle(isOn: $settings.spellCheck) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "checkmark.seal.fill", tint: .green)
                            Text("Kiểm tra chính tả tiếng Việt")
                        }
                    }

                    Toggle(isOn: $settings.restoreInvalidWords) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "arrow.uturn.backward.circle.fill", tint: .teal)
                            Text("Khôi phục phím khi từ không hợp lệ")
                        }
                    }
                    .disabled(!settings.spellCheck)

                    Toggle(isOn: $settings.keepEnglishWords) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "globe.americas.fill", tint: .indigo)
                            Text("Bảo vệ từ tiếng Anh thông dụng")
                        }
                    }

                    Toggle(isOn: $settings.smartTypoRecovery) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "wand.and.rays", tint: .orange)
                            Text("Sửa đảo phím khi gõ nhanh (tieegns → tiếng)")
                        }
                    }
                    .disabled(!settings.spellCheck)

                    NavigationLink {
                        IOSCustomWordsView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "character.book.closed.fill", tint: .purple)
                            LabeledContent("Từ ngoại lệ cá nhân", value: "\(settings.customEnglishWords.count)")
                        }
                    }
                    .accessibilityIdentifier("settings.customWords")
                } header: {
                    Text("Bộ gõ & Chính tả")
                } footer: {
                    Text("viTek tự nhận Telex và VNI theo từng từ, hỗ trợ đổi mượt uô ↔ ươ và gõ nhanh viw / yw / uyw.")
                }

                Section {
                    Toggle(isOn: $settings.shortcutsEnabled) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "bolt.horizontal.fill", tint: .orange)
                            Text("Bật gõ tắt thông minh")
                        }
                    }
                    Toggle("Mở rộng gõ tắt cả khi đang ở chế độ EN", isOn: $settings.shortcutsInEnglishMode)
                        .disabled(!settings.shortcutsEnabled)

                    NavigationLink {
                        IOSShortcutsView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "list.bullet.rectangle.portrait.fill", tint: .pink)
                            LabeledContent("Bảng gõ tắt & Gợi ý tự động", value: "\(settings.shortcutTable.count)")
                        }
                    }
                    .accessibilityIdentifier("settings.shortcuts")

                    Toggle("Gõ tắt phụ âm đầu (cc, gg, kk, nn, pp, qq, tt)", isOn: $settings.quickStartConsonants)
                    Toggle("Gõ tắt phụ âm cuối (g→ng, h→nh, k→ch)", isOn: $settings.quickEndConsonants)
                } header: {
                    Text("Gõ tắt & Tốc ký")
                } footer: {
                    Text("Hỗ trợ biến động {{date}}, {{time}}, {{datetime}} và tự gợi ý chữ tắt từ cụm từ bạn hay gõ.")
                }

                Section {
                    Picker(selection: $settings.oneHandedMode) {
                        Text("Đầy đủ").tag(IOSKeyboardSettings.OneHandedMode.full)
                        Text("Tay trái").tag(IOSKeyboardSettings.OneHandedMode.left)
                        Text("Tay phải").tag(IOSKeyboardSettings.OneHandedMode.right)
                    } label: {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "keyboard.onehanded.right", tint: .cyan)
                            Text("Bố cục một tay (dọc)")
                        }
                    }

                    Toggle(isOn: $settings.showSuggestions) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "sparkles.rectangle.stack.fill", tint: .blue)
                            Text("Thanh gợi ý từ thông minh")
                        }
                    }

                    Toggle(isOn: $settings.flickDownSymbols) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "arrow.down.square.fill", tint: .mint)
                            Text("Vuốt xuống phím chữ gõ số & ký hiệu")
                        }
                    }

                    Toggle(isOn: $settings.glideTypingEnabled) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "scribble.variable", tint: .cyan)
                            Text("Gõ lướt nối chữ tiếng Việt (Glide Typing)")
                        }
                    }

                    Toggle("Hiển thị hàng phím số riêng phía trên", isOn: $settings.showNumberRow)
                    Toggle("Tự viết hoa chữ cái đầu câu", isOn: $settings.autoCapitalization)
                    Toggle("Nhấn đúp dấu cách chèn dấu chấm", isOn: $settings.doubleSpacePeriod)
                    Toggle("Phản hồi rung xúc giác nhẹ (Haptics)", isOn: $settings.hapticFeedback)
                    Toggle("Âm thanh bấm phím hệ thống", isOn: $settings.keyClickSound)
                } header: {
                    Text("Giao diện & Cảm giác gõ")
                } footer: {
                    Text("Tất cả phím được căn chỉnh đồng nhất kích thước chuẩn iOS 26 Liquid Glass với độ trễ phản hồi chạm 0 ms.")
                }

                Section {
                    Toggle(isOn: $settings.splitLandscapeKeyboard) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "rectangle.split.2x1.fill", tint: .indigo)
                            Text("Chia đôi bàn phím trên màn rộng / Duo")
                        }
                    }
                    Picker(selection: $settings.duoCenterBridgeMode) {
                        ForEach(DuoBridgeMode.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.symbolName).tag(mode)
                        }
                    } label: {
                        Text("Cầu nối trung tâm (khi chia đôi)")
                    }
                    Toggle("Lặp phím ranh giới G & B hai bên", isOn: $settings.duoDuplicateBoundaryKeys)
                    Picker("Gõ một tay trên màn ngoài gọn", selection: $settings.coverOneHandedMode) {
                        Text("Đầy đủ").tag(IOSKeyboardSettings.OneHandedMode.full)
                        Text("Tay trái").tag(IOSKeyboardSettings.OneHandedMode.left)
                        Text("Tay phải").tag(IOSKeyboardSettings.OneHandedMode.right)
                    }
                } header: {
                    Text("iPad & Màn hình gập iPhone Duo")
                }

                Section {
                    Toggle(isOn: $settings.iCloudSyncEnabled) {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "icloud.fill", tint: .blue)
                            Text("Đồng bộ cài đặt & gõ tắt qua iCloud")
                        }
                    }
                    Toggle("Đồng bộ mẫu Clipboard đã ghim", isOn: $settings.syncClipboardPinnedICloud)
                        .disabled(!settings.iCloudSyncEnabled)
                    Toggle("Đồng bộ Clipboard gần đây", isOn: $settings.syncClipboardRecentICloud)
                        .disabled(!settings.iCloudSyncEnabled)
                    Toggle("Đồng bộ từ vựng cá nhân đã học", isOn: $settings.syncPersonalVocabularyICloud)
                        .disabled(!settings.iCloudSyncEnabled)
                    LabeledContent("Từ/cụm cá nhân đã học", value: "\(settings.personalFrequency.totalCount)")
                    Button("Xóa từ vựng cá nhân đã học", role: .destructive) {
                        settings.forgetPersonalFrequency()
                    }
                    .disabled(settings.personalFrequency.isEmpty)
                } header: {
                    Text("iCloud")
                }

                Section {
                    NavigationLink {
                        IOSClipboardView()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsBadgeIcon(symbol: "doc.on.clipboard.fill", tint: .teal)
                            LabeledContent("Mẫu Clipboard đã ghim", value: "\(settings.clipboardHistory.items.count)")
                        }
                    }
                    Toggle("Đồng bộ qua iCloud", isOn: $settings.iCloudSyncEnabled)
                } header: {
                    Text("Clipboard & iCloud")
                }

                Section {
                    LabeledContent("Phiên bản", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
                    LabeledContent("ANE Ngữ cảnh", value: NeuralContextScorer.shared.statusSummary)
                    LabeledContent("Apple Intelligence", value: WritingSuggestion.readiness().canGenerate ? "Sẵn sàng trên thiết bị" : "Theo cài đặt máy")
                    LabeledContent("Giấy phép", value: "MIT Open Source")
                    if let repoURL = URL(string: "https://github.com/luongbinhf/viTek") {
                        Link(destination: repoURL) {
                            Label("Mã nguồn trên GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                } header: {
                    Text("Giới thiệu")
                }
            }
            .navigationTitle("Cài đặt")
        }
    }
}

// MARK: - Shortcuts, Custom Words & Clipboard Views

private struct IOSShortcutsView: View {
    @Bindable private var settings = IOSKeyboardSettings.shared
    @State private var abbreviation = ""
    @State private var expansion = ""
    @State private var showingImport = false
    @State private var importText = ""
    @State private var importSummary: String?

    private var smartSuggestions: [SuggestedShortcut] {
        let existingAbbr = Set(settings.shortcuts.map { $0.abbreviation.trimmingCharacters(in: .whitespaces).lowercased() })
        let existingExp = Set(settings.shortcuts.map { $0.expansion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return settings.personalFrequency.suggestedShortcuts(
            excluding: existingAbbr,
            existingExpansions: existingExp,
            minCount: 4,
            limit: 5
        )
    }

    var body: some View {
        List {
            let suggestions = smartSuggestions
            if !suggestions.isEmpty {
                Section("Gợi ý tự động từ thói quen gõ") {
                    ForEach(suggestions, id: \.abbreviation) { item in
                        Button {
                            settings.importShortcuts([ShortcutEntry(abbreviation: item.abbreviation, expansion: item.phrase)])
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text(item.abbreviation)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(item.phrase)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(item.count)×")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Thêm gõ tắt") {
                TextField("Chữ tắt (vd: ko)", text: $abbreviation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Thay bằng (vd: không)", text: $expansion)
                Button {
                    let key = abbreviation.trimmingCharacters(in: .whitespaces)
                    let value = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty, !key.contains(" "), !value.isEmpty else { return }
                    settings.importShortcuts([ShortcutEntry(abbreviation: key, expansion: value)])
                    abbreviation = ""
                    expansion = ""
                } label: {
                    Label("Thêm gõ tắt", systemImage: "plus.circle.fill")
                }
                .disabled(abbreviation.trimmingCharacters(in: .whitespaces).isEmpty ||
                          abbreviation.contains(" ") ||
                          expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Danh sách (\(settings.shortcuts.count))") {
                if settings.shortcuts.isEmpty {
                    Text("Chưa có gõ tắt nào.").foregroundStyle(.secondary)
                } else {
                    ForEach(settings.shortcuts) { item in
                        HStack {
                            Text(item.abbreviation)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                            Spacer()
                            Text(item.expansion)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .onDelete { offsets in
                        var list = settings.shortcuts
                        list.remove(atOffsets: offsets)
                        settings.shortcuts = list
                    }
                }
            }

            if let importSummary {
                Section {
                    Text(importSummary).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Gõ tắt")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nhập…") { showingImport = true }
            }
        }
        .sheet(isPresented: $showingImport) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dán bảng gõ tắt theo định dạng viTek (Tab), dấu hai chấm (chữ:thay bằng) hoặc CSV:")
                        .font(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $importText)
                        .font(.system(.body, design: .monospaced))
                        .padding(6)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .padding()
                .navigationTitle("Nhập gõ tắt")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { showingImport = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Nhập") {
                            let parsed = ShortcutFile.parse(importText)
                            let result = settings.importShortcuts(parsed.entries)
                            importSummary = "Đã thêm \(result.added), cập nhật \(result.replaced)"
                                + (parsed.rejectedLines.isEmpty ? "" : ", bỏ qua \(parsed.rejectedLines.count) dòng.")
                            importText = ""
                            showingImport = false
                        }
                        .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

private struct IOSCustomWordsView: View {
    @Bindable private var settings = IOSKeyboardSettings.shared
    @State private var newWord = ""

    var body: some View {
        List {
            Section("Thêm từ không đặt dấu") {
                TextField("vd: viTek, SwiftUI, NextJS", text: $newWord)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !word.isEmpty, !word.contains(" "),
                          !settings.customEnglishWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame })
                    else { return }
                    settings.customEnglishWords.append(word)
                    newWord = ""
                } label: {
                    Label("Thêm từ ngoại lệ", systemImage: "plus.circle.fill")
                }
                .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newWord.contains(" "))
            }

            Section("Danh sách (\(settings.customEnglishWords.count))") {
                if settings.customEnglishWords.isEmpty {
                    Text("Chưa có từ ngoại lệ nào.").foregroundStyle(.secondary)
                } else {
                    ForEach(settings.customEnglishWords, id: \.self) { word in
                        Text(word).font(.system(.body, design: .monospaced))
                    }
                    .onDelete { offsets in
                        var list = settings.customEnglishWords
                        list.remove(atOffsets: offsets)
                        settings.customEnglishWords = list
                    }
                }
            }
        }
        .navigationTitle("Từ ngoại lệ cá nhân")
    }
}

private struct IOSClipboardEditDraft: Identifiable {
    let originalText: String
    var text: String
    var alias: String
    var isPinned: Bool
    var id: String { originalText }
}

private struct IOSShortcutDraft: Identifiable {
    var abbreviation: String = ""
    let expansion: String
    var id: String { abbreviation + ":" + expansion }
}

private struct IOSClipboardView: View {
    @Bindable private var settings = IOSKeyboardSettings.shared
    @State private var newPinned = ""
    @State private var newAlias = ""
    @State private var query = ""
    @State private var filter: ClipboardFilter = .all
    @State private var statusBanner: String?
    @State private var editingDraft: IOSClipboardEditDraft?
    @State private var shortcutDraft: IOSShortcutDraft?

    private var items: [ClipboardItem] {
        settings.clipboardHistory.filter(filter, query: query)
    }

    var body: some View {
        let now = Int(Date().timeIntervalSince1970)
        NavigationStack {
            List {
                Section {
                    Button {
                        if let pasteText = UIPasteboard.general.string, !pasteText.isEmpty {
                            settings.recordClipboard(pasteText)
                            statusBanner = "Đã lưu từ Bộ nhớ tạm."
                        } else {
                            statusBanner = "Bộ nhớ tạm hiện chưa có văn bản."
                        }
                    } label: {
                        Label("Lưu văn bản đang có trong Bộ nhớ tạm", systemImage: "doc.on.clipboard.fill")
                            .font(.subheadline.weight(.semibold))
                    }

                    TextField("Tên gợi nhớ (tuỳ chọn, vd: Chữ ký, STK)", text: $newAlias)
                    HStack {
                        TextField("Nội dung mẫu ghim cố định…", text: $newPinned)
                        Button("Ghim") {
                            let text = newPinned.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            settings.addPinnedClipboard(text, alias: newAlias)
                            newPinned = ""
                            newAlias = ""
                            statusBanner = "Đã ghim mẫu mới."
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                        .disabled(newPinned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let statusBanner {
                        Text(statusBanner)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Thêm vào Clipboard viTek")
                } footer: {
                    Text("Mẫu ghim được đồng bộ với macOS qua iCloud và sẵn dùng ngay trên phím Clipboard của bàn phím viTek ngay cả khi tắt truy cập đầy đủ.")
                }

                Section {
                    Picker("Bộ lọc", selection: $filter) {
                        ForEach(ClipboardFilter.allCases, id: \.self) { chip in
                            Text(chip.title).tag(chip)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)

                Section("Danh sách (\(items.count))") {
                    if items.isEmpty {
                        Text(settings.clipboardHistory.isEmpty
                             ? "Chưa có mẫu Clipboard nào."
                             : "Không tìm thấy mẫu phù hợp.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items, id: \.text) { item in
                            Button {
                                UIPasteboard.general.string = item.text
                                statusBanner = "Đã chép vào Bộ nhớ tạm."
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        if item.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.caption2)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        if !item.alias.isEmpty {
                                            Text(item.alias)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                        }
                                        let rel = item.relativeTimeText(now: now)
                                        if !rel.isEmpty {
                                            Text(rel)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Text(item.preview)
                                        .font(item.kind.usesMonospacedFont
                                              ? .system(.callout, design: .monospaced)
                                              : .callout)
                                        .foregroundStyle(item.alias.isEmpty ? .primary : .secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    settings.togglePinClipboard(item.text)
                                } label: {
                                    Label(item.isPinned ? "Bỏ ghim" : "Ghim",
                                          systemImage: item.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    settings.removeClipboard(item.text)
                                } label: {
                                    Label("Xoá", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = item.text
                                } label: {
                                    Label("Chép", systemImage: "doc.on.clipboard")
                                }
                                Button {
                                    editingDraft = IOSClipboardEditDraft(
                                        originalText: item.text,
                                        text: item.text,
                                        alias: item.alias,
                                        isPinned: item.isPinned
                                    )
                                } label: {
                                    Label("Sửa nội dung / tên gợi nhớ…", systemImage: "square.and.pencil")
                                }
                                Button {
                                    shortcutDraft = IOSShortcutDraft(expansion: item.text)
                                } label: {
                                    Label("Tạo Gõ tắt từ mục này…", systemImage: "bolt.horizontal.fill")
                                }
                                if WritingSuggestion.readiness().canGenerate {
                                    Button {
                                        statusBanner = "Đang phân tích bằng Apple Intelligence…"
                                        Task { @MainActor in
                                            do {
                                                let insight = try await WritingSuggestion.analyzeClipboardSnippet(item.text)
                                                settings.updateClipboardItem(
                                                    oldText: item.text,
                                                    newText: insight.extractedValue,
                                                    alias: insight.alias,
                                                    isPinned: true
                                                )
                                                statusBanner = "Đã đặt tên “\(insight.alias)”."
                                                shortcutDraft = IOSShortcutDraft(abbreviation: insight.abbreviation, expansion: insight.extractedValue)
                                            } catch {
                                                statusBanner = error.localizedDescription
                                            }
                                        }
                                    } label: {
                                        Label("Đặt tên & Gợi ý gõ tắt (AI)…", systemImage: "sparkles")
                                    }
                                    Button {
                                        statusBanner = "Đang khôi phục dấu trên thiết bị…"
                                        Task { @MainActor in
                                            do {
                                                let output = try await WritingSuggestion.runTask(mode: .restoreDiacritics, input: item.text)
                                                UIPasteboard.general.string = output.text
                                                settings.recordClipboard(output.text)
                                                statusBanner = "Đã khôi phục dấu và chép vào Bộ nhớ tạm."
                                            } catch {
                                                statusBanner = error.localizedDescription
                                            }
                                        }
                                    } label: {
                                        Label("Khôi phục dấu tiếng Việt (AI)", systemImage: "textformat")
                                    }
                                }
                                Button {
                                    settings.togglePinClipboard(item.text)
                                } label: {
                                    Label(item.isPinned ? "Bỏ ghim" : "Ghim lên đầu",
                                          systemImage: item.isPinned ? "pin.slash" : "pin")
                                }
                                Divider()
                                Button("Sửa lỗi font → Unicode") {
                                    let converted = TextConverter.convert(item.text, mode: .autoToUnicode)
                                    UIPasteboard.general.string = converted
                                    settings.recordClipboard(converted)
                                }
                                Button("Bỏ dấu tiếng Việt") {
                                    let stripped = TextConverter.convert(item.text, mode: .stripAccents)
                                    UIPasteboard.general.string = stripped
                                    settings.recordClipboard(stripped)
                                }
                                Button("Xoá", role: .destructive) {
                                    settings.removeClipboard(item.text)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Tìm kiếm có dấu hoặc không dấu")
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xoá gần đây") {
                        settings.clearUnpinnedClipboard()
                    }
                    .disabled(settings.clipboardHistory.unpinnedItems.isEmpty)
                }
            }
            .sheet(item: $editingDraft) { draft in
                IOSEditClipboardSheet(draft: draft) { updated in
                    settings.updateClipboardItem(
                        oldText: updated.originalText,
                        newText: updated.text,
                        alias: updated.alias,
                        isPinned: updated.isPinned
                    )
                    statusBanner = "Đã cập nhật mẫu Clipboard."
                }
            }
            .sheet(item: $shortcutDraft) { draft in
                IOSCreateShortcutSheet(initialAbbreviation: draft.abbreviation, initialExpansion: draft.expansion) { entry in
                    settings.importShortcuts([entry])
                    statusBanner = "Đã thêm gõ tắt “\(entry.abbreviation)”."
                }
            }
        }
    }
}

private struct IOSEditClipboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: IOSClipboardEditDraft
    let onSave: (IOSClipboardEditDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Tên gợi nhớ") {
                    TextField("vd: STK ngân hàng, Chữ ký…", text: $draft.alias)
                }
                Section("Nội dung") {
                    TextEditor(text: $draft.text)
                        .frame(minHeight: 120)
                }
                Section {
                    Toggle("Ghim lên đầu", isOn: $draft.isPinned)
                }
            }
            .navigationTitle("Sửa mẫu Clipboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct IOSCreateShortcutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var abbreviation: String
    @State private var expansion: String
    let onSave: (ShortcutEntry) -> Void

    init(initialAbbreviation: String = "", initialExpansion: String, onSave: @escaping (ShortcutEntry) -> Void) {
        _abbreviation = State(initialValue: initialAbbreviation)
        _expansion = State(initialValue: initialExpansion)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chữ tắt") {
                    TextField("vd: stk, dc, email", text: $abbreviation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Thay bằng") {
                    TextEditor(text: $expansion)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Tạo Gõ tắt mới")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let key = abbreviation.trimmingCharacters(in: .whitespaces)
                        let val = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty, !key.contains(" "), !val.isEmpty else { return }
                        onSave(ShortcutEntry(abbreviation: key, expansion: val))
                        dismiss()
                    }
                    .disabled(abbreviation.trimmingCharacters(in: .whitespaces).isEmpty
                              || abbreviation.contains(" ")
                              || expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
