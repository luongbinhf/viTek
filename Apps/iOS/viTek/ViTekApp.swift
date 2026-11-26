import SwiftUI
import UIKit
import VitekEngine
import VitekSession

@main
struct ViTekApp: App {
    @Bindable private var route = WritingRoute.shared

    var body: some Scene {
        WindowGroup {
            TabView(selection: $route.destination) {
                Tab("Bàn phím", systemImage: "keyboard", value: WritingRoute.Destination.keyboard) {
                    KeyboardGuide()
                }
                Tab("Gợi ý viết", systemImage: "pencil", value: WritingRoute.Destination.writing) {
                    WritingView()
                }
                Tab("Clipboard", systemImage: "doc.on.clipboard", value: WritingRoute.Destination.clipboard) {
                    IOSClipboardView()
                }
                Tab("Cài đặt", systemImage: "gearshape", value: WritingRoute.Destination.settings) {
                    KeyboardSettingsView()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .onOpenURL { route.handle($0) }
            .task {
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

// MARK: - Tab 1: Bàn phím (iOS 26 Liquid Glass Dashboard & Live Sandbox)

private struct KeyboardGuide: View {
    @Environment(\.openURL) private var openURL
    @Bindable private var settings = IOSKeyboardSettings.shared
    @Bindable private var route = WritingRoute.shared
    @State private var sample = ""

    private var hasVietnameseDiacritics: Bool {
        sample.unicodeScalars.contains { $0.value > 127 && CharacterSet.letters.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroGlassCard
                    quickControlStrip
                    liveTypingSandboxCard
                    ergonomicHighlightsGrid
                    setupStepsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(ambientBackdrop.ignoresSafeArea())
            .navigationTitle("viTek")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var ambientBackdrop: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.14),
                    Color.cyan.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 320)
        }
    }

    private var heroGlassCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                BrandMascotView(size: 70)
                    .shadow(color: .blue.opacity(0.18), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("viTek 26")
                            .font(.title3.weight(.bold))
                        Text("Liquid Glass")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.14), in: Capsule())
                    }
                    Text("Bộ gõ tiếng Việt 100% Swift 6 Native · Tự nhận Telex & VNI · 0,7 µs trên Apple Silicon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Mở Cài đặt Bàn phím", systemImage: "keyboard.badge.ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                Button {
                    route.destination = .writing
                } label: {
                    Label("AI Viết", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var quickControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        settings.vietnameseEnabled.toggle()
                    } label: {
                        Label(
                            settings.vietnameseEnabled ? "Chế độ: Tiếng Việt" : "Chế độ: English",
                            systemImage: "globe"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(settings.vietnameseEnabled ? Color.accentColor : .primary)
                        .glassEffect(
                            settings.vietnameseEnabled ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                            in: .capsule
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        settings.toneStyle = (settings.toneStyle == .modern) ? .traditional : .modern
                    } label: {
                        Label(
                            settings.toneStyle == .modern ? "Dấu mới: hoà" : "Dấu cũ: hòa",
                            systemImage: "textformat"
                        )
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)

                    Button {
                        route.destination = .clipboard
                    } label: {
                        Label(
                            "Clipboard (\(settings.clipboardHistory.items.count))",
                            systemImage: "doc.on.clipboard"
                        )
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var liveTypingSandboxCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ô gõ thử trực tiếp", systemImage: "character.cursor.ibeam")
                    .font(.headline)
                Spacer()
                if !sample.isEmpty {
                    Button {
                        sample = ""
                    } label: {
                        Label("Xoá", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Thử gõ vieetj", text: $sample, axis: .vertical)
                .lineLimit(2...5)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            if hasVietnameseDiacritics {
                Label("Đã gõ tiếng Việt mượt mà với viTek!", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        examplePill(keys: "vieetj", output: "việt")
                        examplePill(keys: "tuoongw", output: "tương")
                        examplePill(keys: "chuywnj", output: "chuyện")
                        examplePill(keys: "vie65t", output: "việt")
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func examplePill(keys: String, output: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
            Text(output)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }

    private var ergonomicHighlightsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            highlightTile(
                symbol: "arrow.down.square.fill",
                tint: .blue,
                title: "Vuốt xuống phím",
                subtitle: "Gõ nhanh số 1–0 & ký hiệu @ # $ mà không chuyển trang"
            )
            highlightTile(
                symbol: "arrow.left.and.right.square.fill",
                tint: .indigo,
                title: "Rê Dấu cách",
                subtitle: "Trượt ngang trên phím Tiếng Việt để đặt con trỏ chính xác"
            )
            highlightTile(
                symbol: "keyboard.onehanded.right",
                tint: .teal,
                title: "Một tay & Duo",
                subtitle: "Nhấn giữ nút VI để thu gọn 1 tay hoặc mở cầu nối màn gập"
            )
            highlightTile(
                symbol: "cpu.fill",
                tint: .purple,
                title: "ANE & AI Cục bộ",
                subtitle: "Khử mơ hồ song ngữ trên máy, không cần Full Access"
            )
        }
    }

    private func highlightTile(symbol: String, tint: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsBadgeIcon(symbol: symbol, tint: tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var setupStepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hướng dẫn bật nhanh (3 bước)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            stepRow(number: "1", title: "Mở Cài đặt → Cài đặt chung → Bàn phím", detail: "Chọn Bàn phím → Thêm bàn phím mới → chọn viTek.")
            Divider()
            stepRow(number: "2", title: "Riêng tư tuyệt đối", detail: "Không cần bật “Cho phép truy cập đầy đủ” để gõ tiếng Việt, dùng gõ tắt hay gợi ý từ.")
            Divider()
            stepRow(number: "3", title: "Chuyển sang viTek bằng phím 🌐", detail: "Chạm giữ biểu tượng quả địa cầu dưới góc trái bàn phím và chọn viTek.")
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.gradient, in: Circle())
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(ClipboardFilter.allCases, id: \.self) { chip in
                                    let isActive = chip == filter
                                    Button {
                                        filter = chip
                                    } label: {
                                        Label(chip.title, systemImage: chip.symbolName)
                                            .font(.caption.weight(isActive ? .semibold : .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .foregroundStyle(isActive ? Color.accentColor : .primary)
                                            .glassEffect(
                                                isActive ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                                in: .capsule
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 2)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
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
                                HStack(alignment: .top, spacing: 12) {
                                    ClipboardKindBadge(item: item, size: 32)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 3) {
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
                                            .lineSpacing(2)
                                            .lineLimit(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.vertical, 3)
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
