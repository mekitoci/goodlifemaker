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
}

// MARK: - DrawableImage view

/// Renders a plant image from a drawable-catalog path, falling back to a leaf SF Symbol.
struct DrawableImage: View {
    let path: String
    let fallbackColor: Color

    var body: some View {
        if let image = UIImage.drawable(named: path) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "leaf.fill")
                .resizable().scaledToFit()
                .foregroundStyle(fallbackColor)
                .padding(22)
        }
    }
}
