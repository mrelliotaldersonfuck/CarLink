import SwiftUI

/// Central color palette for CarLink's dark theme. Keeping the colors in one
/// place makes the iPhone UI and the CarPlay assets look like one product.
enum Theme {
    static let background = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x16161D)
    static let surfaceRaised = Color(hex: 0x1F1F29)
    static let stroke = Color(hex: 0x2C2C38)
    static let accent = Color(hex: 0x4C8DFF)
    static let textPrimary = Color(hex: 0xF4F4F7)
    static let textSecondary = Color(hex: 0x9A9AA8)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
