import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class DynamicIslandState {
    enum CompactKind: Equatable {
        case mode(vietnamese: Bool, label: String)
        case copied(preview: String)
        case skippedSecret
    }

    var geometry: ScreenCutoutGeometry = .resolve()
    var compact: CompactKind?
    var isExpanded = false
}

/// Pure-black (`#000000`) Notch & OLED Dynamic Island status surface for viTek.
/// Shows brief non-blocking wings for `VI / EN` app mode changes and `⌘C` clipboard confirmations,
/// plus optional cursor-dwell trigger at the Notch bottom edge to drop open `ClipboardPanel`.
@MainActor
enum DynamicIslandPanel {
    private static let state = DynamicIslandState()
    private static var panel: NSPanel?
    private static var host: NSHostingView<DynamicIslandToastView>?
    private static var dismissTask: Task<Void, Never>?
    private static var hoverMonitor: Any?
    private static var hoverDwellTask: Task<Void, Never>?

    private static let leftWingWidth: CGFloat = 92
    private static let rightWingWidth: CGFloat = 148
    private static let earRadius: CGFloat = 10

    static func showMode(vietnamese: Bool, appName: String?, caret: NSRect = .zero) {
        let modeText = vietnamese ? "Tiếng Việt" : "English"
        let rightLabel = if let appName, !appName.isEmpty {
            "\(appName) · \(modeText)"
        } else {
            modeText
        }
        present(
            .mode(vietnamese: vietnamese, label: rightLabel),
            geometry: ScreenCutoutGeometry.resolve(for: caret),
            duration: .milliseconds(700)
        )
    }

    static func showCopied(preview: String) {
        guard !ClipboardPanel.isVisible else { return }
        let collapsed = preview
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return }
        let short = collapsed.count <= 26 ? collapsed : String(collapsed.prefix(26)) + "…"
        present(.copied(preview: short), geometry: ScreenCutoutGeometry.resolve(), duration: .milliseconds(800))
    }

    static func showSkippedSecret() {
        guard !ClipboardPanel.isVisible else { return }
        present(.skippedSecret, geometry: ScreenCutoutGeometry.resolve(), duration: .milliseconds(850))
    }

    static func hideCompact() {
        dismissTask?.cancel()
        dismissTask = nil
        state.isExpanded = false
        panel?.orderOut(nil)
    }

    static func updateHoverMonitoring() {
        let shouldMonitor = SettingsStore.shared.notchHoverClipboard
            && SettingsStore.shared.clipboardHistoryEnabled
            && SettingsStore.shared.overlayPlacement == .notchIsland

        if shouldMonitor, hoverMonitor == nil {
            hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                MainActor.assumeIsolated {
                    handleGlobalMouseMoved()
                }
            }
        } else if !shouldMonitor, let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
            hoverMonitor = nil
            hoverDwellTask?.cancel()
            hoverDwellTask = nil
        }
    }

    private static func handleGlobalMouseMoved() {
        guard !ClipboardPanel.isVisible else {
            hoverDwellTask?.cancel()
            hoverDwellTask = nil
            return
        }
        let mouse = NSEvent.mouseLocation
        guard isInsideNotchTriggerZone(mouse) else {
            hoverDwellTask?.cancel()
            hoverDwellTask = nil
            return
        }
        guard hoverDwellTask == nil else { return }
        hoverDwellTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            hoverDwellTask = nil
            if isInsideNotchTriggerZone(NSEvent.mouseLocation), !ClipboardPanel.isVisible {
                VitekInputController.openIslandClipboardFromHover()
            }
        }
    }

    private static func isInsideNotchTriggerZone(_ point: NSPoint) -> Bool {
        guard let cutout = ScreenCutoutGeometry.physicalCutoutRect(at: point) else { return false }
        let trigger = NSRect(
            x: cutout.minX - 10,
            y: cutout.minY - 6,
            width: cutout.width + 20,
            height: cutout.height + 6
        )
        return trigger.contains(point)
    }

    private static func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let created = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        created.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        created.isOpaque = false
        created.backgroundColor = .clear
        created.hasShadow = true
        created.ignoresMouseEvents = true
        created.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: DynamicIslandToastView(state: state))
        created.contentView = hosting
        self.host = hosting
        self.panel = created
        return created
    }

    private static func present(
        _ kind: DynamicIslandState.CompactKind,
        geometry: ScreenCutoutGeometry,
        duration: Duration
    ) {
        dismissTask?.cancel()
        state.geometry = geometry
        state.compact = kind
        state.isExpanded = false

        let panel = ensurePanel()
        let frame: NSRect
        switch geometry.style {
        case .notch:
            let totalWidth = earRadius + leftWingWidth + geometry.cutoutRect.width + rightWingWidth + earRadius
            let height = max(geometry.cutoutRect.height, 34)
            let x = geometry.cutoutRect.minX - leftWingWidth - earRadius
            let y = geometry.screenFrame.maxY - height
            frame = NSRect(x: x, y: y, width: totalWidth, height: height)

        case .dynamicIsland:
            let totalWidth = leftWingWidth + geometry.cutoutRect.width + rightWingWidth
            let height = max(geometry.cutoutRect.height + 4, 34)
            let x = geometry.cutoutRect.minX - leftWingWidth
            let y = geometry.cutoutRect.maxY - height + 2
            frame = NSRect(x: x, y: y, width: totalWidth, height: height)

        case .floatingPill:
            let totalWidth: CGFloat = 248
            let height: CGFloat = 32
            let x = geometry.screenFrame.midX - totalWidth / 2
            let y = geometry.visibleFrame.maxY - height - 6
            frame = NSRect(x: x, y: y, width: totalWidth, height: height)
        }

        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            state.isExpanded = true
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                state.isExpanded = false
            }
            try? await Task.sleep(for: .milliseconds(170))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }
}

