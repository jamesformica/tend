import SwiftUI

@main
struct TendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// Hosted inside the NSStatusItem button via NSHostingView so we can keep the dynamic
// SwiftUI menu-bar label (leaf + counter + optional drop) while owning the status item
// directly via AppKit (which is required to anchor the notification HUD reliably).
struct MenubarLabelView: View {
    @ObservedObject var engine: PlantEngine
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let stage = engine.plant?.stage ?? .seedling
        HStack(spacing: 2) {
            Image(systemName: MenubarLabel.symbol(for: stage))
                .foregroundStyleIfPresent(MenubarLabel.tint(stage: stage, vibrancy: engine.vibrancy, colorScheme: colorScheme))
            if let p = engine.plant, p.stage != .dead {
                Text(MenubarLabel.counterText(for: p, timings: engine.timings))
                    .monospacedDigit()
                    .foregroundStyle(MenubarLabel.counterColor(for: p, timings: engine.timings))
            }
            if engine.canFeed {
                Image(systemName: "drop.degreesign")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 4)
    }
}

// Pure formatting / styling for the menu-bar label. Hoisted out of the view so the
// AppDelegate cache key can be computed from the same inputs without re-implementing
// the display logic.
enum MenubarLabel {
    static func counterText(for p: Plant, timings: Timings) -> String {
        let needsAttention = p.unwateredActive >= timings.growthBreakReminder
        return formatDuration(p.unwateredActive) + (needsAttention ? "*" : "")
    }

    static func counterColor(for p: Plant, timings: Timings) -> Color {
        if p.stage == .wilting { return .red }
        if p.unwateredActive >= timings.growthPauseThreshold { return .orange }
        return .primary
    }

    static func symbol(for stage: PlantStage) -> String {
        switch stage {
        case .seedling, .youngling: return "leaf"
        case .growing, .flowering, .wilting, .dead: return "leaf.fill"
        }
    }

    static func tint(stage: PlantStage, vibrancy: Double, colorScheme: ColorScheme) -> Color? {
        switch stage {
        case .seedling, .youngling, .growing, .flowering:
            return PlantArt.menuBarTint(for: .leaf, vibrancy: vibrancy, colorScheme: colorScheme)
        case .wilting: return .red
        case .dead:    return .secondary
        }
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total < 60 { return "\(total)s" }
        let h = total / 3600
        let m = (total % 3600) / 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

private extension View {
    @ViewBuilder
    func foregroundStyleIfPresent(_ color: Color?) -> some View {
        if let color { foregroundStyle(color) } else { self }
    }
}
