import SwiftUI

/// Commvault brand color palette derived from commvault.com
enum CommvaultColors {
    // MARK: - Primary
    static let deepPurple = Color(hex: "1A054F")
    static let purple = Color(hex: "381D56")
    static let mediumPurple = Color(hex: "783D7A")
    static let lightPurple = Color(hex: "925A8E")

    // MARK: - Accent / Rose
    static let rosePink = Color(hex: "CB9298")
    static let coral = Color(hex: "E4ABA1")
    static let peach = Color(hex: "F0C4A3")
    static let hotPink = Color(hex: "F495B1")

    // MARK: - Supporting
    static let navyBlue = Color(hex: "2A3176")
    static let lavender = Color(hex: "E5D2EE")
    static let eggshell = Color(hex: "E2E3F1")
    static let darkPlum = Color(hex: "4B2E54")

    // MARK: - Semantic
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9500")
    static let critical = Color(hex: "FF3B30")
    static let info = Color(hex: "5AC8FA")

    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [peach, hotPink, mediumPurple, deepPurple],
        startPoint: .bottom,
        endPoint: .top
    )

    static let footerGradient = LinearGradient(
        colors: [Color(hex: "EFCAB7"), hotPink, lightPurple, purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        colors: [deepPurple, navyBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [rosePink, hotPink],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
