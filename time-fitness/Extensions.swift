import SwiftUI
import UIKit

// MARK: - Color

extension Color {
    static func blended(from: UIColor, to: UIColor, amount: Double) -> Color {
        let c = min(max(amount, 0), 1)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2,   green: &g2, blue: &b2, alpha: &a2)
        return Color(uiColor: UIColor(
            red:   r1 + (r2 - r1) * c,
            green: g1 + (g2 - g1) * c,
            blue:  b1 + (b2 - b1) * c,
            alpha: a1 + (a2 - a1) * c
        ))
    }
}

// MARK: - UIImage

extension UIImage {
    /// Load a plant image using the drawable-style path from the catalog,
    /// falling back to the local drawable folder during development.
    static func drawable(named rawPath: String) -> UIImage? {
        let sanitized = rawPath.replacingOccurrences(of: "\\", with: "/")
        let name = (sanitized.split(separator: "/").last.map(String.init) ?? sanitized)
            .replacingOccurrences(of: ".png", with: "")

        if let img = UIImage(named: name) { return img }
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let img = UIImage(contentsOfFile: path) { return img }

        for base in [
            "/Users/yang/.cursor/worktrees/time-fitness/qur",
            "/Users/yang/code/time-fitness"
        ] {
            for candidate in [
                "\(base)/\(sanitized).png",
                "\(base)/\(sanitized)",
                "\(base)/drawable/\(name).png"
            ] {
                if let img = UIImage(contentsOfFile: candidate) { return img }
            }
        }
        return nil
    }

    private static let trimmedCache = NSCache<NSString, UIImage>()

    /// Load image and trim transparent padding to normalize visual size.
    static func drawableNormalized(named rawPath: String) -> UIImage? {
        let key = rawPath as NSString
        if let cached = trimmedCache.object(forKey: key) { return cached }
        guard let image = drawable(named: rawPath) else { return nil }
        let normalized = image.trimTransparentPadding() ?? image
        trimmedCache.setObject(normalized, forKey: key)
        return normalized
    }

    /// Crop fully transparent outer pixels.
    private func trimTransparentPadding() -> UIImage? {
        guard let cg = self.cgImage else { return nil }
        let alphaInfo = cg.alphaInfo
        let alphaOffset: Int
        switch alphaInfo {
        case .premultipliedLast, .last, .noneSkipLast:
            alphaOffset = 3
        case .premultipliedFirst, .first, .noneSkipFirst:
            alphaOffset = 0
        default:
            return nil
        }

        guard let provider = cg.dataProvider,
              let cfData = provider.data,
              let ptr = CFDataGetBytePtr(cfData) else { return nil }

        let width = cg.width
        let height = cg.height
        let bpp = max(cg.bitsPerPixel / 8, 4)
        let bpr = cg.bytesPerRow

        var minX = width, minY = height, maxX = 0, maxY = 0
        var found = false

        for y in 0..<height {
            for x in 0..<width {
                let index = y * bpr + x * bpp + alphaOffset
                if ptr[index] > 0 {
                    found = true
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard found else { return nil }
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - DrawableImage view

/// Renders a plant image from a drawable-catalog path, falling back to a leaf SF Symbol.
struct DrawableImage: View {
    let path: String
    let fallbackColor: Color

    var body: some View {
        if let image = UIImage.drawableNormalized(named: path) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "leaf.fill")
                .resizable().scaledToFit()
                .foregroundStyle(fallbackColor)
                .padding(22)
        }
    }
}
