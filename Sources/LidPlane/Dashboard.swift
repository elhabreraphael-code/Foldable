// Copyright (c) 2026 Jhey; Fold interface and additions (c) 2026 Fold contributors
// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI
import MetalKit
import ServiceManagement
import LidPlaneCore

final class DashboardModel: ObservableObject {
    var liveAngle: Double?
    @Published var page: DashboardPage = .overview
    @Published var angle: Double?
    @Published var enabled = false
    @Published var status = "Off"
    @Published var permission = false
    @Published var shortcutAvailable = true
    @Published var shortcutConfiguration = ShortcutConfiguration.default
    @Published var shortcutMessage = ""
    @Published var paused = false
    @Published var previewAngle = 110.0
    @Published var followHinge = false
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var captureStatus = "Sleeping"
    @Published var frameRate = 60
    @Published var frameCount = 0
    @Published var message = ""
    var toggle: () -> Void = {}
    var authorize: () -> Void = {}
    var apply: () -> Void = {}
    var calibrate: () -> Void = {}
    var reset: () -> Void = {}
    var setShortcut: (ShortcutConfiguration) -> Void = { _ in }
    var recordShortcut: (Bool) -> Void = { _ in }
    var pause: () -> Void = {}
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                message = "Approve Foldable in System Settings → General → Login Items."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { message = error.localizedDescription }
    }
}

enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "Overview", motion = "Motion", capture = "Screen Capture", shortcuts = "Shortcuts", about = "General"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "macbook"
        case .motion: return "slider.horizontal.3"
        case .capture: return "rectangle.inset.filled.and.person.filled"
        case .shortcuts: return "keyboard"
        case .about: return "gearshape"
        }
    }
}

