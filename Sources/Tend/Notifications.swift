import Foundation

enum NotificationKey: String, CaseIterable {
    case growthBreakReminder
    case growthStalled
    case firstReminder
    case secondReminder
    case lastReminder
    case wilted
    case dying
    case dead

    func message(plantName: String) -> String {
        switch self {
        case .growthBreakReminder: return "ready for a stretch?"
        case .growthStalled:       return "growth's on pause — let's both take a breather."
        case .firstReminder:       return "soil's getting a touch dry."
        case .secondReminder:      return "leaves are feeling heavy."
        case .lastReminder:        return "if i don't get water soon…"
        case .wilted:              return "i've wilted."
        case .dying:               return "last chance — i'm fading."
        case .dead:                return "goodbye, \(plantName)."
        }
    }

    var severity: HUDSeverity {
        switch self {
        case .growthBreakReminder, .growthStalled: return .neutral
        case .firstReminder, .secondReminder, .lastReminder: return .neutral
        case .wilted, .dying: return .warning
        case .dead: return .lost
        }
    }
}

enum Notifications {
    @MainActor
    static func fire(_ key: NotificationKey, plantName: String) {
        NotificationHUD.shared.show(
            message: key.message(plantName: plantName),
            severity: key.severity
        )
    }
}
