import SwiftUI

// Tag for one character of a plant frame — drives which color from the palette is used.
// Stored in a parallel "mask" string aligned char-by-char with the frame.
enum PlantPart {
    case pot, stem, leaf, flower

    init?(maskChar: Character) {
        switch maskChar {
        case "P": self = .pot
        case "S": self = .stem
        case "L": self = .leaf
        case "F": self = .flower
        default: return nil
        }
    }
}

// Two sRGB endpoints per part. The plant linearly interpolates between dull and vibrant
// as vibrancy moves between 0 and 1. Dull palette is desaturated but not invisible — the
// plant should look "tired but alive" between feeds.
struct PartColor {
    let dull: (r: Double, g: Double, b: Double)
    let vibrant: (r: Double, g: Double, b: Double)

    func color(vibrancy t: Double) -> Color {
        PlantArt.interpolatedColor(from: dull, to: vibrant, t: t)
    }
}

enum PlantArt {
    static let palette: [PlantPart: PartColor] = [
        .pot:    PartColor(dull: (0.50, 0.42, 0.34), vibrant: (0.78, 0.46, 0.28)),
        .stem:   PartColor(dull: (0.42, 0.50, 0.38), vibrant: (0.22, 0.58, 0.30)),
        .leaf:   PartColor(dull: (0.46, 0.54, 0.40), vibrant: (0.38, 0.78, 0.36)),
        .flower: PartColor(dull: (0.62, 0.52, 0.56), vibrant: (0.98, 0.40, 0.62)),
    ]

    // For the menu bar leaf icon: returns nil at vibrancy ~0 so the SF Symbol's automatic
    // template color (white on dark bars, black on light) reads at full contrast. As
    // vibrancy climbs, interpolates from that base toward the part's vibrant color — the
    // icon briefly blooms green after a feed and fades back to readable.
    static func menuBarTint(for part: PlantPart, vibrancy: Double, colorScheme: ColorScheme) -> Color? {
        if vibrancy < 0.02 { return nil }
        guard let vibrant = palette[part]?.vibrant else { return nil }
        let base: (r: Double, g: Double, b: Double) = colorScheme == .dark ? (1, 1, 1) : (0, 0, 0)
        return interpolatedColor(from: base, to: vibrant, t: vibrancy)
    }

    static func render(frame: String, stage: PlantStage, vibrancy: Double) -> AttributedString {
        switch stage {
        case .wilting: return uniform(frame, color: .red)
        case .dead:    return uniform(frame, color: .secondary)
        default:       break
        }

        guard let mask = mask(for: stage) else {
            return uniform(frame, color: .primary)
        }

        // Resolve part colors once per render, then emit one AttributedString per
        // contiguous run of same-part characters — drops ~100 per-char allocations
        // down to ~10–20 runs for the largest frames.
        let runColor: [PlantPart: Color] = palette.mapValues { $0.color(vibrancy: vibrancy) }
        let frameChars = Array(frame)
        let maskChars = Array(mask)

        var result = AttributedString()
        var i = 0
        while i < frameChars.count {
            let part = partAt(i, in: maskChars)
            var j = i + 1
            while j < frameChars.count, partAt(j, in: maskChars) == part { j += 1 }
            var piece = AttributedString(String(frameChars[i..<j]))
            piece.foregroundColor = part.flatMap { runColor[$0] } ?? .primary
            result += piece
            i = j
        }
        return result
    }

    static func interpolatedColor(from src: (r: Double, g: Double, b: Double), to dst: (r: Double, g: Double, b: Double), t: Double) -> Color {
        let t = max(0, min(1, t))
        let r = src.r + (dst.r - src.r) * t
        let g = src.g + (dst.g - src.g) * t
        let b = src.b + (dst.b - src.b) * t
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    static func uniform(_ frame: String, color: Color) -> AttributedString {
        var attr = AttributedString(frame)
        attr.foregroundColor = color
        return attr
    }

    private static func partAt(_ i: Int, in mask: [Character]) -> PlantPart? {
        guard i < mask.count else { return nil }
        return PlantPart(maskChar: mask[i])
    }

    // MARK: — Masks

    // Each mask is built by joining its line array with "\n" — same shape as the
    // corresponding multiline literal in PlantFrames.swift after Swift's leading-
    // and trailing-newline removal. Each character in a line tags the same column
    // in the frame: P=pot, S=stem, L=leaf, F=flower, ' '=untagged.
    private static func mask(for stage: PlantStage) -> String? {
        switch stage {
        case .seedling:  return seedlingMask
        case .youngling: return younglingMask
        case .growing:   return growingMask
        case .flowering: return floweringMask
        case .wilting, .dead: return nil
        }
    }

    private static let seedlingMask: String = [
        "",
        "",
        "",
        "",
        "",
        "",
        "PPPPPPP",
        " PPPPP",
    ].joined(separator: "\n")

    private static let younglingMask: String = [
        "",
        "",
        "",
        "",
        "    L",
        " SSSLL",
        "PPPPPPP",
        " PPPPP",
    ].joined(separator: "\n")

    private static let growingMask: String = [
        "",
        "",
        "",
        "  LL",
        "   SLL",
        " LLSLL",
        "PPPPPPP",
        " PPPPP",
    ].joined(separator: "\n")

    private static let floweringMask: String = [
        "      F",
        "    FFFFF",
        "   FFFFFFF",
        "    FFFF",
        " LSS",
        " L SLL",
        "PPPPPPP",
        " PPPPP",
    ].joined(separator: "\n")
}
