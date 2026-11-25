import SwiftUI
import VitekSession

/// Crisp rounded-square SF Symbol badge (or live RGB color swatch for `#RRGGBB` snippets) shared by macOS and iOS.
struct ClipboardKindBadge: View {
    let item: ClipboardItem
    var size: CGFloat = 28

    private var tint: Color {
        switch item.kind {
        case .url: .blue
        case .email: .indigo
        case .phone: .green
        case .otp: .orange
        case .hexColor: .pink
        case .code: .purple
        case .multiline: .teal
        case .text: .secondary
        }
    }

    var body: some View {
        if item.kind == .hexColor, let rgb = item.parsedHexColor {
            let swatch = Color(red: rgb.redFraction, green: rgb.greenFraction, blue: rgb.blueFraction)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(swatch.gradient)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: swatch.opacity(0.32), radius: 2, y: 1)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1)
            }
            .accessibilityLabel("Mã màu \(item.preview)")
        } else {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                .shadow(color: tint.opacity(0.22), radius: 1.5, y: 0.75)
                .accessibilityLabel(item.kind.badgeTitle)
        }
    }
}
