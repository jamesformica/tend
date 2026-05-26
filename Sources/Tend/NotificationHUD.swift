import AppKit
import SwiftUI

// Pandan-style transient HUD. A small floating chip slides in below the menu bar with the
// plant's voice copy and dismisses itself after a few seconds. Replaces system notifications
// so the app never produces an Apple-style banner — keeps things calm.
@MainActor
final class NotificationHUD {
    static let shared = NotificationHUD()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private weak var statusItem: NSStatusItem?

    private let panelWidth: CGFloat = 280
    private let panelHeight: CGFloat = 60

    func setStatusItem(_ item: NSStatusItem) {
        statusItem = item
    }

    func show(message: String, severity: HUDSeverity = .neutral, duration: TimeInterval = 60.0) {
        dismissTask?.cancel()

        let panel = panel ?? makePanel()
        self.panel = panel

        let view = NotificationHUDView(message: message, severity: severity)
        panel.contentViewController = NSHostingController(rootView: view)
        positionPanel(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await self?.dismiss()
        }
    }

    func dismissNow() {
        dismissTask?.cancel()
        dismissTask = nil
        Task { [weak self] in await self?.dismiss() }
    }

    private func dismiss() async {
        guard let panel = panel else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
                continuation.resume()
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        // Anchor directly under the Tend status-item icon. We own the NSStatusItem now,
        // so its button window's frame is the icon's real position — no heuristics needed.
        if let button = statusItem?.button,
           let buttonWindow = button.window,
           let screen = buttonWindow.screen ?? NSScreen.main {
            let iconFrame = buttonWindow.frame
            let gap: CGFloat = 6
            let edgeInset: CGFloat = 12
            let unclampedX = iconFrame.midX - panelWidth / 2
            let x = max(screen.frame.minX + edgeInset,
                        min(screen.frame.maxX - panelWidth - edgeInset, unclampedX))
            let y = iconFrame.minY - panelHeight - gap
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            return
        }

        // Fallback (shouldn't happen now that we own the status item): hug the right edge.
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen = screen else { return }
        let menuBarHeight = NSStatusBar.system.thickness
        let topInset: CGFloat = 6
        let edgeInset: CGFloat = 12
        let x = screen.frame.maxX - panelWidth - edgeInset
        let y = screen.frame.maxY - menuBarHeight - panelHeight - topInset
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}

enum HUDSeverity {
    case neutral
    case warning
    case lost

    var leafTint: Color {
        switch self {
        case .neutral: return .green
        case .warning: return .red
        case .lost:    return .secondary
        }
    }

    var symbol: String { "leaf.fill" }
}

private struct NotificationHUDView: View {
    let message: String
    let severity: HUDSeverity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: severity.symbol)
                .foregroundStyle(severity.leafTint)
                .font(.system(size: 16))
            Text(message)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
