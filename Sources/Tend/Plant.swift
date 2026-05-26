import Foundation

struct Plant: Codable, Equatable {
    var name: String
    var ordinal: Int
    var stage: PlantStage
    var plantedAt: Date
    var lastWateredAt: Date?

    // Active seconds accumulated while in the current growth stage. Resets on stage advance.
    // Drives Seedling → Youngling → Growing → Flowering transitions.
    var activeAtStage: TimeInterval

    // Active seconds accumulated since the last watering. Resets to 0 on Water click.
    // Drives Flowering → Wilting → Dead decay. Idle drains this at Flowering (1:4 ratio).
    var unwateredActive: TimeInterval

    var wateredCount: Int
    var wiltedCount: Int

    // NotificationKey raw values that have already fired for this plant's current decay cycle.
    // Cleared on water() so reminders re-arm. Persists across launches so we don't re-fire after restart.
    var firedNotifications: [String]

    static func seedling(name: String, ordinal: Int = 1) -> Plant {
        Plant(
            name: name,
            ordinal: ordinal,
            stage: .seedling,
            plantedAt: Date(),
            lastWateredAt: nil,
            activeAtStage: 0,
            unwateredActive: 0,
            wateredCount: 0,
            wiltedCount: 0,
            firedNotifications: []
        )
    }
}

extension PlantStage: Codable {}
