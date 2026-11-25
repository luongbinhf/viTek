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
}

struct ToggleWidgetLanguageIntent: AppIntent {
    static let title: LocalizedStringResource = "Chuyển chế độ Việt / Anh"
    static let description = IntentDescription("Bật hoặc tạm tắt dấu tiếng Việt trên bàn phím viTek.")

    func perform() async throws -> some IntentResult {
        SharedWidgetDefaults.isVietnameseEnabled.toggle()
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
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

@available(iOS 18.0, *)
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
}

private struct TypingProvider: TimelineProvider {
    private func currentEntry() -> TypingEntry {
        TypingEntry(
            date: .now,
            isVietnamese: SharedWidgetDefaults.isVietnameseEnabled,
            isModernTone: SharedWidgetDefaults.isModernTone,
            shortcutCount: SharedWidgetDefaults.shortcutCount
        )
    }

    func placeholder(in context: Context) -> TypingEntry {
        TypingEntry(date: .now, isVietnamese: true, isModernTone: true, shortcutCount: 0)
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
                Text("viTek · \(entry.isVietnamese ? "Tiếng Việt" : "English")")
                    .font(.headline)
                Text(entry.isModernTone ? "Dấu mới (hoà) · \(entry.shortcutCount) gõ tắt" : "Dấu cũ (hòa) · \(entry.shortcutCount) gõ tắt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .widgetURL(WritingLink.url)
        case .systemMedium:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("viTek", systemImage: "keyboard")
                        .font(.headline)
                    Text(entry.isVietnamese ? "Đang gõ Tiếng Việt" : "Đang tạm gõ English")
                        .font(.subheadline.weight(.semibold))
                    Text("\(entry.shortcutCount) gõ tắt · viwtj → việt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Link(destination: WritingLink.url) {
                        Label("Gợi ý viết", systemImage: "square.and.pencil")
                            .font(.caption.weight(.medium))
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    Button(intent: ToggleWidgetLanguageIntent()) {
                        Label(entry.isVietnamese ? "VI" : "EN", systemImage: "globe")
                            .font(.callout.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(entry.isVietnamese ? .blue : .secondary)

                    Button(intent: ToggleWidgetToneStyleIntent()) {
                        Text(entry.isModernTone ? "Dấu mới: hoà" : "Dấu cũ: hòa")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(width: 120)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("viTek", systemImage: "keyboard")
                        .font(.subheadline.bold())
                    Spacer()
                    Button(intent: ToggleWidgetLanguageIntent()) {
                        Text(entry.isVietnamese ? "VI" : "EN")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(entry.isVietnamese ? .blue : .secondary)
                }
                Button(intent: ToggleWidgetToneStyleIntent()) {
                    Text(entry.isModernTone ? "Kiểu mới · hoà" : "Kiểu cũ · hòa")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Link(destination: WritingLink.url) {
                    Label("Gợi ý viết", systemImage: "square.and.pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TypingWidget: Widget {
    let kind = "viTek.QuickTyping"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TypingProvider()) { entry in
            TypingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Trạng thái & Gõ nhanh viTek")
        .description("Chuyển nhanh Việt/Anh, đổi kiểu dấu hoà/hòa và mở Gợi ý viết ngay từ Màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@available(iOS 18.0, *)
struct VitekControlProvider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool {
        SharedWidgetDefaults.isVietnameseEnabled
    }
}

@available(iOS 18.0, *)
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
        if #available(iOS 18.0, *) {
            VitekLanguageControl()
        }
    }
}
