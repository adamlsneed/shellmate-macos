import SwiftUI

/// Shellmate color palette matching the Electron app's Tailwind config.
/// shell-* = neon cyan accent, navy-* = dark background
enum ShellmateColors {
    // MARK: - Shell (Neon Cyan Accent)
    static let shell50  = Color(hex: 0xECFEFF)
    static let shell100 = Color(hex: 0xCFFAFE)
    static let shell200 = Color(hex: 0xA5F3FC)
    static let shell300 = Color(hex: 0x67E8F9)
    static let shell400 = Color(hex: 0x22D3EE)  // Primary accent
    static let shell500 = Color(hex: 0x06B6D4)
    static let shell600 = Color(hex: 0x0891B2)
    static let shell700 = Color(hex: 0x0E7490)

    // MARK: - Navy (Dark Background)
    static let navy600  = Color(hex: 0x3D4663)
    static let navy700  = Color(hex: 0x2D3450)
    static let navy800  = Color(hex: 0x222840)
    static let navy850  = Color(hex: 0x1E2338)
    static let navy900  = Color(hex: 0x1A1F2E)  // Primary background
    static let navy950  = Color(hex: 0x131825)  // Deepest background

    // MARK: - Semantic
    static let background = navy950
    static let surface = navy900
    static let surfaceHover = navy850
    static let accent = shell400
    static let accentDim = shell600
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.4)
    static let error = Color(hex: 0xEF4444)
    static let success = Color(hex: 0x22C55E)
    static let warning = Color(hex: 0xF59E0B)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
