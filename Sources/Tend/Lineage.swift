import Foundation

struct PlantRecord: Codable, Identifiable {
    let id: UUID
    let name: String
    let ordinal: Int
    let plantedAt: Date
    let diedAt: Date
    let wateredCount: Int
    let wiltedCount: Int

    var lifespan: TimeInterval { diedAt.timeIntervalSince(plantedAt) }
}

struct Lineage: Codable {
    var records: [PlantRecord] = []

    // Next roman-numeral ordinal for a given base name. Case-insensitive, whitespace-trimmed.
    // Returns 1 for a name with no history (so the UI renders no numeral — first of its kind).
    func nextOrdinal(for baseName: String) -> Int {
        let normalized = baseName.trimmingCharacters(in: .whitespaces).lowercased()
        let priorCount = records.filter {
            $0.name.trimmingCharacters(in: .whitespaces).lowercased() == normalized
        }.count
        return priorCount + 1
    }

    mutating func archive(_ plant: Plant, diedAt: Date) {
        let record = PlantRecord(
            id: UUID(),
            name: plant.name,
            ordinal: plant.ordinal,
            plantedAt: plant.plantedAt,
            diedAt: diedAt,
            wateredCount: plant.wateredCount,
            wiltedCount: plant.wiltedCount
        )
        records.append(record)
    }
}
