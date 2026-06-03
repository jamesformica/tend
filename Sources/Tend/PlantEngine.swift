import Foundation
import Combine

@MainActor
final class PlantEngine: ObservableObject {
    // Optional — between memorial dismissal and replant we have no active plant.
    @Published private(set) var plant: Plant?
    @Published private(set) var lineage: Lineage
    @Published private(set) var isIdle: Bool = false
    private var idleSeconds: TimeInterval = 0

    // Highest feed tier qualified during the current idle streak, plus the timestamp it was
    // earned (or last upgraded). The user has `waterGraceWindow` seconds from that moment to
    // actually click — subsequent activity doesn't revoke the opportunity. Cleared on a
    // successful feed or when the grace expires.
    @Published private(set) var qualified: QualifiedFeed?

    // Set to an in-between ASCII frame while playing the Wilting → Flowering recovery
    // animation. When non-nil, the popover renders this instead of plant.stage.frame.
    @Published private(set) var recoveryFrame: RecoveryFrame?

    // Tracks whether the popover is currently shown. Tier qualification only accumulates
    // while this is true — opening the popover is the deliberate act of taking a break.
    @Published private(set) var popoverOpen: Bool = false

    // Continuous seconds idle while the popover is open (HID idle gated by popoverOpen).
    // As this crosses each FeedTier.idleThreshold, `qualified` upgrades.
    @Published private(set) var idleInPopover: TimeInterval = 0

    // 0...1 — drives PlantArt color interpolation between dull and vibrant. Set to a tier's
    // peak on feed, then decays linearly back to 0 at vibrancyDecayPerSec.
    @Published private(set) var vibrancy: Double = 0
    private var vibrancyDecayPerSec: Double = 0

    let timings: Timings
    private var lastTickAt: Date = Date()
    private var timer: Timer?

    init(plant: Plant?, lineage: Lineage, timings: Timings = .production) {
        self.plant = plant
        self.lineage = lineage
        self.timings = timings
    }

    static func loadOrCreate(timings: Timings = .production) -> PlantEngine {
        let plant = Storage.loadPlant()
        let lineage = Storage.loadLineage()
        return PlantEngine(plant: plant, lineage: lineage, timings: timings)
    }

