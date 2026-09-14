// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit
import ScreenCaptureKit
import LidPlaneCore
import OSLog
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class MenuBarApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let dashboard = DashboardModel()
    private var settingsWindow: NSWindow?
    private var lastDashboardUpdate: TimeInterval = 0
    private var locked = false
    private var sensor = LidSensor()
    private let environment = DisplayEnvironment()
    private var safety = DisplaySafetyGate()
    private var motion = LidMotionFilter()
    private var spring = FoldSpring()
    private var handoffMotion = HandoffSmoothing()
    private var capturePolicy = CapturePolicy()
    private var captureTask: Task<Void, Never>?
    private var timerInterval: TimeInterval = 0
    private var motionResponse = 0.045
    private var handoffWidth = 15.0
    private var captureLead = 12.0
    private var targetStyle = 0
    private var pauseDeadline: Date?
    private var resumeAlignment = ResumeAlignment()
    private var firstFrameTime: TimeInterval = 0
    private var boundaryWeight = 1.0
    private var stoppingCapture = false
    private var lastSensorReconnect: TimeInterval = 0
    private var demoAngle = 75.0
    private let preferences = UserDefaults.standard
    private var window: OverlayPanel!
    private var view: MTKView!
    private var renderer: PlaneRenderer!
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let logger = Logger(subsystem: "app.fold.mac", category: "Overlay")
    private var wantsOverlay = false
    private var lastAnglePoll: TimeInterval = 0
    private var lastButtonLabel = ""
    private var shortcut: GlobalShortcut?
    private var timer: Timer?
    private var capture: DesktopCapture?
    private var enabled = false
    private var starting = false
    private var suspended = false
    private var hasFrame = false
    private var current = 110.0
    private var lastReading: TimeInterval = 0
    private var previousTick: TimeInterval = 0
    private var anchor = AutoAnchor(angle: 110, now: 0)
    private var simulated = false
    private var status = "Off"
    private var capturedDisplay: CGDirectDisplayID?
    private var autoAnchor: Bool {
        get { preferences.bool(forKey: "autoAnchor") }
        set { preferences.set(newValue, forKey: "autoAnchor") }
    }
    private var angleMode: Bool { preferences.bool(forKey: "angleMode") }
    private var activationAngle: Double { min(180, max(10, preferences.double(forKey: "activationAngle"))) }
    private var jitterTolerance: Double { min(5, max(0, preferences.double(forKey: "jitterTolerance"))) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences.register(defaults: ["autoAnchor": true, "anchorDelay": AutoAnchor.defaultDelay, "blur": true, "tilt": true, "perspective": true, "showHUD": true, "angleMode": true, "activationAngle": EffectDefaults.activationAngle, "jitterTolerance": EffectDefaults.jitterTolerance, "blurStrength": 1.0, "response": 0.045, "quality": 60, "captureLead": 12.0, "handoffWidth": 15.0, "respectLowPower": true, "foldStyle": 0, "foldDepth": 1.0])
        guard let gpu = MTLCreateSystemDefaultDevice() else { showError("Metal is unavailable on this Mac."); NSApp.terminate(nil); return }
        do { renderer = try PlaneRenderer(gpu: gpu) }
        catch { showError(error.localizedDescription); NSApp.terminate(nil); return }
        renderer.blur = preferences.bool(forKey: "blur")
        renderer.warp = preferences.bool(forKey: "tilt")
        renderer.perspective = preferences.bool(forKey: "perspective")
        window = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.title = "Foldable Overlay"
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.hasShadow = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        view = MTKView(frame: .zero, device: gpu)
        view.colorPixelFormat = .bgra8Unorm
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.delegate = renderer
        view.preferredFramesPerSecond = min(preferences.integer(forKey: "quality"), DisplayEnvironment.usableBuiltInScreen()?.maximumFramesPerSecond ?? 60)
        renderer.tick = { [weak self] in self?.advanceMotion() }
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        renderer.onRenderComplete = { [weak self] success in
            guard let self, self.wantsOverlay else { return }
            if success {
                if self.window.alphaValue < 1 { self.logger.notice("First frame complete; making overlay visible") }
                self.window.alphaValue = 1
            }
            else { self.window.orderOut(nil); self.logger.error("Overlay render failed; hiding panel") }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Foldable")
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Foldable: click for settings, right-click for options")
        }
        menu.delegate = self
        menu.autoenablesItems = false
        refreshStatus()
        if CommandLine.arguments.contains("--dashboard-check") { runDashboardCheck(); return }
        if CommandLine.arguments.contains("--window-check") { runWindowCheck(); return }
        do { shortcut = try GlobalShortcut(configuration: savedShortcut) { [weak self] in self?.toggleEnabled() } }
        catch { logger.error("\(error.localizedDescription, privacy: .public)") }
        configureTimer()
        installApplicationMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(powerChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        dashboard.shortcutAvailable = shortcut?.isRegistered == true
        dashboard.shortcutConfiguration = savedShortcut
        dashboard.setShortcut = { [weak self] in self?.setShortcut($0) }
        dashboard.recordShortcut = { [weak self] in self?.recordShortcut($0) }
        dashboard.pause = { [weak self] in self?.togglePause() }
        dashboard.toggle = { [weak self] in self?.toggleEnabled() }
        dashboard.authorize = { [weak self] in self?.requestScreenAccess() }
        dashboard.apply = { [weak self] in self?.applyPreferences() }
        dashboard.calibrate = { [weak self] in
            guard let self, let angle = self.dashboard.angle else { return }
            self.preferences.set(min(180, max(10, angle)), forKey: "activationAngle")
            self.preferences.set(true, forKey: "angleMode")
            self.resetMotion()
        }
        dashboard.reset = { [weak self] in
            guard let self else { return }
            for (key, value) in ["activationAngle": 110.0, "jitterTolerance": 0.0, "blurStrength": 1.0, "response": 0.045, "captureLead": 12.0, "handoffWidth": 15.0] { self.preferences.set(value, forKey: key) }
            for key in ["blur", "tilt", "perspective", "showHUD", "angleMode"] { self.preferences.set(true, forKey: key) }
            self.preferences.set(60, forKey: "quality")
            self.preferences.set(true, forKey: "respectLowPower")
            self.preferences.set(0, forKey: "foldStyle")
            self.preferences.set(1.0, forKey: "foldDepth")
            self.applyPreferences(); self.resetMotion()
        }
        applyPreferences()
        if CommandLine.arguments.contains("--settings") { showSettings() }
        NSLog("Foldable menu bar ready; %@", sensor.diagnostic)
    }

    /// Snapshots contain only this app's generated artwork and synthetic status.
    /// Never enable DesktopCapture or request permissions in this diagnostic.
    private func runDashboardCheck() {
        showSettings()
        dashboard.angle = 110
        dashboard.permission = false
        let output = Bundle.main.bundleURL.deletingLastPathComponent()
        var step = 0
        var reports: [String] = []
        let pages = DashboardPage.allCases
        func configure(_ index: Int) {
            let dark = (index / pages.count).isMultiple(of: 2) == false
            self.settingsWindow?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            self.dashboard.page = pages[index % pages.count]
            self.dashboard.enabled = dark
            self.dashboard.status = dark ? "Ready · prewarmed" : "Off"
            self.dashboard.permission = dark
            self.dashboard.previewAngle = index == pages.count ? max(10, self.activationAngle - 35) : index == pages.count * 2 ? self.activationAngle - 6 : self.activationAngle
            self.settingsWindow?.setContentSize(NSSize(width: index >= pages.count * 2 ? 820 : 940, height: index >= pages.count * 2 ? 600 : 700))
        }
        configure(step)
        timer = Timer(timeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self, let panel = self.settingsWindow else { return }
            let name = "dashboard-\(step)-\(pages[step % pages.count].rawValue.replacingOccurrences(of: " ", with: "-"))"
            if let capture = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(panel.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
               let png = NSBitmapImageRep(cgImage: capture).representation(using: .png, properties: [:]) {
                do {
                    try png.write(to: output.appendingPathComponent(name + ".png"))
                    reports.append("PASS: \(name) \(capture.width)×\(capture.height)")
                } catch { reports.append("FAIL: \(name) \(error)") }
            } else { reports.append("FAIL: \(name) could not inspect app window") }
            step += 1
            if step == pages.count * 4 {
                try? reports.joined(separator: "\n").write(to: output.appendingPathComponent("dashboard-check.txt"), atomically: true, encoding: .utf8)
                NSApp.terminate(nil)
            } else { configure(step) }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func runWindowCheck() {
        var shortcutChecksPassed = false
        do { try ShortcutChecks.run(); shortcutChecksPassed = true }
        catch { logger.error("Shortcut checks failed: \(error.localizedDescription, privacy: .public)") }
        renderer.tick = nil
        let screen = NSScreen.main!
        fitOverlay(to: screen)
        renderer.blur = true; renderer.warp = true; renderer.perspective = true
        // Reproduce the real CVPixelBuffer → Metal path, not just a static texture.
        let artwork = PlaneRenderer.artwork()
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let result = CVPixelBufferCreate(nil, artwork.width, artwork.height, kCVPixelFormatType_32BGRA, attributes, &pixelBuffer)
        guard result == kCVReturnSuccess, let pixelBuffer else { fatalError("Test pixel buffer unavailable") }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: artwork.width, height: artwork.height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
        context.draw(artwork, in: CGRect(x: 0, y: 0, width: artwork.width, height: artwork.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        let accepted = renderer.setDesktopFrame(pixelBuffer)
        var shortcutCalls = 0
        do { shortcut = try GlobalShortcut { shortcutCalls += 1 } }
        catch { logger.error("\(error.localizedDescription, privacy: .public)") }
        let shortcutEventResult = GlobalShortcut.dispatchTestEvent()
        var sliderValue = 0.0
        let sliderCheck = MenuSlider(title: "Jitter tolerance", value: 2, range: 0...5, step: 0.5) { sliderValue = $0 }
        sliderCheck.slider.doubleValue = 1.1
        sliderCheck.slider.sendAction(sliderCheck.slider.action, to: sliderCheck.slider.target)
        let sliderPassed = sliderValue == 1 && sliderCheck.slider.doubleValue == 1
        renderer.delta = 0.6
        wantsOverlay = true
        window.alphaValue = 0
        window.orderFrontRegardless()
        var ticks = 0
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if ticks == 10 { self.wantsOverlay = false; self.window.orderOut(nil) }
            if ticks == 15 { self.wantsOverlay = true; self.window.alphaValue = 0; self.window.orderFrontRegardless() }
            self.renderer.delta = 0.6 + Float(sin(Double(ticks))) * 0.005
            self.view.draw()
            ticks += 1
            if ticks == 30 {
                let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(self.window.windowNumber)) as? [[String: Any]] ?? []
                let onScreen = windows.first?[kCGWindowIsOnscreen as String] as? Bool == true
                var visiblePixels = false
                // Inspect only our generated artwork window, never another app's pixels.
                // GPU completion alone passed even with a broken, blank presentation layer.
                if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(self.window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                    let bitmap = NSBitmapImageRep(cgImage: image)
                    if let center = bitmap.colorAt(x: image.width / 2, y: image.height / 2)?.usingColorSpace(.deviceRGB) {
                        visiblePixels = center.alphaComponent > 0.99 && center.greenComponent > 0.05 && center.blueComponent > 0.05
                    }
                    if let png = bitmap.representation(using: .png, properties: [:]) {
                        try? png.write(to: Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("window-check.png"))
                    }
                }
                let passed = shortcutChecksPassed && accepted && visiblePixels && onScreen && sliderPassed && self.renderer.completedDraws > 20 && self.window.alphaValue == 1 && self.window.ignoresMouseEvents && !self.window.canBecomeKey && self.view.layer?.contentsScale == screen.backingScaleFactor && shortcutCalls == 1 && shortcutEventResult == 0
                let report = "\(passed ? "PASS" : "FAIL"): shortcutChecks=\(shortcutChecksPassed) pixelBuffer=\(accepted) visiblePixels=\(visiblePixels) onScreen=\(onScreen) slider=\(sliderPassed) scale=\(self.view.layer?.contentsScale ?? 0) drawable=\(self.view.drawableSize) permission=\(CGPreflightScreenCaptureAccess()) opacity=\(self.renderer.opacity) geometry=\(self.renderer.geometryWeight) windowAlpha=\(self.window.alphaValue) attempts=\(self.renderer.attemptedDraws) missing=\(self.renderer.missingDrawables) completed=\(self.renderer.completedDraws) shortcutCalls=\(shortcutCalls) clickThrough=\(self.window.ignoresMouseEvents) canBecomeKey=\(self.window.canBecomeKey)\n"
                try? report.write(to: Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("window-check.txt"), atomically: true, encoding: .utf8)
                NSApp.terminate(nil)
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func statusClicked() {
        let event = NSApp.currentEvent
        if event?.modifierFlags.contains(.option) == true { toggleEnabled(); return }
        if event?.clickCount == 2 { showSettings(); return }
        guard let button = statusItem.button else { return }
        rebuildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }
    func menuWillOpen(_ menu: NSMenu) { rebuildMenu() }
    private func rebuildMenu() {
        menu.removeAllItems()
        @discardableResult func item(_ title: String, _ action: Selector?, checked: Bool? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            if let checked { item.state = checked ? .on : .off }
            menu.addItem(item)
            return item
        }
        item("Foldable · \(status)", nil).isEnabled = false
        let toggle = item(enabled ? "Disable Effect" : "Enable Effect", #selector(toggleEnabled))
        if shortcut?.isRegistered == true {
            let chord = shortcut!.configuration
            toggle.keyEquivalent = (ShortcutConfiguration.keys[chord.keyCode] == "Space" ? " " : ShortcutConfiguration.keys[chord.keyCode]?.lowercased()) ?? ""
            toggle.keyEquivalentModifierMask = chord.eventModifiers
        } else { item("Toggle shortcut unavailable", nil).isEnabled = false }
        if enabled { item(pauseDeadline == nil ? "Pause for 10 Minutes" : "Resume Now", #selector(togglePause)) }
        item("Open Foldable Settings…", #selector(showSettings))
        menu.addItem(.separator())
        for style in FoldStyle.allCases {
            let choice = item(style.title, #selector(setStyle(_:)), checked: preferences.integer(forKey: "foldStyle") == style.rawValue)
            choice.representedObject = style.rawValue
        }
        let feels = item("Motion Feel", nil)
        let feelsMenu = NSMenu()
        for title in ["Direct", "Balanced", "Silky"] {
            let choice = NSMenuItem(title: title, action: #selector(setFeel(_:)), keyEquivalent: "")
            choice.target = self; choice.representedObject = title; feelsMenu.addItem(choice)
        }
        feels.submenu = feelsMenu
        func slider(_ title: String, key: String, range: ClosedRange<Double>, step: Double,
                    suffix: String = "°", scale: Double = 1, active: Bool = true, in destination: NSMenu) {
            let row = NSMenuItem()
            row.view = MenuSlider(title: title, value: preferences.double(forKey: key), range: range,
                step: step, enabled: active, suffix: suffix, valueScale: scale) { [weak self] value in
                self?.preferences.set(value, forKey: key); self?.applyPreferences()
            }
            destination.addItem(row)
        }
        slider("Start angle", key: "activationAngle", range: 10...180, step: 1, active: angleMode, in: menu)
        slider("Smoothing", key: "response", range: 0.02...0.12, step: 0.005, suffix: " ms", scale: 1000, in: menu)
        slider("Desktop handoff", key: "handoffWidth", range: 8...22, step: 1, active: angleMode, in: menu)
        let more = item("More Adjustments", nil)
        let adjustments = NSMenu(); adjustments.autoenablesItems = false; more.submenu = adjustments
        slider("Softness", key: "blurStrength", range: 0.3...1.6, step: 0.05, suffix: "%", scale: 100, in: adjustments)
        slider("Capture prewarm", key: "captureLead", range: 10...15, step: 1, active: angleMode, in: adjustments)
        slider("Steadiness", key: "jitterTolerance", range: 0...5, step: 0.5, in: adjustments)
        slider("Origami depth", key: "foldDepth", range: 0.5...1.4, step: 0.05, suffix: "%", scale: 100,
            active: targetStyle == 1, in: adjustments)
        let quality = item("Refresh Rate", nil)
        let rates = NSMenu(); quality.submenu = rates
        for rate in [60, 120] {
            let choice = NSMenuItem(title: rate == 60 ? "60 Hz" : "Up to 120 Hz", action: #selector(setQuality(_:)), keyEquivalent: "")
            choice.target = self; choice.representedObject = rate
            choice.state = preferences.integer(forKey: "quality") == rate ? .on : .off; rates.addItem(choice)
        }
        item("Use Activation Angle", #selector(toggleAngleMode), checked: angleMode)
        menu.addItem(.separator())
        item("Anchor Here", #selector(anchorHere)).isEnabled = enabled && !angleMode
        item("Auto-anchor When Still", #selector(toggleAutoAnchor), checked: autoAnchor && !angleMode).isEnabled = !angleMode
        let delay = item("Pause Before Anchoring", nil)
        let submenu = NSMenu()
        for value in [AutoAnchor.defaultDelay, 0.3, 0.5, 1.0, 2.0] {
            let choice = NSMenuItem(title: "\(value) seconds", action: #selector(setDelay(_:)), keyEquivalent: "")
            choice.target = self; choice.representedObject = value
            choice.state = preferences.double(forKey: "anchorDelay") == value ? .on : .off
            submenu.addItem(choice)
        }
        delay.submenu = submenu
        delay.isEnabled = !angleMode
        menu.addItem(.separator())
        item("Progressive Blur", #selector(toggleBlur), checked: renderer.blur)
        item("Hold Content Angle", #selector(toggleTilt), checked: renderer.warp)
        item("Perspective Taper", #selector(togglePerspective), checked: renderer.perspective)
        item("Show Lid Angle in Menu Bar", #selector(toggleHUD), checked: preferences.bool(forKey: "showHUD"))
        item("Simulate a Fold", #selector(toggleSimulation), checked: simulated).isEnabled = enabled
        menu.addItem(.separator())
        item("Customize Toggle Shortcut…", #selector(showShortcutSettings))
        item("Screen Recording Settings…", #selector(openPermissions))
        item("Quit Foldable", #selector(quit))
    }

    @objc private func toggleEnabled() {
        if !enabled && !CGPreflightScreenCaptureAccess() {
            requestScreenAccess()
            return
        }
        enabled.toggle()
        pauseDeadline = nil; dashboard.paused = false
        safety.reset()
        capturePolicy.reset()
        configureTimer()
        if enabled { anchorHere(); update() } else { resumeAlignment.cancel(); stopCapture(); status = "Off" }
        refreshStatus()
    }
    private func startCapture() {
        guard enabled, !suspended, !locked, safety.state == .ready, capture == nil, !stoppingCapture,
              let screen = DisplayEnvironment.usableBuiltInScreen(),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }
        fitOverlay(to: screen)
        capturedDisplay = displayID
        anchorHere()
        resumeAlignment.suspend()
        starting = true; status = "Preparing screen…"
        let session = DesktopCapture()
        capture = session
        session.onFrame = { [weak self, weak session] buffer in
            guard let self, let session, self.capture === session, self.enabled, !self.suspended, !self.locked else { return }
            // Require a new sensor reading alongside the first complete frame.
            // Capture discovery may finish long after the lid has moved.
            let firstFrame = !self.hasFrame
            if firstFrame {
                guard let angle = self.sensor.read() else { return }
                let now = CACurrentMediaTime()
                self.current = angle; self.lastReading = now
                let reference = self.angleMode ? self.activationAngle : self.anchor.reference
                let input = self.simulated ? self.demoAngle : angle
                guard let delta = self.resumeAlignment.takeDelta(angle: input, reference: reference, fresh: true) else { return }
                self.motion.reset(to: input)
                self.targetDelta = Float(delta)
                self.spring.reset(to: delta)
                self.handoffMotion.reset()
                self.renderer.delta = Float(delta)
                self.previousTick = now
                self.firstFrameTime = now
            }
            self.hasFrame = self.renderer.setDesktopFrame(buffer)
            if !self.hasFrame { self.resumeAlignment.suspend() }
            if firstFrame { self.update() }
        }

        session.onError = { [weak self, weak session] error in
            guard let self, let session, self.capture === session else { return }
            self.captureFailed(error)
        }
        captureTask = Task { @MainActor in
            do {
                try await session.start(displayID: displayID, framesPerSecond: view.preferredFramesPerSecond)
                guard capture === session, enabled else { await session.stop(); return }
                starting = false; update()
            } catch {
                guard capture === session else { return }
                captureFailed(error)
            }
        }
    }
    private func stopCapture() {
        captureTask?.cancel(); captureTask = nil
        let previous = capture
        previous?.cancel()
        capture = nil; starting = false; hasFrame = false; simulated = false
        firstFrameTime = 0; boundaryWeight = 1
        spring.reset(); handoffMotion.reset()
        renderer.invalidatePresentation()
        capturedDisplay = nil
        wantsOverlay = false
        view.isPaused = true
        window.orderOut(nil)
        renderer.delta = 0; targetDelta = 0; renderer.opacity = 0; renderer.useArtwork()
        if let previous {
            stoppingCapture = true
            Task { @MainActor in await previous.stop(); stoppingCapture = false }
        }
    }
    private func captureFailed(_ error: Error) {
        let now = CACurrentMediaTime()
        if suspended || environment.lidClosed(now: now) == true || DisplayEnvironment.usableBuiltInScreen() == nil || (now - lastReading <= 1 && current <= 5) {
            stopCapture(); safety.reset(); status = "Paused · display changing"; refreshStatus(); return
        }
        let error = error as NSError
        stopCapture(); enabled = false; configureTimer(); status = "Capture unavailable"; refreshStatus()
        let denied = error.domain == SCStreamErrorDomain && error.code == -3801
        let message = denied
            ? "Allow Foldable in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen the app. If it is already enabled after a rebuild, remove the old Foldable entry and allow the new build again."
            : error.localizedDescription
        showError("\(message)\n\n\(error.domain) (\(error.code))")
    }

    private func update() {
        guard !suspended, !locked else { return }
        let now = CACurrentMediaTime()
        // The optional menu bar readout also works while the visual effect is off.
        let pollInterval = enabled ? timerInterval * 0.8 : 0.18
        if (enabled || settingsWindow?.isVisible == true || preferences.bool(forKey: "showHUD")), now-lastAnglePoll >= pollInterval {
            lastAnglePoll = now
            if let angle = sensor.read() { current = angle; lastReading = now }
            else if now - lastSensorReconnect > 2 {
                lastSensorReconnect = now; sensor = LidSensor()
            }
        }
        guard enabled else { refreshStatus(); return }
        if let deadline = pauseDeadline {
            if deadline > Date() {
                let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                status = String(format: "Paused · %d:%02d remaining", remaining / 60, remaining % 60)
                refreshStatus(); return
            }
            pauseDeadline = nil; dashboard.paused = false; safety.reset(); configureTimer()
        }

        let freshSensor = now - lastReading <= 1
        let screen = DisplayEnvironment.usableBuiltInScreen()
        let closed = environment.lidClosed(now: now) == true || (freshSensor && current <= 5)
        if closed { resumeAlignment.suspend() }
        guard safety.update(lidClosed: closed, builtInAvailable: screen != nil, sensorAvailable: freshSensor || simulated, now: now) else {
            if capture != nil || wantsOverlay { stopCapture() }
            status = safety.state.rawValue; refreshStatus(); return
        }
        if let capturedDisplay, let screen,
           screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID != capturedDisplay {
            stopCapture(); safety.reset(); return
        }
        let input = simulated ? demoAngle : current
        let needsCapture = capturePolicy.update(angle: input, activation: activationAngle,
            lead: captureLead, angleMode: angleMode, now: now) && (renderer.blur || renderer.warp)
        guard needsCapture else {
            if capture != nil || wantsOverlay { stopCapture() }
            status = renderer.blur || renderer.warp ? "Armed · capture sleeping" : "Paused · visual effects off"
            refreshStatus(); return
        }
        if capture == nil { startCapture() }
        capture?.setActive(true, framesPerSecond: view.preferredFramesPerSecond)
        guard AngleActivation.allows(angle: input, limit: activationAngle, enabled: angleMode) else {
            motion.reset(to: activationAngle)
            renderer.invalidatePresentation()
            renderer.opacity = 0
            spring.reset(); handoffMotion.reset()
            renderer.delta = 0; targetDelta = 0; wantsOverlay = false; view.isPaused = true; window.orderOut(nil)
            status = starting ? "Preparing screen…" : "Ready · prewarmed at \(Int(activationAngle + captureLead))°"; refreshStatus(); return
        }
        let stableAngle = motion.update(input, tolerance: simulated ? 0 : jitterTolerance)
        anchor.delay = preferences.double(forKey: "anchorDelay")
        anchor.movementThreshold = max(0.1, jitterTolerance)
        anchor.update(angle: stableAngle, now: now, enabled: autoAnchor && !angleMode && !simulated)
        let reference = angleMode ? activationAngle : anchor.reference
        targetDelta = Float((reference-stableAngle) * .pi/180)
        if view.isPaused { advanceMotion() }
        status = starting ? "Starting…" : (simulated ? "Demo" : "On")
        // Show the real desktop when aligned, avoiding capture latency and reduced resolution.
        // An independent timer keeps sensing the lid while the overlay is hidden.
        wantsOverlay = hasFrame && !resumeAlignment.pending && abs(renderer.delta) > 0.0001 && boundaryWeight > 0 && (renderer.blur || renderer.warp)
        if wantsOverlay {
            if !window.isVisible {
                window.alphaValue = 0
                window.orderFrontRegardless()
                logger.notice("Showing overlay; drawable \(self.view.drawableSize.width) x \(self.view.drawableSize.height)")
            }
            view.isPaused = false
        } else { view.isPaused = true; window.orderOut(nil) }

        refreshStatus()
    }
    private var targetDelta: Float = 0
    private func advanceMotion() {
        let now = CACurrentMediaTime()
        let dt = min(0.05, max(0, now - previousTick)); previousTick = now
        renderer.delta = Float(spring.advance(to: Double(targetDelta), elapsed: dt, response: motionResponse))
        let distance = handoffMotion.advance(distance: activationAngle - (simulated ? demoAngle : current),
            elapsed: dt, response: motionResponse, width: handoffWidth)
        let presentation = OverlayHandoff.presentation(delta: Double(renderer.delta),
            rawDistance: distance, angleMode: angleMode,
            width: handoffWidth, elapsedSinceFrame: hasFrame ? now - firstFrameTime : 0)
        boundaryWeight = presentation.geometry
        renderer.geometryWeight = Float(presentation.geometry)
        renderer.opacity = Float(presentation.opacity)
        renderer.foldStyle = Float(MotionSmoothing.advance(Double(renderer.foldStyle), to: Double(targetStyle), elapsed: dt, response: 0.10))
        if abs(renderer.foldStyle - Float(targetStyle)) < 0.0001 { renderer.foldStyle = Float(targetStyle) }
    }
    private func refreshStatus() {
        let now = CACurrentMediaTime()
        dashboard.liveAngle = now - lastReading < 1 ? current : nil
        if now - lastDashboardUpdate > 0.15 {
            lastDashboardUpdate = now
            let angle = now-lastReading < 1 ? current : nil
            if dashboard.angle != angle { dashboard.angle = angle }
            if dashboard.enabled != enabled { dashboard.enabled = enabled }
            if dashboard.status != status { dashboard.status = status }
            let captureStatus = capture == nil ? "Sleeping" : starting || !hasFrame ? "Preparing" : wantsOverlay ? "Live" : "Prewarmed"
            if dashboard.captureStatus != captureStatus { dashboard.captureStatus = captureStatus }
            if dashboard.frameRate != view.preferredFramesPerSecond { dashboard.frameRate = view.preferredFramesPerSecond }
            if dashboard.frameCount != (capture?.frames ?? 0) { dashboard.frameCount = capture?.frames ?? 0 }
            if settingsWindow?.isVisible == true {
                let granted = CGPreflightScreenCaptureAccess()
                if dashboard.permission != granted { dashboard.permission = granted }
            }
        }
        statusItem?.button?.toolTip = "Foldable: \(status). Click for quick settings; \(dashboard.shortcutConfiguration.label) toggles the effect."
        statusItem?.button?.appearsDisabled = !enabled
        guard let button = statusItem?.button else { return }
        let showAngle = preferences.bool(forKey: "showHUD")
        let fresh = simulated || CACurrentMediaTime()-lastReading < 1
        let label = showAngle ? (fresh ? "\(Int(current.rounded()))°" : "—°") : ""
        if label != lastButtonLabel || (showAngle && button.image != nil) {
            lastButtonLabel = label
            statusItem.length = showAngle ? 44 : NSStatusItem.squareLength
            button.image = showAngle ? nil : NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Foldable")
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.title = label
        }
    }
    @objc private func anchorHere() {
        if !simulated, let angle = sensor.read() { current = angle; lastReading = CACurrentMediaTime() }
        anchor.anchor(at: current, now: CACurrentMediaTime())
        motion.reset(to: angleMode ? min(current, activationAngle) : current)
    }
    private func resetMotion() {
        renderer.invalidatePresentation()
        spring.reset(); handoffMotion.reset()
        renderer.delta = 0; targetDelta = 0; wantsOverlay = false; view.isPaused = true; window.orderOut(nil)
        anchorHere()
    }
    @objc private func toggleAngleMode() {
        preferences.set(!angleMode, forKey: "angleMode"); resetMotion()
    }
    @objc private func toggleAutoAnchor() { autoAnchor.toggle() }
    @objc private func setDelay(_ sender: NSMenuItem) { preferences.set(sender.representedObject as? Double ?? AutoAnchor.defaultDelay, forKey: "anchorDelay") }
    @objc private func toggleBlur() { renderer.blur.toggle(); preferences.set(renderer.blur, forKey: "blur"); applyPreferences() }
    @objc private func toggleTilt() { renderer.warp.toggle(); preferences.set(renderer.warp, forKey: "tilt"); applyPreferences() }
    @objc private func togglePerspective() { renderer.perspective.toggle(); preferences.set(renderer.perspective, forKey: "perspective"); applyPreferences() }
    @objc private func toggleHUD() { preferences.set(!preferences.bool(forKey: "showHUD"), forKey: "showHUD"); refreshStatus() }
    @objc private func toggleSimulation() {
        simulated.toggle()
        if simulated { demoAngle = max(10, (angleMode ? activationAngle : anchor.reference)-35) } else { resetMotion() }
    }
    @objc private func openPermissions() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!) }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            panel.title = "Foldable"
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .visible
            panel.minSize = NSSize(width: 820, height: 600)
            panel.toolbarStyle = .unified
            panel.tabbingMode = .disallowed
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: FoldDashboard(model: dashboard))
            panel.center()
            if !CommandLine.arguments.contains("--dashboard-check") { panel.setFrameAutosaveName("FoldDashboard") }
            settingsWindow = panel
        }
        dashboard.permission = CGPreflightScreenCaptureAccess()
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeFirstResponder(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshStatus()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    private func applyPreferences() {
        renderer.blur = preferences.bool(forKey: "blur")
        renderer.warp = preferences.bool(forKey: "tilt")
        renderer.perspective = preferences.bool(forKey: "perspective")
        renderer.blurStrength = Float(min(1.6, max(0.3, preferences.double(forKey: "blurStrength"))))
        targetStyle = FoldStyle(rawValue: preferences.integer(forKey: "foldStyle"))?.rawValue ?? 0
        renderer.foldDepth = Float(min(1.4, max(0.5, preferences.double(forKey: "foldDepth"))))
        if !wantsOverlay { renderer.foldStyle = Float(targetStyle) }
        motionResponse = min(0.12, max(0.02, preferences.double(forKey: "response")))
        handoffWidth = min(22, max(8, preferences.double(forKey: "handoffWidth")))
        captureLead = min(15, max(10, preferences.double(forKey: "captureLead")))
        view.preferredFramesPerSecond = FrameCadence.framesPerSecond(requested: preferences.integer(forKey: "quality"),
            displayMaximum: DisplayEnvironment.usableBuiltInScreen()?.maximumFramesPerSecond ?? 60,
            conserveEnergy: preferences.bool(forKey: "respectLowPower") && ProcessInfo.processInfo.isLowPowerModeEnabled)
        configureTimer()
        update()
        refreshStatus()
    }
    private func requestScreenAccess() {
        if CGPreflightScreenCaptureAccess() { openPermissions(); return }
        let granted = CGRequestScreenCaptureAccess()
        dashboard.permission = granted
        if !granted { openPermissions() }
        showSettings()
    }
    @objc private func screenLocked() { if enabled { resumeAlignment.suspend() }; locked = true; safety.reset(); stopCapture(); configureTimer(); status = "Paused · screen locked"; refreshStatus() }
    @objc private func screenUnlocked() { locked = false; didWake() }
    @objc private func willSleep() { if enabled { resumeAlignment.suspend() }; suspended = true; safety.reset(); stopCapture(); configureTimer(); status = "Paused · sleeping"; refreshStatus() }
    @objc private func didWake() {
        // System and display wake can both arrive. Reset recovery only once.
        guard suspended || capture == nil else { return }
        suspended = false
        configureTimer()
        safety.reset()
        safety.recoveryDelay = 0.15
        lastReading = 0; lastAnglePoll = 0
        sensor = LidSensor()
        if enabled { update() }
    }
    @objc private func displaysChanged() {
        guard enabled else { return }
        // Stop before AppKit can relocate a fullscreen panel onto an external screen.
        stopCapture(); safety.reset(); safety.recoveryDelay = 0.5; status = "Waiting for built-in display…"; refreshStatus()
    }
    private func fitOverlay(to screen: NSScreen) {
        view.preferredFramesPerSecond = FrameCadence.framesPerSecond(requested: preferences.integer(forKey: "quality"), displayMaximum: screen.maximumFramesPerSecond, conserveEnergy: preferences.bool(forKey: "respectLowPower") && ProcessInfo.processInfo.isLowPowerModeEnabled)
        configureTimer()
        window.setFrame(screen.frame, display: false)
        view.frame = NSRect(origin: .zero, size: screen.frame.size)
        // A zero-sized MTKView can retain contentsScale == 0 after resizing.
        // A valid drawableSize still renders successfully, but presents no pixels.
        view.layer?.contentsScale = screen.backingScaleFactor
        view.drawableSize = CGSize(width: screen.frame.width * screen.backingScaleFactor, height: screen.frame.height * screen.backingScaleFactor)
    }
    @objc private func powerChanged() { applyPreferences() }
    private func configureTimer() {
        let interval = enabled && !suspended && !locked && pauseDeadline == nil ? 1 / Double(max(1, view.preferredFramesPerSecond)) : 0.2
        guard timer == nil || abs(interval - timerInterval) > 0.0001 else { return }
        timer?.invalidate(); timerInterval = interval
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.update() }
        timer?.tolerance = enabled ? interval * 0.05 : 0.04
        RunLoop.main.add(timer!, forMode: .common)
    }
    private func installApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(title: "Foldable"); appItem.submenu = appMenu
        let settings = NSMenuItem(title: "Foldable Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Foldable", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let quit = NSMenuItem(title: "Quit Foldable", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; appMenu.addItem(quit)
        let windowItem = NSMenuItem(); main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window"); windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.mainMenu = main; NSApp.windowsMenu = windowMenu
    }
    private var savedShortcut: ShortcutConfiguration {
        guard let data = preferences.data(forKey: "toggleShortcut"),
              let value = try? JSONDecoder().decode(ShortcutConfiguration.self, from: data), value.validationError == nil else { return .default }
        return value
    }
    private func setShortcut(_ chord: ShortcutConfiguration) {
        do {
            if let shortcut { try shortcut.replace(with: chord) }
            else { shortcut = try GlobalShortcut(configuration: chord) { [weak self] in self?.toggleEnabled() } }
            preferences.set(try JSONEncoder().encode(chord), forKey: "toggleShortcut")
            dashboard.shortcutConfiguration = chord
            dashboard.shortcutAvailable = true
            dashboard.shortcutMessage = "Saved. \(chord.label) now toggles Foldable."
        } catch { dashboard.shortcutMessage = error.localizedDescription }
        refreshStatus()
    }
    private func recordShortcut(_ recording: Bool) {
        if recording { shortcut?.pauseRegistration(); return }
        do { try shortcut?.resumeRegistration() }
        catch { dashboard.shortcutMessage = error.localizedDescription }
        dashboard.shortcutAvailable = shortcut?.isRegistered == true
    }
    @objc private func showShortcutSettings() { dashboard.page = .shortcuts; showSettings() }
    @objc private func setStyle(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        preferences.set(value, forKey: "foldStyle"); applyPreferences()
    }
    @objc private func setQuality(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        preferences.set(value, forKey: "quality"); applyPreferences()
    }
    @objc private func setFeel(_ sender: NSMenuItem) {
        let name = sender.representedObject as? String ?? "Balanced"
        preferences.set(name == "Direct" ? 0.025 : name == "Silky" ? 0.075 : 0.045, forKey: "response")
        preferences.set(name == "Direct" ? 10.0 : name == "Silky" ? 20.0 : 15.0, forKey: "handoffWidth")
        preferences.set(0.0, forKey: "jitterTolerance"); applyPreferences()
    }
    @objc private func togglePause() {
        guard enabled else { return }
        pauseDeadline = pauseDeadline == nil ? Date().addingTimeInterval(600) : nil
        dashboard.paused = pauseDeadline != nil
        stopCapture(); safety.reset(); configureTimer(); update()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); window?.orderOut(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "Foldable"; alert.informativeText = message; alert.runModal()
    }
}
