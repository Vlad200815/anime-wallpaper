import AppKit
import QuartzCore
import RiveRuntime

// Anime Girl by 3dfactor (remix of "Anime Girl" by xandercorp), CC BY.
// https://rive.app/marketplace/6421-12447-anime-girl/

private let riveName = "anime-girl"

/// Where the .riv lives: inside the .app when bundled, else SwiftPM's resource bundle (`swift run`).
private func riveBundle() -> Bundle {
    if Bundle.main.url(forResource: riveName, withExtension: "riv") != nil { return .main }
    return .module
}

/// How big the girl is drawn, as a multiple of the screen height.
enum Zoom: Double, CaseIterable {
    case whole = 1.0
    case medium = 1.6
    case close = 2.2
    case fill = 0 // cover the whole screen, crop top and bottom

    var title: String {
        switch self {
        case .whole: return "Whole figure"
        case .medium: return "Medium"
        case .close: return "Close"
        case .fill: return "Fill the screen"
        }
    }
}

/// One full-screen wallpaper window on one display.
final class WallpaperWindow: NSWindow {
    let screenRef: NSScreen
    var onExitViewing: (() -> Void)?
    private let backModel: RiveViewModel   // blurred "cover" copy filling the sides
    private let frontModel: RiveViewModel  // the girl
    private let backView: RiveView
    private let frontView: RiveView
    private let dim = NSView()
    private let edgeMask = CAGradientLayer()
    private var zoom: Zoom = .medium
    private var aspect: CGFloat = 368.0 / 654.0 // artboard width / height, replaced once loaded

    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
    /// Desktop widgets are drawn 2 levels above the icons; this sits just over both,
    /// and still far below every app window (level 0).
    private static let overIconsLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 3)

    /// true: the wallpaper covers desktop icons and widgets (app windows stay on top).
    private(set) var hideIcons = false
    private var baseLevel: NSWindow.Level { hideIcons ? Self.overIconsLevel : Self.desktopLevel }

    init(screen: NSScreen, zoom: Zoom, allDesktops: Bool, hideIcons: Bool) {
        screenRef = screen
        let bundle = riveBundle()
        backModel = RiveViewModel(fileName: riveName, in: bundle, fit: .cover, alignment: .center)
        frontModel = RiveViewModel(fileName: riveName, in: bundle, fit: .contain, alignment: .center)
        backView = backModel.createRiveView()
        frontView = frontModel.createRiveView()

        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

        // Sit on the desktop: above the system wallpaper, below the desktop icons and every app.
        level = Self.desktopLevel
        setAllDesktops(allDesktops)
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false

        if let b = frontModel.riveModel?.artboard?.bounds(), b.height > 0 { aspect = b.width / b.height }

        let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        root.wantsLayer = true
        root.layerUsesCoreImageFilters = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        contentView = root

        // Background: the same scene, scaled to cover, blurred and dimmed.
        backView.frame = root.bounds.insetBy(dx: -80, dy: -80) // overscan so the blur has no dark rim
        backView.wantsLayer = true
        if let blur = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 45]) {
            backView.layer?.filters = [blur]
        }
        root.addSubview(backView)

        dim.frame = root.bounds
        dim.wantsLayer = true
        dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        root.addSubview(dim)

        frontView.wantsLayer = true
        root.addSubview(frontView)

        setFrame(screen.frame, display: true)
        setZoom(zoom)
        setHideIcons(hideIcons)
    }

    func setHideIcons(_ on: Bool) {
        hideIcons = on
        guard !viewing else { return }
        level = baseLevel
        // Over hidden icons, catch clicks ourselves so nobody drags an invisible file.
        ignoresMouseEvents = !on
    }

    override var canBecomeKey: Bool { true }

    func setAllDesktops(_ on: Bool) {
        // Without .canJoinAllSpaces the window belongs to the desktop (Space) it was shown on.
        collectionBehavior = on
            ? [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            : [.stationary, .ignoresCycle, .fullScreenNone]
    }

    func setZoom(_ z: Zoom) {
        zoom = z
        let bounds = contentView?.bounds ?? .zero
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if z == .fill {
            frontModel.fit = .cover
            frontView.frame = bounds
            frontView.layer?.mask = nil
        } else {
            frontModel.fit = .contain
            let h = bounds.height * z.rawValue
            frontView.frame = NSRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
            // Fade the girl's left and right edges into the blurred background.
            let girlW = min(h * aspect, bounds.width)
            let left = (bounds.width - girlW) / 2 / bounds.width
            let fade = 0.08 * girlW / bounds.width
            edgeMask.frame = frontView.bounds
            edgeMask.startPoint = CGPoint(x: 0, y: 0.5)
            edgeMask.endPoint = CGPoint(x: 1, y: 0.5)
            edgeMask.colors = [NSColor.clear.cgColor, NSColor.black.cgColor,
                               NSColor.black.cgColor, NSColor.clear.cgColor]
            edgeMask.locations = [left, left + fade, 1 - left - fade, 1 - left].map { NSNumber(value: Double($0)) }
            frontView.layer?.mask = edgeMask
        }
        CATransaction.commit()
        let showBack = z != .fill
        backView.isHidden = !showBack
        dim.isHidden = !showBack
        if showBack { backModel.play() } else { backModel.pause() }
    }

    /// Feeds a cursor position, normalised to this screen (0...1, top-left origin),
    /// into the state machines. The whole screen maps onto the whole artboard,
    /// so she follows the cursor wherever it is, not only when it is over her.
    func pointer(normalized p: CGPoint) {
        for model in activeModels {
            guard let artboard = model.riveModel?.artboard,
                  let machine = model.riveModel?.stateMachine else { continue }
            let b = artboard.bounds()
            let loc = CGPoint(x: b.minX + p.x * b.width, y: b.minY + p.y * b.height)
            _ = machine.touchMoved(atLocation: loc)
            if !model.isPlaying { model.play() }
        }
    }

    private var activeModels: [RiveViewModel] { zoom == .fill ? [frontModel] : [frontModel, backModel] }

    func setPaused(_ paused: Bool) {
        for model in activeModels {
            if paused { model.pause() } else { model.play() }
        }
    }

    // MARK: Viewing mode: the wallpaper in front of icons, widgets and windows.

    private(set) var viewing = false

    func setViewing(_ on: Bool) {
        viewing = on
        level = on ? .floating : baseLevel
        ignoresMouseEvents = !(on || hideIcons)
        if on {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        } else {
            orderFrontRegardless()
        }
        setPaused(false)
    }

    override func keyDown(with event: NSEvent) {
        if viewing && event.keyCode == 53 { onExitViewing?() } else { super.keyDown(with: event) } // Esc
    }

    override func mouseDown(with event: NSEvent) {
        if viewing { onExitViewing?() } // otherwise: a click on the bare wallpaper does nothing
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [WallpaperWindow] = []
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var lastMouse = CGPoint(x: -1, y: -1)
    private var zoomItems: [Zoom: NSMenuItem] = [:]
    private var desktopItem: NSMenuItem?
    private var iconsItem: NSMenuItem?
    private var hideIcons: Bool {
        get { UserDefaults.standard.object(forKey: "hideIcons") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hideIcons") }
    }

    private var zoom: Zoom {
        get { Zoom(rawValue: UserDefaults.standard.object(forKey: "zoom") as? Double ?? Zoom.medium.rawValue) ?? .medium }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "zoom") }
    }
    private var allDesktops: Bool {
        get { UserDefaults.standard.object(forKey: "allDesktops") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "allDesktops") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindows()
        buildMenu()

        // Poll the cursor: a desktop-level window gets no mouse events of its own,
        // and polling needs no Accessibility or Input Monitoring permission.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(sleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    private func buildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let w = WallpaperWindow(screen: screen, zoom: zoom, allDesktops: allDesktops, hideIcons: hideIcons)
            w.onExitViewing = { [weak self] in self?.setViewing(false) }
            w.orderFrontRegardless()
            NotificationCenter.default.addObserver(
                self, selector: #selector(occlusionChanged(_:)),
                name: NSWindow.didChangeOcclusionStateNotification, object: w)
            return w
        }
    }

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Anime Wallpaper")
        let menu = NSMenu()

        let view = NSMenuItem(title: "View Wallpaper (Esc or click to exit)", action: #selector(startViewing), keyEquivalent: "")
        view.target = self
        menu.addItem(view)
        menu.addItem(.separator())

        let sizeHeader = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeHeader.isEnabled = false
        menu.addItem(sizeHeader)
        for z in Zoom.allCases {
            let zi = NSMenuItem(title: z.title, action: #selector(pickZoom(_:)), keyEquivalent: "")
            zi.target = self
            zi.representedObject = z.rawValue
            zi.state = z == zoom ? .on : .off
            zi.indentationLevel = 1
            menu.addItem(zi)
            zoomItems[z] = zi
        }
        menu.addItem(.separator())

        let desk = NSMenuItem(title: "Show on All Desktops", action: #selector(toggleAllDesktops), keyEquivalent: "")
        desk.target = self
        desk.state = allDesktops ? .on : .off
        menu.addItem(desk)
        desktopItem = desk

        let icons = NSMenuItem(title: "Hide Icons & Widgets", action: #selector(toggleHideIcons), keyEquivalent: "")
        icons.target = self
        icons.state = hideIcons ? .on : .off
        menu.addItem(icons)
        iconsItem = icons
        menu.addItem(.separator())

        let credit = NSMenuItem(title: "Anime Girl by 3dfactor (CC BY)", action: #selector(openCredit), keyEquivalent: "")
        credit.target = self
        menu.addItem(credit)
        menu.addItem(NSMenuItem(title: "Quit Anime Wallpaper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func tick() {
        let m = NSEvent.mouseLocation
        guard m != lastMouse else { return }
        lastMouse = m
        for w in windows {
            let f = w.screenRef.frame
            // Cursor on another display still steers every girl, clamped to the edge.
            let nx = min(max((m.x - f.minX) / f.width, 0), 1)
            let ny = min(max(1 - (m.y - f.minY) / f.height, 0), 1)
            w.pointer(normalized: CGPoint(x: nx, y: ny))
        }
    }

    @objc private func startViewing() { setViewing(true) }

    private func setViewing(_ on: Bool) {
        windows.forEach { $0.setViewing(on) }
        if !on { NSApp.hide(nil) } // hand focus back to whatever was in front
    }

    @objc private func pickZoom(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Double, let z = Zoom(rawValue: raw) else { return }
        zoom = z
        zoomItems.forEach { $0.value.state = $0.key == z ? .on : .off }
        windows.forEach { $0.setZoom(z) }
        lastMouse = CGPoint(x: -1, y: -1) // re-send the cursor
    }

    @objc private func toggleHideIcons() {
        hideIcons.toggle()
        iconsItem?.state = hideIcons ? .on : .off
        windows.forEach { $0.setHideIcons(hideIcons) }
    }

    /// Off: the wallpaper stays only on the desktop that is active right now.
    @objc private func toggleAllDesktops() {
        allDesktops.toggle()
        desktopItem?.state = allDesktops ? .on : .off
        for w in windows {
            w.orderOut(nil)
            w.setAllDesktops(allDesktops)
            w.orderFrontRegardless() // lands on the current desktop
        }
    }

    @objc private func occlusionChanged(_ note: Notification) {
        guard let w = note.object as? WallpaperWindow else { return }
        // Fully covered or on another desktop: stop rendering to save battery.
        w.setPaused(!w.occlusionState.contains(.visible))
    }

    @objc private func screensChanged() { buildWindows() }
    @objc private func sleep() { windows.forEach { $0.setPaused(true) } }
    @objc private func wake() { windows.forEach { $0.setPaused(!$0.occlusionState.contains(.visible)) } }

    @objc private func openCredit() {
        NSWorkspace.shared.open(URL(string: "https://rive.app/marketplace/6421-12447-anime-girl/")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon; lives in the menu bar
app.run()