    func start() {
        lastTickAt = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: — Popover lifecycle

    func popoverOpened() {
        popoverOpen = true
        idleInPopover = 0
        NotificationHUD.shared.dismissNow()
    }

    func popoverClosed() {
        popoverOpen = false
        idleInPopover = 0
        // qualified persists — once you've earned a tier, the grace window applies.
    }

    // MARK: — Tick

    private func tick() {
        let now = Date()
        let deltaT = now.timeIntervalSince(lastTickAt)
        lastTickAt = now

        idleSeconds = Activity.systemIdleSeconds()
        let nowIdle = idleSeconds >= timings.idleThreshold
        if nowIdle != isIdle { isIdle = nowIdle }

        if vibrancy > 0 {
            vibrancy = max(0, vibrancy - vibrancyDecayPerSec * deltaT)
            if vibrancy == 0 { vibrancyDecayPerSec = 0 }
        }

        guard plant != nil else { return }
        let snapshot = plant

        if popoverOpen {
            if idleInPopover != idleSeconds { idleInPopover = idleSeconds }
            let reached = tierIndex(forIdleSeconds: idleSeconds)
            if let r = reached, r > (qualified?.tier ?? -1) {
                qualified = QualifiedFeed(tier: r, at: Date())
            }
        } else if idleInPopover != 0 {
            idleInPopover = 0
        }

        if let q = qualified, Date().timeIntervalSince(q.at) > timings.waterGraceWindow {
            qualified = nil
        }

        if isIdle {
            if plant!.stage == .flowering {
                plant!.unwateredActive = max(0, plant!.unwateredActive - deltaT * timings.idleDrainRatio)
            } else if plant!.stage.isGrowing,
                      idleSeconds >= timings.passiveBreakThreshold,
                      plant!.unwateredActive > 0 || !plant!.firedNotifications.isEmpty {
                plant!.unwateredActive = 0
                plant!.firedNotifications.removeAll()
            }
        } else {
            plant!.activeAtStage += deltaT
            plant!.unwateredActive += deltaT
            checkTransitions()
        }

        checkNotifications()
        if plant != snapshot { Storage.savePlant(plant!) }
    }

    private func tierIndex(forIdleSeconds s: TimeInterval) -> Int? {
        var result: Int? = nil
        for (i, tier) in timings.feedTiers.enumerated() {
            if s >= tier.idleThreshold { result = i } else { break }
        }
        return result
    }

    private func checkTransitions() {
        guard var p = plant else { return }
        switch p.stage {
        case .seedling:
            advanceIfReady(plant: &p, threshold: timings.seedlingToYoungling, to: .youngling)
        case .youngling:
            advanceIfReady(plant: &p, threshold: timings.younglingToGrowing, to: .growing)
        case .growing:
            advanceIfReady(plant: &p, threshold: timings.growingToFlowering, to: .flowering)
        case .flowering:
            if p.unwateredActive >= timings.floweringToWilting {
                p.stage = .wilting
                p.wiltedCount += 1
            }
        case .wilting:
            if p.unwateredActive >= timings.floweringToWilting + timings.wiltingToDead {
                p.stage = .dead
                handleDeath(&p)
            }
        case .dead:
            break
        }
        plant = p
    }

    private func advanceIfReady(plant p: inout Plant, threshold: TimeInterval, to next: PlantStage) {
        guard p.unwateredActive < timings.growthPauseThreshold else { return }
        guard p.activeAtStage >= threshold else { return }
        p.stage = next
        p.activeAtStage = 0
    }

    private func handleDeath(_ p: inout Plant) {
        lineage.archive(p, diedAt: Date())
        Storage.saveLineage(lineage)
    }

    // MARK: — Notifications

    private func checkNotifications() {
        guard var p = plant else { return }
        let unwatered = p.unwateredActive

        switch p.stage {
        case .flowering:
            fireIfDue(.firstReminder, threshold: timings.firstReminder, unwatered: unwatered, plant: &p)
            fireIfDue(.secondReminder, threshold: timings.secondReminder, unwatered: unwatered, plant: &p)
            fireIfDue(.lastReminder, threshold: timings.lastReminder, unwatered: unwatered, plant: &p)
        case .wilting:
            fireOnce(.wilted, plant: &p)
            fireIfDue(.dying, threshold: timings.dyingReminder, unwatered: unwatered, plant: &p)
        case .dead:
            fireOnce(.dead, plant: &p)
        case .seedling, .youngling, .growing:
            fireIfDue(.growthBreakReminder, threshold: timings.growthBreakReminder, unwatered: unwatered, plant: &p)
            fireIfDue(.growthStalled, threshold: timings.growthPauseThreshold, unwatered: unwatered, plant: &p)
        }
        plant = p
    }

    private func fireIfDue(_ key: NotificationKey, threshold: TimeInterval, unwatered: TimeInterval, plant p: inout Plant) {
        guard unwatered >= threshold else { return }
        fireOnce(key, plant: &p)
    }

    private func fireOnce(_ key: NotificationKey, plant p: inout Plant) {
        guard !p.firedNotifications.contains(key.rawValue) else { return }
        p.firedNotifications.append(key.rawValue)
        Notifications.fire(key, plantName: p.name)
    }

    // MARK: — Feeding

    var canFeed: Bool {
        guard let p = plant, p.stage != .dead else { return false }
        return qualified != nil
    }

    var qualifiedTierConfig: FeedTier? {
        guard let i = qualified?.tier else { return nil }
        return timings.feedTiers[i]
    }

    // Progress info for the popover's "current → next tier" bar. Returns the seconds the
    // user has accumulated past the current tier's threshold, the span up to the next
    // tier's threshold, and the seconds remaining to reach it. nil at the top tier.
    var nextTierProgress: (label: String, into: TimeInterval, span: TimeInterval, remaining: TimeInterval)? {
        let currentIdx = qualified?.tier ?? -1
        let nextIdx = currentIdx + 1
        guard nextIdx < timings.feedTiers.count else { return nil }
        let next = timings.feedTiers[nextIdx]
        let prev: TimeInterval = currentIdx >= 0 ? timings.feedTiers[currentIdx].idleThreshold : 0
        let span = max(0.01, next.idleThreshold - prev)
        let into = max(0, idleInPopover - prev)
        let remaining = max(0, next.idleThreshold - idleInPopover)
        return (next.label, into, span, remaining)
    }

    // Progress toward unlocking the first tier — used before any feed is available.
    var firstTierProgress: (into: TimeInterval, total: TimeInterval, remaining: TimeInterval) {
        let total = timings.feedTiers[0].idleThreshold
        let into = max(0, min(total, idleInPopover))
        return (into, total, max(0, total - idleInPopover))
    }

    @discardableResult
    func feed() -> Bool {
        guard canFeed, let q = qualified else { return false }
        guard var p = plant else { return false }

        let tier = timings.feedTiers[q.tier]

        let wasWilting = p.stage == .wilting
        if wasWilting {
            p.stage = .flowering
        }
        p.unwateredActive = 0
        p.wateredCount += 1
        p.lastWateredAt = Date()
        p.firedNotifications.removeAll()
        plant = p
        qualified = nil
        Storage.savePlant(p)

        // Boost vibrancy to the tier's peak. If the plant is already glowing brighter
        // (rare — only via a higher tier moments ago), keep the higher value.
        vibrancy = max(vibrancy, tier.vibrancyPeak)
        vibrancyDecayPerSec = tier.vibrancyPeak / tier.vibrancyDecay

        if wasWilting {
            playRecoveryAnimation()
        }
        return true
    }

    private func playRecoveryAnimation() {
        recoveryFrame = .step1
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.recoveryFrame = .step2
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.recoveryFrame = nil
        }
    }

    // MARK: — Lifecycle: replant / first plant

    func plantNew(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let chosenName = trimmed.isEmpty ? "Petal" : trimmed
        let ordinal = lineage.nextOrdinal(for: chosenName)
        let seedling = Plant.seedling(name: chosenName, ordinal: ordinal)
        plant = seedling
        Storage.savePlant(seedling)
    }

    var suggestedReplantName: String {
        plant?.name ?? lineage.records.last?.name ?? ""
    }
}

struct QualifiedFeed: Equatable {
    let tier: Int
    let at: Date
}
