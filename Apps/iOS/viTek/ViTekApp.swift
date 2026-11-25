import SwiftUI
import VitekEngine
import VitekSession

@main
struct ViTekApp: App {
    @Bindable private var route = WritingRoute.shared

    var body: some Scene {
        WindowGroup {
            TabView(selection: $route.destination) {
                Tab("Bàn phím", systemImage: "keyboard", value: WritingRoute.Destination.keyboard) { KeyboardGuide() }
                Tab("Gợi ý viết", systemImage: "pencil", value: WritingRoute.Destination.writing) { WritingView() }
                Tab("Clipboard", systemImage: "doc.on.clipboard", value: WritingRoute.Destination.clipboard) { IOSClipboardView() }
                Tab("Cài đặt", systemImage: "gearshape", value: WritingRoute.Destination.settings) { KeyboardSettingsView() }
            }
            .onOpenURL { route.handle($0) }
            .task {
                CloudSettingsSync.shared.start()
                await VitekFocusFilter.refreshCurrent()
            }
        }
    }
}

private struct KeyboardGuide: View {
    @Environment(\.openURL) private var openURL
    @State private var sample = ""

    private var typedVietnamese: Bool {
        sample.lowercased().split(whereSeparator: \.isWhitespace).contains("việt")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        BrandMascotView(size: 74)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text("viTek")
                                    .font(.title2.bold())
                                Text("MIT Open Source")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                            Text("100% Swift Native · Tự nhận Telex & VNI · Xử lý hoàn toàn trên thiết bị.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Text("Trong Cài đặt, mở Cài đặt chung → Bàn phím → Bàn phím → Thêm bàn phím mới, rồi chọn viTek.")
                    Button("Mở cài đặt của viTek") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: {
                    Text("1. Thêm viTek")
                } footer: {
                    Text("Bạn có thể để tắt “Cho phép truy cập đầy đủ”.")
                }
                Section {
                    Text("Chạm vào ô nhập, giữ phím quả địa cầu rồi chọn viTek.")
                    TextField("Thử gõ vieetj", text: $sample, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if typedVietnamese {
                        Label("Đã gõ được tiếng Việt!", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("2. Gõ thử")
                } footer: {
                    Text("Gõ vieetj hoặc vie65t rồi bấm dấu cách. Cả hai cách đều cho ra “việt”.")
                }
            }
            .navigationTitle("Bàn phím viTek")
        }
    }
}

private struct KeyboardSettingsView: View {
    @Bindable private var settings = IOSKeyboardSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kiểu đặt dấu", selection: $settings.toneStyle) {
                        Text("Kiểu mới (hoà, thuý)").tag(ToneStyle.modern)
                        Text("Kiểu cũ (hòa, thúy)").tag(ToneStyle.traditional)
                    }
                    Toggle("Kiểm tra chính tả tiếng Việt", isOn: $settings.spellCheck)
                    Toggle("Khôi phục từ không hợp lệ", isOn: $settings.restoreInvalidWords)
                    Toggle("Giữ nguyên từ tiếng Anh thông dụng", isOn: $settings.keepEnglishWords)
                    Toggle("Gõ tắt phụ âm đầu (cc, gg, kk, nn, pp, qq, tt)", isOn: $settings.quickStartConsonants)
                    Toggle("Gõ tắt phụ âm cuối (g→ng, h→nh, k→ch)", isOn: $settings.quickEndConsonants)
                    NavigationLink {
                        IOSCustomWordsView()
                    } label: {
                        LabeledContent("Từ ngoại lệ cá nhân", value: "\(settings.customEnglishWords.count)")
                    }
                    .accessibilityIdentifier("settings.customWords")
                } header: {
                    Text("Kiểu gõ")
                } footer: {
                    Text("viTek tự nhận Telex và VNI theo từng từ, xử lý hoàn toàn trên thiết bị.")
                }

