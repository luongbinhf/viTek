import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Displays the bundled viTek Lac Owl mascot artwork (`BrandMascot.png`) cleanly on macOS & iOS.
struct BrandMascotView: View {
    let size: CGFloat

    var body: some View {
        #if os(macOS)
        if let image = Self.macImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            MacAppIcon(size: size)
        }
        #elseif os(iOS)
        if let image = Self.iosImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
        #endif
    }

    #if os(macOS)
    private static let macImage: NSImage? = Bundle.main.url(forResource: "BrandMascot", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
    #elseif os(iOS)
    private static let iosImage: UIImage? = Bundle.main.url(forResource: "BrandMascot", withExtension: "png")
        .flatMap { UIImage(contentsOfFile: $0.path) }
    #endif
}
