import AppKit
import Carbon

/// Install per user, then let Text Input Sources handle registration and system consent.
@MainActor
enum Installation {
    static let bundleID = "io.github.luongbinhf.inputmethod.viTek"

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func install() async throws -> URL {
        let files = FileManager.default
        let payload = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/viTek.app")
        let library = try files.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let destination = library.appendingPathComponent("Input Methods/viTek.app")
        try await update(from: payload, to: destination)
        return destination
    }

    /// Shared by the GUI and dev installer. Validate first, leave the selected input session,
    /// stop the old server gracefully, then atomically replace the bundle. Never kill the menu agent.
    static func update(from payload: URL, to destination: URL) async throws {
        try validate(payload)
        let files = FileManager.default
        if files.contentsEqual(atPath: payload.path, andPath: destination.path) { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter {
            $0.bundleURL?.standardizedFileURL == destination.standardizedFileURL
        }
        if !running.isEmpty, isSelected { try await selectFallback() }
        for app in running where !app.isTerminated {
            guard app.terminate() || app.isTerminated else {
                throw Failure(message: "Không thể dừng phiên viTek cũ an toàn. Hãy chuyển nguồn nhập rồi thử lại.")
            }
        }
        for _ in 0..<40 {
            if running.allSatisfy(\.isTerminated) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard running.allSatisfy(\.isTerminated) else {
            throw Failure(message: "Phiên viTek cũ chưa kết thúc; bản cài được giữ nguyên. Hãy chuyển nguồn nhập rồi thử lại.")
        }
        try copyInputMethod(from: payload, to: destination)
    }

    private static func validate(_ payload: URL) throws {
        let files = FileManager.default
        guard let app = Bundle(url: payload), app.bundleIdentifier == bundleID,
              let executable = app.executableURL, files.isExecutableFile(atPath: executable.path),
              app.url(forResource: "AppIcon", withExtension: "icns") != nil else {
            throw Failure(message: "Bộ cài thiếu ứng dụng viTek hoặc logo. Hãy mở lại từ bản DMG đầy đủ.")
        }
    }

    static func copyInputMethod(from payload: URL, to destination: URL) throws {
        let files = FileManager.default
        try validate(payload)
        let directory = destination.deletingLastPathComponent()
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = try files.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                    appropriateFor: directory, create: true)
        defer { try? files.removeItem(at: staging) }
        let copy = staging.appendingPathComponent("viTek.app")
        try files.copyItem(at: payload, to: copy)
        if files.fileExists(atPath: destination.path) {
            guard Bundle(url: destination)?.bundleIdentifier == bundleID else {
                throw Failure(message: "Thư mục nguồn nhập đã có một ứng dụng khác cùng tên viTek.app.")
            }
            _ = try files.replaceItemAt(destination, withItemAt: copy, options: .usingNewMetadataOnly)
        } else {
            try files.moveItem(at: copy, to: destination)
        }
    }

    private static var isSelected: Bool {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id = TISGetInputSourceProperty(current, kTISPropertyBundleID) else { return false }
        return Unmanaged<CFString>.fromOpaque(id).takeUnretainedValue() as String == bundleID
    }

    private static func selectFallback() async throws {
        guard let layout = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              TISSelectInputSource(layout) == noErr else {
            throw Failure(message: "Chưa kết thúc được phiên nhập cũ. Chọn ABC trong menu nguồn nhập rồi thử lại.")
        }
        guard try await waitForSelection(vitek: false) else {
            throw Failure(message: "Phiên nhập cũ chưa chuyển sang ABC; bản cài được giữ nguyên để thử lại.")
        }
    }

    private static func waitForSelection(vitek: Bool) async throws -> Bool {
        for _ in 0..<10 {
            if isSelected == vitek { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return isSelected == vitek
    }

    static func reconnect(at url: URL) async throws {
        if isSelected { try await selectFallback() }
        try await activate(at: url)
    }

    static func activate(at url: URL) async throws {
        let status = TISRegisterInputSource(url as CFURL)
        guard status == noErr else {
            throw Failure(message: "macOS chưa đăng ký được viTek (\(status)). Bản cài vẫn được giữ nguyên để thử lại.")
        }
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
              let source = sources.first(where: { source in
                  guard let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else { return false }
                  return Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue() == kCFBooleanTrue
              }) else {
            throw Failure(message: "macOS chưa nhận nguồn nhập viTek. Trong Bàn phím → Nhập văn bản, thêm viTek trong nhóm Tiếng Việt rồi thử lại.")
        }
        let enabledProperty = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled)
        let alreadyEnabled = enabledProperty.map {
            Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue
        } ?? false
        // Re-enabling an already enabled source can reopen the system consent sheet for each
        // freshly compiled dev helper, stealing focus from the application being tested.
        let enabled = alreadyEnabled ? noErr : TISEnableInputSource(source)
        guard enabled == noErr else {
            throw Failure(message: "Chưa bật được viTek (\(enabled)). Hãy cho phép bật nguồn nhập khi macOS hỏi rồi thử lại.")
        }
        // Registration/selection can succeed without launching a stopped IMK server.
        // Start the exact installed bundle in the background before waiting for its handshake.
        let launch = NSWorkspace.OpenConfiguration()
        launch.activates = false
        launch.addsToRecentItems = false
        let running = try await NSWorkspace.shared.openApplication(at: url, configuration: launch)
        guard running.bundleURL?.standardizedFileURL == url.standardizedFileURL else {
            throw Failure(message: "macOS đã mở một bản viTek khác. Bản cài được giữ nguyên để thử lại.")
        }
        guard TISSelectInputSource(source) == noErr, try await waitForSelection(vitek: true) else {
            throw Failure(message: "Ô nhập hiện tại chưa cho chọn viTek. Chọn một ô văn bản thường rồi thử lại.")
        }
        let version = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !version.isEmpty, try await InputMethodConnection.check(version: version, bundleURL: url) else {
            throw Failure(message: "Đã chọn nguồn nhập nhưng viTek chưa trả lời. Bấm Thử lại để kết nối lại; nếu chỉ một ứng dụng không nhận phím, mở lại ứng dụng đó.")
        }
    }
}
