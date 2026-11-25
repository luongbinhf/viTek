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
                    Text("Hỗ trợ nhập từ viTek, UniKey, OpenKey, CSV và các biến {{date}}, {{time}}, {{datetime}}.")
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
                    Text("Nhấn giữ phím VI/EN để đổi nhanh chế độ một tay; bấm ◫ khi xoay ngang hoặc trên iPad để chia đôi/gộp bàn phím.")
                }

                Section {
                    Toggle("Đồng bộ cài đặt & gõ tắt qua iCloud", isOn: $settings.iCloudSyncEnabled)
                    LabeledContent("Từ/cụm cá nhân đã học", value: "\(settings.personalFrequency.totalCount)")
                    Button("Xóa từ đã học", role: .destructive) { settings.forgetPersonalFrequency() }
                        .disabled(settings.personalFrequency.isEmpty)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Chỉ đồng bộ tuỳ chọn kiểu gõ và bảng gõ tắt giữa Mac, iPhone và iPad. Không đồng bộ văn bản đang gõ.")
                }

                Section {
                    LabeledContent("Phiên bản", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
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
                    Text("Dán bảng gõ tắt theo định dạng viTek (Tab), UniKey/OpenKey (chữ:thay bằng) hoặc CSV:")
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
