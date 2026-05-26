import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = PlantEngine.loadOrCreate()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var labelCancellable: AnyCancellable?
    private var lastLabelKey: MenubarLabelKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        engine.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

        let host = NSHostingController(rootView: PopoverView(engine: engine))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host

        NotificationHUD.shared.setStatusItem(statusItem)

        renderStatusLabel()
        labelCancellable = engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.renderStatusLabel() }
    }

    // Rebuild the menu-bar button's image from MenubarLabelView. NSStatusItem's variable
    // length auto-sizes to fit button.image, so this is also how the button grows/shrinks
    // as the counter text changes width. Subscribed to engine.objectWillChange but skipped
    // when the visible state hasn't changed — ImageRenderer is the most expensive thing
    // we do per tick, and most ticks above the 60s display floor are no-op renders.
    private func renderStatusLabel() {
        guard let button = statusItem.button else { return }
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let key = MenubarLabelKey(engine: engine, isDark: isDark)
        if key == lastLabelKey { return }
        lastLabelKey = key

        let content = MenubarLabelView(engine: engine)
            .environment(\.colorScheme, isDark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        if let image = renderer.nsImage {
            image.isTemplate = false
            button.image = image
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// Cache key for the menu-bar image. Every input that affects a pixel goes here; nothing
// else. Vibrancy is bucketed because the leaf tint isn't perceptibly different per 0.001
// step but we wouldn't otherwise cache between the once-per-second decay updates.
struct MenubarLabelKey: Equatable {
    let stage: PlantStage?
    let counterText: String?
    let counterIsRed: Bool
    let counterIsOrange: Bool
    let canFeed: Bool
    let vibrancyBucket: Int
    let isDark: Bool

    @MainActor
    init(engine: PlantEngine, isDark: Bool) {
        let plant = engine.plant
        self.stage = plant?.stage
        if let p = plant, p.stage != .dead {
            self.counterText = MenubarLabel.counterText(for: p, timings: engine.timings)
            let color = MenubarLabel.counterColor(for: p, timings: engine.timings)
            self.counterIsRed = color == .red
            self.counterIsOrange = color == .orange
        } else {
            self.counterText = nil
            self.counterIsRed = false
            self.counterIsOrange = false
        }
        self.canFeed = engine.canFeed
        self.vibrancyBucket = Int((engine.vibrancy * 50).rounded())
        self.isDark = isDark
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        // Apply the denser/active chrome BEFORE the open animation runs — otherwise the
        // first ~half second shows the default lighter material until popoverDidShow fires.
        applyPopoverChrome()
    }

    func popoverDidShow(_ notification: Notification) {
        engine.popoverOpened()
        // Re-apply after the popover is fully visible, in case the system re-set anything
        // during the open animation. Also makes the window key so input works correctly.
        if let window = popover.contentViewController?.view.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
        }
        applyPopoverChrome()
    }

    private func applyPopoverChrome() {
        guard let window = popover.contentViewController?.view.window else { return }
        for vev in findVisualEffectViews(in: window.contentView) {
            vev.material = .menu
            vev.state = .active
        }
    }

    func popoverDidClose(_ notification: Notification) {
        engine.popoverClosed()
    }

    private func findVisualEffectViews(in view: NSView?) -> [NSVisualEffectView] {
        guard let view = view else { return [] }
        var result: [NSVisualEffectView] = []
        if let vev = view as? NSVisualEffectView { result.append(vev) }
        for sub in view.subviews { result.append(contentsOf: findVisualEffectViews(in: sub)) }
        return result
    }
}
