#if os(macOS)
import SwiftUI

/// Read the bundled artwork directly, including when the IMK host runs without a Dock icon.
struct MacAppIcon: View {
    let size: CGFloat

    private static let artwork = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:)) ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    var body: some View {
        Image(nsImage: Self.artwork)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
#endif