private struct DynamicIslandToastView: View {
    let state: DynamicIslandState

    private let leftWingWidth: CGFloat = 92
    private let rightWingWidth: CGFloat = 148
    private let earRadius: CGFloat = 10

    var body: some View {
        let style = state.geometry.style
        let gapWidth = state.geometry.cutoutRect.width

        Group {
            switch style {
            case .notch:
                HStack(spacing: 0) {
                    Color.clear.frame(width: earRadius)
                    leftWing
                        .frame(width: leftWingWidth, alignment: .center)
                    Color.clear.frame(width: gapWidth)
                    rightWing
                        .frame(width: rightWingWidth, alignment: .leading)
                    Color.clear.frame(width: earRadius)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .clipShape(NotchEarShape(earRadius: earRadius, bottomRadius: 15))

            case .dynamicIsland:
                HStack(spacing: 0) {
                    leftWing
                        .frame(width: leftWingWidth, alignment: .center)
                    Color.clear.frame(width: gapWidth)
                    rightWing
                        .frame(width: rightWingWidth, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))

            case .floatingPill:
                HStack(spacing: 8) {
                    leftWing
                    Spacer(minLength: 4)
                    rightWing
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
            }
        }
        .scaleEffect(x: state.isExpanded ? 1.0 : 0.88, y: state.isExpanded ? 1.0 : 0.88, anchor: .top)
        .opacity(state.isExpanded ? 1.0 : 0.0)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var leftWing: some View {
        switch state.compact {
        case .mode(let vietnamese, _):
            HStack(spacing: 5) {
                Text(vietnamese ? "VI" : "EN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(vietnamese ? Color.accentColor : Color.white.opacity(0.22))
                    )
            }
        case .copied:
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.teal)
                Text("Đã chép")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .skippedSecret:
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Bảo mật")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        switch state.compact {
        case .mode(_, let label):
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
        case .copied(let preview):
            Text(preview)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
        case .skippedSecret:
            Text("Bỏ qua mật khẩu")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.orange.opacity(0.95))
                .lineLimit(1)
                .padding(.horizontal, 6)
        case nil:
            EmptyView()
        }
    }
}

/// Observes active frontmost application changes (`⌘Tab` / Dock / click) so viTek automatically
/// applies each app's remembered `VI / EN` mode and flashes the Notch / Dynamic Island toast on transitions.
@MainActor
final class AppModeMonitor {
    static let shared = AppModeMonitor()

    private var observer: NSObjectProtocol?
    private var lastBundleID: String?
    private var lastVietnamese: Bool?

    func start() {
        guard observer == nil else { return }
        if let front = NSWorkspace.shared.frontmostApplication, let bundleID = front.bundleIdentifier {
            lastBundleID = bundleID
            lastVietnamese = SettingsStore.shared.effectiveVietnamese(for: bundleID)
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            let appName = app?.localizedName
            MainActor.assumeIsolated {
                Self.shared.handleActivation(bundleID: bundleID, appName: appName)
            }
        }
    }

    func syncManualToggle(bundleID: String?, vietnamese: Bool) {
        if let bundleID { lastBundleID = bundleID }
        lastVietnamese = vietnamese
    }

    private func handleActivation(bundleID: String?, appName: String?) {
        guard let bundleID, bundleID != Bundle.main.bundleIdentifier else { return }
        guard bundleID != lastBundleID else { return }
        let settings = SettingsStore.shared
        let effective = settings.effectiveVietnamese(for: bundleID)
        let previousMode = lastVietnamese
        lastBundleID = bundleID
        lastVietnamese = effective

        if settings.rememberAppMode, settings.vietnameseEnabled != effective {
            settings.vietnameseEnabled = effective
        }

        if settings.showModeSwitchHUD, let previousMode, previousMode != effective {
            ModeIndicatorPanel.show(vietnamese: effective, appName: appName, caret: .zero)
        }
    }
}
