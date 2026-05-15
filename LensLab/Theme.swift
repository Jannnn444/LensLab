import SwiftUI

// MARK: - Theme
enum Theme {
    static let bg          = Color(hex: "#F5F0E8")
    static let surface     = Color(hex: "#FAF7F0")
    static let panel       = Color(hex: "#F0EAD8")
    static let border      = Color(hex: "#DDC9A0")
    static let accent      = Color(hex: "#B8932A")
    static let accentDark  = Color(hex: "#8A6E20")
    static let text        = Color(hex: "#2C2410")
    static let muted       = Color(hex: "#9A8660")
    static let canvasBg    = Color(hex: "#E8E0CC")
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 6 { h += "FF" }
        let v = UInt64((try? UInt64(h, radix: 16)) ?? 0)
        self.init(
            red:   Double((v >> 24) & 0xFF) / 255,
            green: Double((v >> 16) & 0xFF) / 255,
            blue:  Double((v >>  8) & 0xFF) / 255,
            opacity: Double(v & 0xFF) / 255
        )
    }
}

// MARK: - Typography helpers
extension Font {
    static let displaySerif = Font.custom("Georgia", size: 22).italic()
    static let monoSmall    = Font.system(size: 10, weight: .regular, design: .monospaced)
    static let monoTiny     = Font.system(size: 9,  weight: .regular, design: .monospaced)
    static let monoBody     = Font.system(size: 11, weight: .regular, design: .monospaced)
}
