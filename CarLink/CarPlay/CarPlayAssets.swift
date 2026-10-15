import CarPlay
import UIKit

/// Renders SF Symbols into display-ready images sized to the car screen's
/// scale, with light and dark variants so icons stay sharp and legible on
/// every head unit. This is what makes the CarPlay icons adapt to each screen.
enum CarPlayAssets {

    @MainActor
    static func gridImage(symbol: String, tint: UInt32, traits: UITraitCollection, scale: CGFloat) -> UIImage {
        let canvas: CGSize
        if #available(iOS 26.0, *) {
            canvas = CPGridTemplate.maximumGridButtonImageSize
        } else {
            canvas = CGSize(width: 64, height: 64)
        }
        return symbolImage(symbol: symbol,
                           canvas: canvas,
                           pointSize: min(canvas.width, canvas.height) * 0.52,
                           tint: tint,
                           traits: traits,
                           scale: scale)
    }

    @MainActor
    static func listImage(symbol: String, tint: UInt32, traits: UITraitCollection, scale: CGFloat) -> UIImage {
        let canvas = CPListItem.maximumImageSize == .zero ? CGSize(width: 44, height: 44) : CPListItem.maximumImageSize
        return symbolImage(symbol: symbol,
                           canvas: canvas,
                           pointSize: min(canvas.width, canvas.height) * 0.6,
                           tint: tint,
                           traits: traits,
                           scale: scale)
    }

    private static func symbolImage(symbol: String, canvas: CGSize, pointSize: CGFloat, tint: UInt32, traits: UITraitCollection, scale: CGFloat) -> UIImage {
        func render(_ color: UIColor) -> UIImage {
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            let base = UIImage(systemName: symbol, withConfiguration: config) ?? UIImage()
            let format = UIGraphicsImageRendererFormat()
            format.scale = max(1, scale)
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
            return renderer.image { _ in
                let tinted = base.withTintColor(color, renderingMode: .alwaysOriginal)
                let origin = CGPoint(x: (canvas.width - tinted.size.width) / 2,
                                     y: (canvas.height - tinted.size.height) / 2)
                tinted.draw(at: origin)
            }
        }

        let asset = UIImageAsset()
        asset.register(render(color(from: tint, style: .light)), with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(render(color(from: tint, style: .dark)), with: UITraitCollection(userInterfaceStyle: .dark))
        return asset.image(with: traits)
    }

    /// Brand tints read well on dark car themes; on light themes we darken them
    /// a touch so the icon keeps enough contrast.
    private static func color(from hex: UInt32, style: UIUserInterfaceStyle) -> UIColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        let base = UIColor(red: r, green: g, blue: b, alpha: 1)
        guard style == .light else { return base }
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        if base.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) {
            return UIColor(hue: hue, saturation: min(1, sat * 1.05), brightness: bri * 0.72, alpha: alpha)
        }
        return base
    }
}
