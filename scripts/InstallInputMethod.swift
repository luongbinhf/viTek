import Foundation

/// Uses the same update/activation implementation as the GUI installer.
@main struct InstallInputMethod {
    @MainActor static func main() async {
        do { try await install() }
        catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }

    @MainActor private static func install() async throws {
        guard CommandLine.arguments.count == 4 else {
            throw Installation.Failure(message: "Expected payload, destination and activation flag")
        }
        let payload = URL(fileURLWithPath: CommandLine.arguments[1])
        let destination = URL(fileURLWithPath: CommandLine.arguments[2])
        try await Installation.update(from: payload, to: destination)
        if CommandLine.arguments[3] == "activate" {
            try await Installation.reconnect(at: destination)
        }
        print("Installed \(destination.path)")
    }
}