                Section {
                    Toggle("Bật gõ tắt", isOn: $settings.shortcutsEnabled)
                    Toggle("Gõ tắt cả khi tắt tiếng Việt", isOn: $settings.shortcutsInEnglishMode)
                        .disabled(!settings.shortcutsEnabled)
                    NavigationLink {
                        IOSShortcutsView()
                    } label: {
                        LabeledContent("Bảng gõ tắt", value: "\(settings.shortcutTable.count)")
                    }
                    .accessibilityIdentifier("settings.shortcuts")
                } header: {
                    Text("Gõ tắt")
                } footer: {
                    Text("Hỗ trợ nhập định dạng viTek (Tab), dấu hai chấm (chữ:thay bằng), CSV và các biến {{date}}, {{time}}, {{datetime}}.")
                }

                Section {
                    Picker("Bố cục gõ một tay (dọc)", selection: $settings.oneHandedMode) {
                        Text("Đầy đủ").tag(IOSKeyboardSettings.OneHandedMode.full)
                        Text("Tay trái").tag(IOSKeyboardSettings.OneHandedMode.left)
                        Text("Tay phải").tag(IOSKeyboardSettings.OneHandedMode.right)
                    }
                    Toggle("Chia đôi bàn phím khi xoay ngang & iPad", isOn: $settings.splitLandscapeKeyboard)
                    Toggle("Vuốt xuống phím chữ để gõ nhanh số & ký hiệu", isOn: $settings.flickDownSymbols)
                    Toggle("Thanh gợi ý từ trên bàn phím", isOn: $settings.showSuggestions)
                    Toggle("Hiển thị hàng phím số phía trên", isOn: $settings.showNumberRow)
                    Toggle("Tự viết hoa đầu câu", isOn: $settings.autoCapitalization)
                    Toggle("Nhấn đúp dấu cách chèn dấu chấm", isOn: $settings.doubleSpacePeriod)
                    Toggle("Phản hồi rung nhẹ khi nhấn phím", isOn: $settings.hapticFeedback)
                    Toggle("Âm thanh bấm phím hệ thống", isOn: $settings.keyClickSound)
                } header: {
                    Text("Giao diện & Trải nghiệm bàn phím")
                } footer: {
                    Text("Nhấn giữ phím VI/EN để đổi nhanh chế độ một tay; bấm biểu tượng chia đôi khi xoay ngang hoặc trên iPad / iPhone Duo.")
                }

