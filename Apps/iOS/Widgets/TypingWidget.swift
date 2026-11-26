import AppIntents
import SwiftUI
import WidgetKit

private enum SharedWidgetDefaults {
    static let appGroupID = "group.io.github.luongbinhf.viTek"

    static var store: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var isVietnameseEnabled: Bool {
        get { store.object(forKey: "vietnameseEnabled") as? Bool ?? true }
        set { store.set(newValue, forKey: "vietnameseEnabled") }
    }

    static var isModernTone: Bool {
        get { (store.string(forKey: "toneStyle") ?? "modern") == "modern" }
        set { store.set(newValue ? "modern" : "traditional", forKey: "toneStyle") }
    }

    static var shortcutCount: Int {
        guard store.object(forKey: "shortcutsEnabled") as? Bool ?? true else { return 0 }
        let entries = store.array(forKey: "shortcuts") as? [[String: String]] ?? []
        return entries.count
    }

    static var clipboardCount: Int {
        let entries = store.array(forKey: "clipboardItems") as? [[String: String]] ?? []
        return entries.count
    }
}

struct ToggleWidgetLanguageIntent: AppIntent {
    static let title: LocalizedStringResource = "Chuyển chế độ Việt / Anh"
    static let description = IntentDescription("Bật hoặc tạm tắt dấu tiếng Việt trên bàn phím viTek.")

    func perform() async throws -> some IntentResult {
        SharedWidgetDefaults.isVietnameseEnabled.toggle()
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}

struct ToggleWidgetToneStyleIntent: AppIntent {
    static let title: LocalizedStringResource = "Đổi kiểu đặt dấu (hoà / hòa)"
    static let description = IntentDescription("Chuyển nhanh giữa kiểu đặt dấu mới (hoà) và kiểu cũ (hòa).")

    func perform() async throws -> some IntentResult {
        SharedWidgetDefaults.isModernTone.toggle()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SetControlLanguageIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Bật gõ tiếng Việt viTek"

    @Parameter(title: "Tiếng Việt")
    var value: Bool

    func perform() async throws -> some IntentResult {
        SharedWidgetDefaults.isVietnameseEnabled = value
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}

private struct TypingEntry: TimelineEntry {
    let date: Date
    let isVietnamese: Bool
    let isModernTone: Bool
    let shortcutCount: Int
    let clipboardCount: Int
}

private struct TypingProvider: TimelineProvider {
    private func currentEntry() -> TypingEntry {
        TypingEntry(
            date: .now,
            isVietnamese: SharedWidgetDefaults.isVietnameseEnabled,
            isModernTone: SharedWidgetDefaults.isModernTone,
            shortcutCount: SharedWidgetDefaults.shortcutCount,
            clipboardCount: SharedWidgetDefaults.clipboardCount
        )
    }

    func placeholder(in context: Context) -> TypingEntry {
        TypingEntry(date: .now, isVietnamese: true, isModernTone: true, shortcutCount: 6, clipboardCount: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (TypingEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TypingEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }
}

private struct TypingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TypingEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard")
                    Text("viTek · \(entry.isVietnamese ? "Tiếng Việt" : "English")")
                        .font(.headline)
                }
                Text("\(entry.isModernTone ? "Dấu mới (hoà)" : "Dấu cũ (hòa)") · \(entry.shortcutCount) gõ tắt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .widgetURL(WritingLink.url)

        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text("viTek 26")
                            .font(.subheadline.weight(.bold))
                    }

                    Text(entry.isVietnamese ? "Đang bật Tiếng Việt" : "Đang tạm gõ English")
                        .font(.subheadline.weight(.semibold))

                    Text("\(entry.shortcutCount) gõ tắt · \(entry.clipboardCount) mục Clipboard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        Link(destination: WritingLink.url) {
                            Label("AI Viết", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                        }
                        Text("·").foregroundStyle(.tertiary)
                        Link(destination: WritingLink.clipboardURL) {
                            Label("Clipboard", systemImage: "doc.on.clipboard")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Button(intent: ToggleWidgetLanguageIntent()) {
                        Label(entry.isVietnamese ? "Chế độ VI" : "Chế độ EN", systemImage: "globe")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(entry.isVietnamese ? .blue : .secondary)

                    Button(intent: ToggleWidgetToneStyleIntent()) {
                        Text(entry.isModernTone ? "Dấu mới · hoà" : "Dấu cũ · hòa")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .frame(width: 124)
            }

        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "keyboard.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("viTek")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Button(intent: ToggleWidgetLanguageIntent()) {
                        Text(entry.isVietnamese ? "VI" : "EN")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(entry.isVietnamese ? .blue : .secondary)
                }

                Button(intent: ToggleWidgetToneStyleIntent()) {
                    Text(entry.isModernTone ? "Kiểu mới · hoà" : "Kiểu cũ · hòa")
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Link(destination: WritingLink.url) {
                        Label("AI Viết", systemImage: "sparkles")
                            .font(.caption2.weight(.semibold))
                    }
                    Spacer()
                    Link(destination: WritingLink.clipboardURL) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct TypingWidget: Widget {
    let kind = "viTek.QuickTyping"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TypingProvider()) { entry in
            TypingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack(alignment: .topLeading) {
                        Color(uiColor: .secondarySystemGroupedBackground)
                        LinearGradient(
                            colors: [Color.blue.opacity(0.14), Color.cyan.opacity(0.05), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
        }
        .configurationDisplayName("Trạng thái & Gõ nhanh viTek")
        .description("Chuyển nhanh Việt/Anh, đổi kiểu dấu hoà/hòa và mở AI Viết hoặc Clipboard ngay từ Màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct VitekControlProvider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool {
        SharedWidgetDefaults.isVietnameseEnabled
    }
}

struct VitekLanguageControl: ControlWidget {
    let kind = "viTek.LanguageControl"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind, provider: VitekControlProvider()) { isVietnamese in
            ControlWidgetToggle(
                "viTek Tiếng Việt",
                isOn: isVietnamese,
                action: SetControlLanguageIntent()
            ) { on in
                Label(on ? "Tiếng Việt" : "English", systemImage: "keyboard")
            }
        }
        .displayName("Chế độ gõ viTek")
        .description("Bật hoặc tạm tắt dấu tiếng Việt của bàn phím viTek ngay từ Trung tâm điều khiển.")
    }
}

@main
struct VitekWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TypingWidget()
        VitekLanguageControl()
    }
}
