import Foundation

enum Storage {
    static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tend", isDirectory: true)
    }

    static var plantFile: URL { appSupportDir.appendingPathComponent("plant.json") }
    static var lineageFile: URL { appSupportDir.appendingPathComponent("lineage.json") }

    // MARK: — Plant (current alive/dead plant)

    static func savePlant(_ plant: Plant) {
        ensureDir()
        do {
            let data = try encoder().encode(plant)
            try data.write(to: plantFile, options: .atomic)
        } catch {
            NSLog("Tend: failed to save plant — \(error)")
        }
    }

    static func loadPlant() -> Plant? {
        guard let data = try? Data(contentsOf: plantFile) else { return nil }
        return try? decoder().decode(Plant.self, from: data)
    }

    static func deletePlant() {
        try? FileManager.default.removeItem(at: plantFile)
    }

    // MARK: — Lineage (archived past plants)

    static func saveLineage(_ lineage: Lineage) {
        ensureDir()
        do {
            let data = try encoder().encode(lineage)
            try data.write(to: lineageFile, options: .atomic)
        } catch {
            NSLog("Tend: failed to save lineage — \(error)")
        }
    }

    static func loadLineage() -> Lineage {
        guard let data = try? Data(contentsOf: lineageFile),
              let lineage = try? decoder().decode(Lineage.self, from: data) else {
            return Lineage()
        }
        return lineage
    }

    // MARK: — Helpers

    private static func ensureDir() {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
