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
                .foregroundStyleIfPresent(MenubarLabel.tint(for: engine.plant, vibrancy: engine.vibrancy, colorScheme: colorScheme, timings: engine.timings))
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

    // Single source of truth for the menu-bar health color. Both the leaf symbol and the
    // counter read this, so they always agree. Orange = "take a break and water me"
    // (growth stalled, flowering getting thirsty, or freshly wilting); red = "about to
    // die" (final stretch of the wilting window); healthy/dead handled by the callers.
    enum Health { case healthy, warning, critical, dead }

    static func health(for p: Plant, timings: Timings) -> Health {
        switch p.stage {
        case .dead:
            return .dead
        case .wilting:
            // Escalate from orange to red as death nears — dyingReminder sits in the back
            // half of the wilting→dead window.
            return p.unwateredActive >= timings.dyingReminder ? .critical : .warning
        case .flowering:
            // Amber heads-up before it actually wilts, so there's time to step away.
            return p.unwateredActive >= timings.secondReminder ? .warning : .healthy
        case .seedling, .youngling, .growing:
            return p.unwateredActive >= timings.growthPauseThreshold ? .warning : .healthy
        }
    }

    static func counterColor(for p: Plant, timings: Timings) -> Color {
        switch health(for: p, timings: timings) {
        case .critical: return .red
        case .warning:  return .orange
        case .healthy:  return .primary
        case .dead:     return .secondary // counter is hidden when dead; here for completeness
        }
    }

    static func symbol(for stage: PlantStage) -> String {
        switch stage {
        case .seedling, .youngling: return "leaf"
        case .growing, .flowering, .wilting, .dead: return "leaf.fill"
        }
    }

    static func tint(for plant: Plant?, vibrancy: Double, colorScheme: ColorScheme, timings: Timings) -> Color? {
        // No plant yet (between memorial and replant) — show the healthy vibrancy bloom.
        guard let p = plant else {
            return PlantArt.menuBarTint(for: .leaf, vibrancy: vibrancy, colorScheme: colorScheme)
        }
        switch health(for: p, timings: timings) {
        case .critical: return .red
        case .warning:  return .orange
        case .dead:     return .secondary
        case .healthy:  return PlantArt.menuBarTint(for: .leaf, vibrancy: vibrancy, colorScheme: colorScheme)
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
