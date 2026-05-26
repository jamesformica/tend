import SwiftUI

struct PopoverView: View {
    @ObservedObject var engine: PlantEngine
    @State private var isReplanting: Bool = false
    @State private var nameInput: String = ""

    var body: some View {
        Group {
            if isReplanting || engine.plant == nil {
                namingView
            } else if engine.plant?.stage == .dead {
                memorialView
            } else {
                aliveView
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    // MARK: — Alive

    private var aliveView: some View {
        let plant = engine.plant!
        return VStack(alignment: .leading, spacing: 12) {
            Text(displayName(plant))
                .font(.system(.title3, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .center)

            plantFrameText(plantFrame(plant))

            sectionDivider(plant.stage.rawValue)

            Text(unwateredString(plant))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            feedControl(plant)

            asciiHRule

            quitButton
        }
    }

    // MARK: — Memorial

    private var memorialView: some View {
        let plant = engine.plant!
        return VStack(alignment: .leading, spacing: 12) {
            Text("in memory of")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(displayName(plant))
                .font(.system(.title3, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .center)

            plantFrameText(PlantArt.render(frame: PlantStage.dead.frame, stage: .dead, vibrancy: 0))

            sectionDivider("lifetime")

            if let record = engine.lineage.records.last {
                VStack(alignment: .leading, spacing: 4) {
                    statRow("lived", formatDuration(record.lifespan))
                    statRow("watered", "\(record.wateredCount) times")
                    statRow("wilted", "\(record.wiltedCount) " + (record.wiltedCount == 1 ? "time" : "times"))
                }
                .font(.system(.caption, design: .monospaced))
            }

            asciiHRule

            Button {
                nameInput = engine.suggestedReplantName
                isReplanting = true
            } label: {
                Text("plant a new seedling")
                    .frame(maxWidth: .infinity)
            }

            quitButton
        }
    }

    // MARK: — Naming (first launch or post-memorial replant)

    private var namingView: some View {
        let isFirstLaunch = engine.lineage.records.isEmpty && engine.plant == nil
        return VStack(alignment: .leading, spacing: 12) {
            if isFirstLaunch {
                VStack(alignment: .leading, spacing: 4) {
                    Text("hello.")
                        .font(.system(.title3, design: .monospaced))
                    Text("i'll live in your menu bar. take care of me by taking breaks.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("a new beginning")
                    .font(.system(.title3, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            plantFrameText(PlantArt.uniform(PlantStage.seedling.frame, color: .primary))

            Text("what's my name?")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Petal", text: $nameInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text(liveOrdinal)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 30, alignment: .leading)
            }

            Button {
                engine.plantNew(name: nameInput)
                isReplanting = false
                nameInput = ""
            } label: {
                Text("plant")
                    .frame(maxWidth: .infinity)
            }

            quitButton
        }
    }

    // MARK: — Building blocks

    private func sectionDivider(_ label: String) -> some View {
        Text("── \(label) ──")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var asciiHRule: some View {
        Text("──────────")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func statRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("> quit")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q", modifiers: .command)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: — Helpers

    private var liveOrdinal: String {
        let typed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return "" }
        let next = engine.lineage.nextOrdinal(for: typed)
        return romanNumeral(next)
    }

    private func displayName(_ plant: Plant) -> String {
        let ordinal = romanNumeral(plant.ordinal)
        return ordinal.isEmpty ? plant.name : "\(plant.name) \(ordinal)"
    }

    // Recovery frames render uniform during the brief animation; otherwise use PlantArt
    // for masked per-part colors interpolated by current vibrancy.
    private func plantFrame(_ plant: Plant) -> AttributedString {
        if let recovery = engine.recoveryFrame {
            var attr = AttributedString(recovery)
            attr.foregroundColor = .primary
            return attr
        }
        return PlantArt.render(frame: plant.stage.frame, stage: plant.stage, vibrancy: engine.vibrancy)
    }

    @ViewBuilder
    private func plantFrameText(_ content: AttributedString) -> some View {
        Text(content)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func feedControl(_ plant: Plant) -> some View {
        if engine.canFeed {
            VStack(spacing: 6) {
                Button {
                    _ = engine.feed()
                } label: {
                    Text("\(engine.qualifiedTierConfig?.label ?? "water") \(plant.name.lowercased())")
                        .frame(maxWidth: .infinity)
                }
                if engine.isIdle, let next = engine.nextTierProgress {
                    VStack(spacing: 4) {
                        ProgressView(value: min(next.span, next.into), total: next.span)
                        Text("\(Int(ceil(next.remaining)))s to \(next.label)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            let p = engine.firstTierProgress
            VStack(spacing: 6) {
                ProgressView(value: p.into, total: p.total)
                Text("step away from your mac for ~\(Int(ceil(p.remaining)))s and i'll drink.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func unwateredString(_ plant: Plant) -> String {
        switch plant.stage {
        case .dead:
            return ""
        case .flowering:
            let remaining = engine.timings.floweringToWilting - plant.unwateredActive
            if remaining > 0 { return "\(formatDuration(remaining)) until wilting" }
            return ""
        case .wilting:
            let total = engine.timings.floweringToWilting + engine.timings.wiltingToDead
            let remaining = total - plant.unwateredActive
            if remaining > 0 { return "\(formatDuration(remaining)) until lost" }
            return ""
        case .seedling, .youngling, .growing:
            let threshold = stageThreshold(plant.stage)
            let remaining = threshold - plant.activeAtStage
            if remaining > 0 { return "\(formatDuration(remaining)) until next stage" }
            return "ready to grow"
        }
    }

    private func stageThreshold(_ stage: PlantStage) -> TimeInterval {
        switch stage {
        case .seedling:  return engine.timings.seedlingToYoungling
        case .youngling: return engine.timings.younglingToGrowing
        case .growing:   return engine.timings.growingToFlowering
        default:         return 0
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(sec)s" }
        return "\(sec)s"
    }

    private func romanNumeral(_ n: Int) -> String {
        guard n > 1 else { return "" }
        let romans = ["", "", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return n < romans.count ? romans[n] : "\(n)"
    }
}