struct FoldDashboard: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var page: DashboardPage { model.page }
    @State private var playing = false
    @State private var loopPreview = false
    @State private var playStart = Date()
    @State private var confirmReset = false
    @AppStorage("activationAngle") private var activation = 110.0
    @AppStorage("angleMode") private var angleMode = true
    @AppStorage("blurStrength") private var strength = 1.0
    @AppStorage("response") private var response = 0.045
    @AppStorage("jitterTolerance") private var jitter = 0.0
    @AppStorage("handoffWidth") private var handoff = 15.0
    @AppStorage("captureLead") private var lead = 12.0
    @AppStorage("respectLowPower") private var lowPower = true
    @AppStorage("blur") private var blur = true
    @AppStorage("tilt") private var tilt = true
    @AppStorage("perspective") private var perspective = true
    @AppStorage("showHUD") private var hud = true
    @AppStorage("quality") private var quality = 60
    @AppStorage("foldStyle") private var foldStyle = 0
    @AppStorage("foldDepth") private var foldDepth = 1.0
    private var displayedAngle: Double { model.followHinge ? (model.angle ?? activation) : model.previewAngle }
    private static let artwork = NSImage(cgImage: PlaneRenderer.artwork(), size: NSSize(width: 1600, height: 1000))
    private var settingsSignature: String {
        "\(activation)|\(angleMode)|\(strength)|\(response)|\(jitter)|\(handoff)|\(lead)|\(lowPower)|\(blur)|\(tilt)|\(perspective)|\(hud)|\(quality)|\(foldStyle)|\(foldDepth)"
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List {
                    ForEach(Array(DashboardPage.allCases.enumerated()), id: \.element.id) { index, item in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { model.page = item }
                        } label: {
                            Label(item.rawValue, systemImage: item.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                        .listRowBackground(page == item ? Color.accentColor.opacity(0.16) : Color.clear)
                        .accessibilityAddTraits(page == item ? .isSelected : [])
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 7) {
                    Label(model.angle == nil ? "Sensor unavailable" : "Hinge connected", systemImage: model.angle == nil ? "exclamationmark.circle" : "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(model.angle == nil ? .orange : .secondary)
                    Text(model.angle.map { "\(Int($0.rounded()))°" } ?? "—°")
                        .font(.system(size: 34, weight: .light, design: .rounded)).monospacedDigit()
                    Text("Current lid angle").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                Divider()
                Text(model.shortcutAvailable ? "\(model.shortcutConfiguration.label)  Toggle Foldable" : "Toggle shortcut unavailable")
                    .font(.caption).foregroundStyle(.secondary).padding(14)
            }.navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(page == .overview ? "A little physical magic." : page.rawValue)
                            .font(.largeTitle.weight(.semibold))
                        Text(subtitle).font(.body).foregroundStyle(.secondary)
                    }
                    Group {
                        switch page {
                        case .overview: overview
                        case .motion: motionSettings
                        case .capture: captureSettings
                        case .shortcuts: shortcutSettings
                        case .about: generalSettings
                        }
                    }.transition(.opacity)
                    HStack {
                        Label("On your Mac. In the moment.", systemImage: "lock.shield")
                        Spacer()
                        Text("Foldable 1.1.1 Final")
                    }.font(.caption).foregroundStyle(.tertiary)
                }.padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Foldable")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Picker("Animation", selection: $foldStyle) {
                            Text("V1 · Classic").tag(0)
                            Text("V2 · Origami (Beta)").tag(1)
                        }
                        Menu("Motion feel") { presetButtons }
                        Picker("Refresh rate", selection: $quality) {
                            Text("60 Hz").tag(60); Text("Up to 120 Hz").tag(120)
                        }
                        Divider()
                        Toggle("Progressive blur", isOn: $blur)
                        Toggle("Perspective taper", isOn: $perspective)
                        if model.enabled { Button(model.paused ? "Resume now" : "Pause for 10 minutes", action: model.pause) }
                        Divider()
                        Button("Edit toggle shortcut…") { model.page = .shortcuts }
                    } label: { Image(systemName: "slider.horizontal.3") }
                    .help("Quick settings").accessibilityLabel("Quick settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: model.toggle) {
                        Text(model.enabled ? "Disable" : "Enable")
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 74)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .help("Toggle the live effect (\(model.shortcutConfiguration.label))")
                    .accessibilityIdentifier("effect-toggle")
                }
            }
        }
        .frame(minWidth: 800, idealWidth: 940, minHeight: 560, idealHeight: 700)
        .onChange(of: settingsSignature) { _ in model.apply() }
        .onChange(of: page) { _ in playing = false }
        // No always-running preview timer. Metal animates at display cadence;
        // this cancellable task updates only the angle label during playback.
        .task(id: playing) {
            guard playing else { return }
            while !Task.isCancelled {
                let elapsed = max(0, Date().timeIntervalSince(playStart) / 5.6)
                let phase = loopPreview ? elapsed.truncatingRemainder(dividingBy: 1) : min(1, elapsed)
                model.previewAngle = activation - (activation - 20) * pow(sin(phase * .pi), 2)
                if phase >= 1 { playing = false; model.previewAngle = activation; return }
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            }
        }
        .alert("Restore Foldable defaults?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Restore defaults") { model.reset() }
        } message: { Text("Resets motion and capture settings. Your screen permission and login preference are preserved.") }
        .alert("Foldable", isPresented: Binding(get: { !model.message.isEmpty }, set: { if !$0 { model.message = "" } })) {
            Button("OK") { model.message = "" }
        } message: { Text(model.message) }
    }

    private var subtitle: String {
        switch page {
        case .overview: return "Your desktop, moving with your MacBook."
        case .motion: return "Find the feel that belongs on your Mac."
        case .capture: return "Ready just before the fold. Asleep when you’re done."
        case .shortcuts: return "One shortcut, exactly the way you like it."
        case .about: return "Small comforts. Thoughtful defaults."
        }
    }

    private var overview: some View {
        VStack(spacing: 14) {
            Picker("Folding style", selection: $foldStyle) {
                Text("V1 · Classic").tag(0)
                Text("V2 · Origami — Beta").tag(1)
            }.pickerStyle(.segmented).accessibilityLabel("Folding style")
            GroupBox {
                VStack(spacing: 16) {
                    HStack {
                        Label("Try a fold", systemImage: "play.rectangle")
                        Spacer()
                        Text("Preview artwork · no screen access needed").font(.caption).foregroundStyle(.secondary)
                    }
                    ZStack {
                        Image(nsImage: Self.artwork).resizable()
                        FoldMetalPreview(angle: max(0, activation - displayedAngle), activation: activation,
                            response: response, handoff: handoff, style: foldStyle, depth: foldDepth, loop: loopPreview, strength: blur ? strength : 0,
                            warp: tilt, perspective: perspective, playing: playing, playStart: playStart,
                            reduceMotion: reduceMotion, frameRate: model.frameRate,
                            liveAngle: model.followHinge ? { model.liveAngle } : nil)
                    }
                    .aspectRatio(1.6, contentMode: .fit)
                    .frame(maxWidth: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
                    .accessibilityLabel("Interactive folding preview")
                    HStack(spacing: 12) {
                        Button {
                            playing.toggle()
                            if playing { model.followHinge = false; playStart = Date() }
                        } label: { Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 20) }
                            .help(playing ? "Pause preview" : "Play a fold and unfold")
                            .accessibilityLabel(playing ? "Pause preview" : "Play preview")
                        Slider(value: Binding(get: { model.previewAngle }, set: { playing = false; model.previewAngle = $0 }), in: 10...max(110, activation))
                            .disabled(model.followHinge).accessibilityLabel("Preview lid angle")
                        Text("\(Int(displayedAngle))°").monospacedDigit().frame(width: 38)
                        Toggle("Live hinge", isOn: $model.followHinge).toggleStyle(.checkbox)
                            .onChange(of: model.followHinge) { _ in playing = false }
                    }.controlSize(.small)
                    HStack {
                        Toggle("Loop preview", isOn: $loopPreview).toggleStyle(.checkbox)
                        Spacer()
                        Text(foldStyle == 1 ? "Three articulated panels · Beta" : "The original, continuous plane")
                            .foregroundStyle(.secondary)
                        Button("Reset") { playing = false; model.followHinge = false; model.previewAngle = activation }
                    }.font(.caption).controlSize(.small)
                }.padding(12)
            }
            HStack(alignment: .top, spacing: 14) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(model.enabled ? model.status : "Ready when you are", systemImage: "waveform.path")
                            .font(.headline)
                        Text(angleMode ? "Fold begins below \(Int(activation))°." : "Motion mode follows your anchored angle.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Adjust motion…") { model.page = .motion }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(model.permission ? "Screen access ready" : "Allow your first fold", systemImage: model.permission ? "checkmark.shield" : "display")
                            .font(.headline)
                        Text("Live frames stay in memory on your Mac.").font(.callout).foregroundStyle(.secondary)
                        Button(model.permission ? "Capture settings…" : "Allow screen access…") {
                            if model.permission { model.page = .capture } else { model.authorize() }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }
        }
    }

    private var motionSettings: some View {
        VStack(spacing: 18) {
            section("Make it feel right") {
                HStack {
                    Text("Start with a feel").font(.headline)
                    Spacer()
                    presetButtons
                }.controlSize(.small)
                Text("Presets adjust smoothing, handoff, and steadiness. Fine-tune below.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Toggle("Activate below a fixed lid angle", isOn: $angleMode)
                parameter("Start angle", detail: "Above this angle, your real desktop is fully visible.", value: $activation, range: 10...180, step: 1, label: "\(Int(activation))°")
                    .disabled(!angleMode)
                HStack {
                    Text(angleMode ? "Default: 110°" : "Motion mode uses the anchor controls in the menu bar.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Use current angle", action: model.calibrate).disabled(model.angle == nil)
                }
                Divider()
                parameter("Smoothing", detail: "Direct response at the left; softer movement at the right.", value: $response, range: 0.02...0.12, step: 0.005, label: "\(Int(response * 1000)) ms")
                parameter("Desktop handoff", detail: "Flatten and dissolve across the final degrees of opening.", value: $handoff, range: 8...22, step: 1, label: "\(Int(handoff))°")
                    .disabled(!angleMode)
                parameter("Steadiness", detail: "Ignore tiny shakes while preserving slow, deliberate movement.", value: $jitter, range: 0...5, step: 0.5, label: String(format: "%.1f°", jitter))
            }
            section("Finish") {
                Picker("Folding style", selection: $foldStyle) {
                    Text("V1 · Classic").tag(0); Text("V2 · Origami (Beta)").tag(1)
                }
                if foldStyle == 1 {
                    parameter("Origami depth", detail: "Three articulated panels with soft crease shading. V2 is experimental.", value: $foldDepth, range: 0.5...1.4, step: 0.05, label: "\(Int(foldDepth * 100))%")
                }
                Toggle("Progressive blur", isOn: $blur)
                parameter("Softness", detail: "Blur grows gradually away from the hinge.", value: $strength, range: 0.3...1.6, step: 0.05, label: "\(Int(strength * 100))%")
                    .disabled(!blur)
                Divider()
                Toggle("Hold the desktop in space", isOn: $tilt)
                Toggle("Perspective taper", isOn: $perspective).disabled(!tilt)
            }
        }
    }

    private var captureSettings: some View {
        VStack(spacing: 18) {
            section("Just-in-time capture") {
                parameter("Start capture early", detail: "Warm up 10–15° before the effect starts, so its first frame is ready.", value: $lead, range: 10...15, step: 1, label: "\(Int(lead))°")
                    .disabled(!angleMode)
                Label(angleMode ? "Capture at \(Int(activation + lead))° · fold below \(Int(activation))°" : "Motion mode keeps capture ready while enabled.", systemImage: "angle")
                    .font(.callout).foregroundStyle(.secondary)
                Divider()
                Text("Opening past \(Int(activation + lead + 3))° for a moment stops capture and releases its image buffers. A small buffer zone prevents repeated starts when you hover near the edge.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("A very fast lid movement can still outrun screen-capture startup. Choose 15° for more preparation time.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            section("Motion quality") {
                Picker("Refresh rate", selection: $quality) {
                    Text("60 Hz").tag(60)
                    Text("Up to 120 Hz").tag(120)
                }.pickerStyle(.segmented)
                Text("Capture and animation follow your built-in display, up to \(model.frameRate) fps with the current settings.")
                    .font(.callout).foregroundStyle(.secondary)
                Divider()
                Toggle("Respect Low Power Mode", isOn: $lowPower)
                Text("Caps motion at 60 fps when macOS Low Power Mode is on. Capture still sleeps outside the prewarm zone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            section("Right now") {
                LabeledContent("Screen capture", value: model.captureStatus)
                LabeledContent("Complete frames this session", value: "\(model.frameCount)")
                LabeledContent("Screen access", value: model.permission ? "Allowed" : "Needed")
                Divider()
                HStack {
                    Text("No video files. No audio. No uploads.").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.permission ? "Review access…" : "Allow access…", action: model.authorize)
                }
            }
        }
    }

    private var presetButtons: some View {
        Group {
            Button("Direct") { response = 0.025; handoff = 10; jitter = 0 }
            Button("Balanced") { response = 0.045; handoff = 15; jitter = 0 }
            Button("Silky") { response = 0.075; handoff = 20; jitter = 0 }
        }
    }
    private var shortcutSettings: some View {
        VStack(spacing: 18) {
            section("Toggle Foldable") {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.shortcutConfiguration.label).font(.title2.monospaced())
                        Text(model.shortcutAvailable ? "Works while you use other apps." : "Not registered. Choose another combination.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShortcutRecorder(onChange: model.setShortcut, onRecording: model.recordShortcut)
                        .frame(width: 185, height: 30)
                }
                Text("Click Record shortcut, then press at least two modifier keys plus a letter, number, or Space. Escape cancels.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !model.shortcutMessage.isEmpty {
                    Label(model.shortcutMessage, systemImage: "info.circle")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                Button("Reset to default · ⌃⌘L") { model.setShortcut(.default) }
            }
            section("Suggested combinations") {
                Text("Try a combination below. macOS checks availability before Foldable saves it; a conflict keeps your previous shortcut.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    ForEach(ShortcutConfiguration.suggestions, id: \.label) { chord in
                        Button(chord.label) { model.setShortcut(chord) }.frame(minWidth: 80)
                    }
                }
            }
            section("Only your chosen shortcut") {
                Label("No Accessibility or Input Monitoring permission needed.", systemImage: "lock.shield")
                Text("Key recording works only inside the focused settings control. Foldable registers a single global toggle shortcut with macOS; it doesn’t listen to your typing.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                Text("Option-click the menu bar icon to toggle at any time, or click it for quick settings.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private var generalSettings: some View {
        VStack(spacing: 18) {
            section("Your Mac") {
                Toggle("Show lid angle in the menu bar", isOn: $hud)
                Toggle("Open Foldable at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                Text("Foldable starts quietly in the menu bar with the effect off.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                HStack { LabeledContent("Toggle effect", value: model.shortcutConfiguration.label); Spacer(); Button("Edit…") { model.page = .shortcuts } }
                LabeledContent("Quick toggle", value: "Option-click the menu bar icon")
                LabeledContent("Settings", value: "Command–comma")
                LabeledContent("Navigate settings", value: "Command–1 through Command–5")
            }
            section("Foldable 1.1.1 Final") {
                Text("A Mac interpretation of the folding illusion.").font(.headline)
                Text("Works on the built-in display while your Mac is unlocked. Normal lid-close sleep still applies. Protected video may appear blank. The visual effect doesn’t move the underlying click targets.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Local build · ad-hoc signed · not notarized. Hardware and wake timing vary between MacBooks.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Link("Lid Plane by Jhey ↗", destination: URL(string: "https://github.com/jh3y/lid-plane")!)
                    Spacer()
                    Button("GPL-3.0 license") {
                        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) { NSWorkspace.shared.open(url) }
                    }
                }
            }
            HStack {
                Button("Restore defaults…") { confirmReset = true }
                Spacer()
                Text("Changes save automatically.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox(label: Text(title).font(.headline)) {
            VStack(alignment: .leading, spacing: 14, content: content)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func parameter(_ name: String, detail: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(name); Spacer(); Text(label).monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: value, in: range, step: step).accessibilityLabel(name).accessibilityValue(label)
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

final class PreviewMetalView: MTKView {
    var refreshActivity: (() -> Void)?
    private var visibilityObserver: NSObjectProtocol?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let visibilityObserver { NotificationCenter.default.removeObserver(visibilityObserver) }
        visibilityObserver = nil
        guard let window else { isPaused = true; return }
        visibilityObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            self?.refreshActivity?()
        }
        resizeDrawable()
        refreshActivity?()
    }
    override func layout() { super.layout(); resizeDrawable(); refreshActivity?() }
    private func resizeDrawable() {
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        let size = CGSize(width: max(2, bounds.width * scale), height: max(2, bounds.height * scale))
        if drawableSize != size { drawableSize = size }
    }
    deinit { if let visibilityObserver { NotificationCenter.default.removeObserver(visibilityObserver) } }
}

struct FoldMetalPreview: NSViewRepresentable {
    var angle: Double
    var activation: Double
    var response: Double
    var handoff: Double
    var style: Int
    var depth: Double
    var loop: Bool
    var strength: Double
    var warp: Bool
    var perspective: Bool
    var playing: Bool
    var playStart: Date
    var reduceMotion: Bool
    var frameRate: Int
    var liveAngle: (() -> Double?)?
    private var renderingKey: [Double] {
        [angle, activation, response, handoff, Double(style), depth, strength,
         warp ? 1 : 0, perspective ? 1 : 0, playing ? 1 : 0, loop ? 1 : 0,
         playStart.timeIntervalSinceReferenceDate, reduceMotion ? 1 : 0, Double(frameRate), liveAngle == nil ? 0 : 1]
    }
    final class Coordinator {
        var renderer: PlaneRenderer?
        weak var view: PreviewMetalView?
        var spring = FoldSpring()
        var handoffMotion = HandoffSmoothing()
        var configuration: FoldMetalPreview?
        var previousTick = CACurrentMediaTime()
        func refresh() {
            guard let view, view.window?.occlusionState.contains(.visible) == true else { view?.isPaused = true; return }
            previousTick = CACurrentMediaTime()
            renderer?.invalidatePresentation()
            view.isPaused = false
        }
        func tick() {
            guard let renderer, let view, let c = configuration else { return }
            let now = CACurrentMediaTime()
            let dt = now - previousTick; previousTick = now
            var targetDegrees = c.liveAngle.map { max(0, c.activation - ($0() ?? c.activation)) } ?? c.angle
            if c.playing {
                let elapsed = max(0, Date().timeIntervalSince(c.playStart) / 5.6)
                let phase = c.loop ? elapsed.truncatingRemainder(dividingBy: 1) : min(1, elapsed)
                targetDegrees = (c.activation - 20) * pow(sin(phase * .pi), 2)
            }
            let target = targetDegrees * .pi / 180
            if c.reduceMotion { spring.reset(to: target); handoffMotion.reset() }
            else { spring.advance(to: target, elapsed: dt, response: c.response) }
            renderer.delta = Float(spring.value)
            let distance = handoffMotion.advance(distance: targetDegrees, elapsed: dt, response: c.response, width: c.handoff)
            let presentation = OverlayHandoff.presentation(delta: spring.value, rawDistance: distance,
                angleMode: true, width: c.handoff, elapsedSinceFrame: 1)
            renderer.geometryWeight = Float(presentation.geometry)
            renderer.opacity = Float(presentation.opacity)
            renderer.foldStyle = Float(MotionSmoothing.advance(Double(renderer.foldStyle), to: Double(c.style), elapsed: dt, response: 0.10))
            if abs(renderer.foldStyle - Float(c.style)) < 0.0001 { renderer.foldStyle = Float(c.style) }
            if !c.playing && c.liveAngle == nil && spring.isSettled(at: target) && handoffMotion.isSettled(at: targetDegrees) && renderer.foldStyle == Float(c.style) { view.isPaused = true }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PreviewMetalView {
        let gpu = MTLCreateSystemDefaultDevice()
        let view = PreviewMetalView(frame: CGRect(x: 0, y: 0, width: 560, height: 350), device: gpu)
        view.colorPixelFormat = .bgra8Unorm
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        context.coordinator.view = view
        if let gpu, let renderer = try? PlaneRenderer(gpu: gpu) {
            context.coordinator.renderer = renderer; view.delegate = renderer
            renderer.tick = { [weak coordinator = context.coordinator] in coordinator?.tick() }
        }
        view.refreshActivity = { [weak coordinator = context.coordinator] in coordinator?.refresh() }
        return view
    }
    func updateNSView(_ view: PreviewMetalView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        let changed = context.coordinator.configuration?.renderingKey != renderingKey
        context.coordinator.configuration = self
        renderer.blur = strength > 0; renderer.blurStrength = Float(strength)
        renderer.warp = warp; renderer.perspective = perspective; renderer.foldDepth = Float(depth)
        view.preferredFramesPerSecond = min(frameRate, view.window?.screen?.maximumFramesPerSecond ?? 60)
        if changed && view.isPaused { context.coordinator.refresh() }
    }
    static func dismantleNSView(_ view: PreviewMetalView, coordinator: Coordinator) {
        view.isPaused = true; view.delegate = nil; view.refreshActivity = nil
        coordinator.renderer?.tick = nil
    }
}
