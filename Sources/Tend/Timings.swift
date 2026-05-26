import Foundation

// A feeding tier. Unlocks once continuous idle in the popover crosses idleThreshold.
// On feed, sets the plant's vibrancy to vibrancyPeak, which decays back to 0 over vibrancyDecay seconds.
struct FeedTier {
    let idleThreshold: TimeInterval
    let vibrancyPeak: Double
    let vibrancyDecay: TimeInterval
    let label: String
}

struct Timings {
    // Growth thresholds — active seconds accumulated at each stage before advancing.
    let seedlingToYoungling: TimeInterval
    let younglingToGrowing: TimeInterval
    let growingToFlowering: TimeInterval

    // Decay thresholds — unwatered active seconds.
    let floweringToWilting: TimeInterval
    let wiltingToDead: TimeInterval

    // Feeding tiers in ascending unlock order. [0] = water, [1] = fertilize, [2] = feast.
    // The highest tier reached during the current idle streak is the one that fires on click.
    let feedTiers: [FeedTier]
    var minIdleForFeed: TimeInterval { feedTiers[0].idleThreshold }
    var maxIdleForFeed: TimeInterval { feedTiers.last?.idleThreshold ?? feedTiers[0].idleThreshold }

    // Idle drain ratio. 0.25 = 1 second of unwateredActive drained per 4 seconds idle.
    // Only applies while the plant is at Flowering — once it Wilts, only Water revives.
    let idleDrainRatio: Double

    // While growing (Seedling/Youngling/Growing), growth pauses if unwateredActive exceeds this.
    // Stops you from growing a plant you're neglecting.
    let growthPauseThreshold: TimeInterval

    // Active vs idle threshold — HIDIdleTime above this is "idle".
    let idleThreshold: TimeInterval

    // Once a tier has been earned, the watering opportunity stays valid for this long
    // (even if the user becomes active again). Solves the "button disables when you reach
    // for it" problem. Cleared when the user actually feeds.
    let waterGraceWindow: TimeInterval

    // Continuous idle seconds that count as a "passive break". During Seedling/Youngling/
    // Growing, when idle crosses this, unwateredActive resets to 0 and reminders re-arm —
    // so overnight/lunch idle doesn't carry yesterday's counter into today. Flowering
    // keeps its own gradual drain (idleDrainRatio); Wilting/Dead are unaffected.
    let passiveBreakThreshold: TimeInterval

    // Notification thresholds — values of `unwateredActive` at which each reminder fires.
    let firstReminder: TimeInterval
    let secondReminder: TimeInterval
    let lastReminder: TimeInterval
    let dyingReminder: TimeInterval

    // Growth-stage break nudge — fires during Seedling/Youngling/Growing when the user has
    // been active this long without watering.
    let growthBreakReminder: TimeInterval

    // Compressed timings for engine verification. Whole lifecycle in ~3 minutes.
    static let testing = Timings(
        seedlingToYoungling: 20,
        younglingToGrowing: 40,
        growingToFlowering: 60,
        floweringToWilting: 30,
        wiltingToDead: 15,
        feedTiers: [
            FeedTier(idleThreshold: 10, vibrancyPeak: 0.25, vibrancyDecay: 30,  label: "water"),
            FeedTier(idleThreshold: 25, vibrancyPeak: 0.65, vibrancyDecay: 90,  label: "fertilize"),
            FeedTier(idleThreshold: 45, vibrancyPeak: 1.0,  vibrancyDecay: 180, label: "feast"),
        ],
        idleDrainRatio: 0.25,
        growthPauseThreshold: 15,
        idleThreshold: 3,
        waterGraceWindow: 60,
        passiveBreakThreshold: 30,
        firstReminder: 15,
        secondReminder: 22,
        lastReminder: 27,
        dyingReminder: 37,
        growthBreakReminder: 8
    )

    // Real-world timings — locked in our design discussion.
    static let production = Timings(
        seedlingToYoungling: 4 * 3600,
        younglingToGrowing: 8 * 3600,
        growingToFlowering: 12 * 3600,
        floweringToWilting: 4 * 3600,
        wiltingToDead: 2 * 3600,
        feedTiers: [
            FeedTier(idleThreshold: 60,  vibrancyPeak: 0.25, vibrancyDecay: 60,  label: "water"),
            FeedTier(idleThreshold: 180, vibrancyPeak: 0.65, vibrancyDecay: 300, label: "fertilize"),
            FeedTier(idleThreshold: 300, vibrancyPeak: 1.0,  vibrancyDecay: 900, label: "feast"),
        ],
        idleDrainRatio: 0.25,
        growthPauseThreshold: 2 * 3600,
        idleThreshold: 60,
        waterGraceWindow: 5 * 60,
        passiveBreakThreshold: 5 * 60,
        firstReminder: 5400,
        secondReminder: 9000,
        lastReminder: 12600,
        dyingReminder: 18000,
        growthBreakReminder: 3600
    )
}