                Section {
                    Picker(selection: $settings.duoCenterBridgeMode) {
                        ForEach(DuoBridgeMode.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.symbolName).tag(mode)
                        }
                    } label: {
                        Label("Cầu nối giữa bản lề", systemImage: "rectangle.split.2x1.fill")
                    }
                    Toggle(isOn: $settings.duoDuplicateBoundaryKeys) {
                        Label("Lặp phím G & B hai bên khi chia đôi", systemImage: "keyboard")
                    }
                    Toggle(isOn: $settings.duoTabletopUtilityBar) {
                        Label("Thanh công cụ Esc · Tab · Điều hướng", systemImage: "bolt.horizontal.fill")
                    }
                    Picker(selection: $settings.coverOneHandedMode) {
                        Text("Đầy đủ").tag(IOSKeyboardSettings.OneHandedMode.full)
                        Text("Tay trái").tag(IOSKeyboardSettings.OneHandedMode.left)
                        Text("Tay phải").tag(IOSKeyboardSettings.OneHandedMode.right)
                    } label: {
                        Label("Gõ một tay trên màn ngoài", systemImage: "keyboard.onehanded.right")
                    }
                } header: {
                    Text("Màn hình gập iPhone Duo & Đa nhiệm")
                } footer: {
                    Text("Tự chuyển về bàn phím đơn khi chia đôi 2 ứng dụng (< 480 pt); khi mở phẳng Duo sẽ hiện cầu nối giữa bản lề với bàn rê 2D, Numpad hoặc Clipboard.")
                }

                Section {
                    Toggle("Đồng bộ cài đặt & gõ tắt qua iCloud", isOn: $settings.iCloudSyncEnabled)
                    Toggle("Đồng bộ mẫu Clipboard đã ghim qua iCloud", isOn: $settings.syncClipboardPinnedICloud)
                        .disabled(!settings.iCloudSyncEnabled)
                    Toggle("Đồng bộ Clipboard gần đây qua iCloud", isOn: $settings.syncClipboardRecentICloud)
                        .disabled(!settings.iCloudSyncEnabled)
                    Toggle("Đồng bộ từ vựng cá nhân đã học qua iCloud", isOn: $settings.syncPersonalVocabularyICloud)
                        .disabled(!settings.iCloudSyncEnabled)
                    LabeledContent("Từ/cụm cá nhân đã học", value: "\(settings.personalFrequency.totalCount)")
                    Button("Xóa từ đã học", role: .destructive) { settings.forgetPersonalFrequency() }
                        .disabled(settings.personalFrequency.isEmpty)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Đồng bộ tuỳ chọn, gõ tắt, mẫu Clipboard ghim và từ vựng học cá nhân giữa Mac, iPhone và iPad. Không đồng bộ văn bản đang gõ.")
                }

                Section {
                    LabeledContent("Phiên bản", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
                    LabeledContent("ANE Ngữ cảnh", value: NeuralContextScorer.shared.statusSummary)
                    LabeledContent("Apple Intelligence", value: WritingSuggestion.readiness().canGenerate ? "Sẵn sàng trên thiết bị" : "Theo cài đặt máy")
                    LabeledContent("Giấy phép", value: "MIT Open Source")
                    if let repoURL = URL(string: "https://github.com/luongbinhf/viTek") {
                        Link("Mã nguồn trên GitHub", destination: repoURL)
                    }
                } header: {
                    Text("Giới thiệu")
                }
            }
            .navigationTitle("Cài đặt")
        }
    }
}

private struct IOSShortcutsView: View {
    @Bindable private var settings = IOSKeyboardSettings.shared
    @State private var abbreviation = ""
    @State private var expansion = ""
    @State private var showingImport = false
    @State private var importText = ""
    @State private var importSummary: String?

    var body: some View {
        List {
            Section("Thêm gõ tắt") {
                TextField("Chữ tắt (vd: ko)", text: $abbreviation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Thay bằng (vd: không)", text: $expansion)
                Button("Thêm") {
                    let key = abbreviation.trimmingCharacters(in: .whitespaces)
                    let value = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty, !key.contains(" "), !value.isEmpty else { return }
                    settings.importShortcuts([ShortcutEntry(abbreviation: key, expansion: value)])
                    abbreviation = ""
                    expansion = ""
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
                            Text(item.abbreviation).font(.system(.body, design: .monospaced).weight(.semibold))
                            Spacer()
                            Text(item.expansion).foregroundStyle(.secondary).lineLimit(1)
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
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ClipboardFilter.allCases, id: \.self) { chip in
                                let isActive = chip == filter
                                Button {
                                    filter = chip
                                } label: {
                                    Label(chip.title, systemImage: chip.symbolName)
                                        .font(.caption.weight(isActive ? .semibold : .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(isActive ? Color.accentColor : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

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
                                HStack(spacing: 12) {
                                    ClipboardKindBadge(item: item, size: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            if !item.alias.isEmpty {
                                                Text(item.alias)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                            }
                                            if item.isPinned {
                                                Image(systemName: "pin.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                            let rel = item.relativeTimeText(now: now)
                                            Text(rel.isEmpty ? item.statsSummary : "\(item.statsSummary) · \(rel)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Text(item.preview)
                                            .font(item.kind.usesMonospacedFont
                                                  ? .system(.callout, design: .monospaced)
                                                  : .callout)
                                            .foregroundStyle(item.alias.isEmpty ? .primary : .secondary)
                                            .lineLimit(2)
                                    }
                                }
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
