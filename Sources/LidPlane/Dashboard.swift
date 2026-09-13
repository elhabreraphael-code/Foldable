// Copyright (c) 2026 Jhey; Fold interface and additions (c) 2026 Fold contributors
// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI
import MetalKit
import ServiceManagement

final class DashboardModel: ObservableObject {
    @Published var angle: Double? = nil
    @Published var enabled = false
    @Published var status = "Off"
    @Published var permission = false
    @Published var shortcutAvailable = true
    @Published var previewAngle = 110.0
    @Published var followHinge = false
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var message = ""
    var toggle: () -> Void = {}
    var authorize: () -> Void = {}
    var apply: () -> Void = {}
    var calibrate: () -> Void = {}
    var reset: () -> Void = {}
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { message = "Approve Foldable in System Settings → General → Login Items."; SMAppService.openSystemSettingsLoginItems() }
        } catch { message = error.localizedDescription }
    }
}

struct FoldDashboard: View {
    @ObservedObject var model: DashboardModel
    @State private var page = 0
    @State private var playing = false
    @State private var playStart = Date()
    @AppStorage("activationAngle") private var activation = 110.0
    @AppStorage("blurStrength") private var strength = 1.0
    @AppStorage("response") private var response = 0.045
    @AppStorage("jitterTolerance") private var jitter = 0.0
    @AppStorage("blur") private var blur = true
    @AppStorage("tilt") private var tilt = true
    @AppStorage("perspective") private var perspective = true
    @AppStorage("showHUD") private var hud = true
    @AppStorage("quality") private var quality = 60
    private let accent = Color(red: 0.42, green: 0.57, blue: 1)
    private let previewTimer = Timer.publish(every: 1.0/60, on: .main, in: .common).autoconnect()
    private var displayedAngle: Double { model.followHinge ? (model.angle ?? activation) : model.previewAngle }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.45)
            VStack(alignment: .leading, spacing: 22) {
                header
                if page == 0 { overview }
                else if page == 1 { tuning }
                else { details }
                Spacer(minLength: 0)
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield").font(.system(size: 11))
                    Text("On your Mac. In the moment.").font(.system(size: 11))
                    Spacer()
                    Text("FOLDABLE  /  1.0").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.3)
                }.foregroundStyle(.secondary)
            }.padding(.horizontal, 30).padding(.top, 30).padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.085, green: 0.088, blue: 0.105))
        }
        .frame(width: 940, height: 700)
        .preferredColorScheme(.dark).tint(accent)
        .onReceive(previewTimer) { date in
            guard playing else { return }
            let elapsed = date.timeIntervalSince(playStart)
            if elapsed > 5.6 { playing = false; model.previewAngle = activation; return }
            let phase = min(1, elapsed / 5.6)
            model.previewAngle = activation - (activation - 20) * pow(sin(phase * .pi), 2)
        }
        .onChange(of: activation) { _ in model.apply() }
        .onChange(of: strength) { _ in model.apply() }
        .onChange(of: response) { _ in model.apply() }
        .onChange(of: jitter) { _ in model.apply() }
        .onChange(of: blur) { _ in model.apply() }
        .onChange(of: tilt) { _ in model.apply() }
        .onChange(of: perspective) { _ in model.apply() }
        .onChange(of: hud) { _ in model.apply() }
        .onChange(of: quality) { _ in model.apply() }
        .alert("Foldable", isPresented: Binding(get: { !model.message.isEmpty }, set: { if !$0 { model.message = "" } })) {
            Button("OK") { model.message = "" }
        } message: { Text(model.message) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer").font(.system(size: 25, weight: .light)).foregroundStyle(.white)
                Text("Foldable").font(.system(size: 28, weight: .semibold)).tracking(-1)
            }.padding(.top, 42).padding(.bottom, 8)
            Text("A little physical magic.").font(.system(size: 11)).foregroundStyle(.secondary)
            VStack(spacing: 6) {
                nav("Overview", icon: "square.grid.2x2", id: 0)
                nav("Fine-tune", icon: "slider.horizontal.3", id: 1)
                nav("Setup & about", icon: "info.circle", id: 2)
            }.padding(.top, 38)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) { Circle().fill(model.angle == nil ? Color.orange : Color.green).frame(width: 6, height: 6); Text(model.angle == nil ? "Sensor unavailable" : "Hinge connected").font(.system(size: 11)) }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(model.angle.map { String(Int($0.rounded())) } ?? "—").font(.system(size: 42, weight: .light, design: .rounded)).monospacedDigit()
                    Text("°").font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                }
                Text("LIVE LID ANGLE").font(.system(size: 9, weight: .medium)).tracking(1.6).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
            Text(model.shortcutAvailable ? "⌃ ⌘ L  Toggle effect" : "Shortcut is used by another app").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 15).padding(.bottom, 24)
        }.padding(.horizontal, 20).frame(width: 194).background(Color(red: 0.065, green: 0.068, blue: 0.082))
    }
    private func nav(_ title: String, icon: String, id: Int) -> some View {
        Button { page = id } label: {
            HStack(spacing: 11) { Image(systemName: icon).frame(width: 16); Text(title).font(.system(size: 12, weight: page == id ? .medium : .regular)); Spacer() }
                .foregroundStyle(page == id ? .white : .white.opacity(0.55)).padding(.horizontal, 12).padding(.vertical, 11)
                .background(page == id ? .white.opacity(0.085) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(page == 0 ? "Made to move." : page == 1 ? "Find your feel." : "Make yourself at home.").font(.system(size: 28, weight: .semibold)).tracking(-0.8)
                Text(page == 0 ? "Your desktop, beautifully in sync with your lid." : page == 1 ? "Small adjustments. A seamless impression." : "Everything you need for a smooth first fold.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: model.toggle) {
                HStack(spacing: 7) { Circle().fill(model.enabled ? Color.green : Color.white.opacity(0.5)).frame(width: 6, height: 6); Text(model.enabled ? "Enabled" : "Enable Foldable").font(.system(size: 12, weight: .medium)) }
                .padding(.horizontal, 15).padding(.vertical, 10)
                .background(model.enabled ? Color.green.opacity(0.12) : accent.opacity(0.2), in: Capsule())
                .overlay(Capsule().strokeBorder(model.enabled ? Color.green.opacity(0.25) : accent.opacity(0.3)))
            }.buttonStyle(.plain).accessibilityLabel(model.enabled ? "Disable Foldable" : "Enable Foldable")
        }
    }
    private var overview: some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                HStack {
                    Label("THE FOLD", systemImage: "sparkle").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(.secondary)
                    Spacer()
                    Text(model.followHinge ? "LIVE PREVIEW" : "INTERACTIVE PREVIEW").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(.tertiary)
                }.padding(.horizontal, 20).padding(.top, 17)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 17).fill(.black).shadow(color: accent.opacity(0.12), radius: 25, y: 12)
                    FoldMetalPreview(angle: max(0, activation - displayedAngle), strength: blur ? strength : 0, warp: tilt, perspective: perspective)
                        .clipShape(RoundedRectangle(cornerRadius: 10)).padding(7)
                    UnevenNotch().fill(.black).frame(width: 57, height: 12).padding(.top, 6)
                }.frame(width: 468, height: 288).overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.2)))
                    .padding(.top, 22)
                RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom)).frame(width: 510, height: 7).padding(.top, 3)
                HStack(spacing: 13) {
                    Button { playing.toggle(); if playing { model.followHinge = false; playStart = Date() } } label: { Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 26, height: 26) }.buttonStyle(.plain).help("Play the folding preview")
                    Slider(value: Binding(get: { model.previewAngle }, set: { playing = false; model.previewAngle = $0 }), in: 10...max(110, activation)).disabled(model.followHinge).accessibilityLabel("Preview lid angle")
                    Text("\(Int(displayedAngle))°").font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 40)
                    Toggle("Live hinge", isOn: $model.followHinge).toggleStyle(.checkbox).font(.system(size: 11)).onChange(of: model.followHinge) { _ in playing = false }
                }.padding(.horizontal, 24).padding(.top, 21).padding(.bottom, 18)
            }.background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.07)))
            HStack(alignment: .top, spacing: 14) {
                card {
                    Label("Ready when you are", systemImage: "waveform.path").font(.system(size: 12, weight: .medium))
                    Text(model.enabled ? model.status : "Enable Foldable, then gently lower your lid.").font(.system(size: 11)).foregroundStyle(.secondary).frame(height: 28, alignment: .top)
                    Text("Begins below \(Int(activation))°").font(.system(size: 11, weight: .medium)).foregroundStyle(accent)
                }
                card {
                    Label(model.permission ? "Screen access ready" : "One quick permission", systemImage: model.permission ? "checkmark.shield" : "display").font(.system(size: 12, weight: .medium))
                    Text("Live frames stay in memory on your Mac.").font(.system(size: 11)).foregroundStyle(.secondary).frame(height: 28, alignment: .top)
                    Button(model.permission ? "Review setup →" : "Allow screen access →") { if model.permission { page = 2 } else { model.authorize() } }.buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(accent)
                }
            }
        }
    }
    private var tuning: some View {
        VStack(spacing: 16) {
            card {
                Text("MOTION").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(.secondary)
                parameter("Start angle", detail: "The effect is invisible above this angle.", value: $activation, range: 45...140, step: 1, label: "\(Int(activation))°")
                HStack { Spacer(); Button("Use current lid angle", action: model.calibrate).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(accent).disabled(model.angle == nil) }
                Divider().opacity(0.5)
                parameter("Smoothing", detail: "Lower feels direct. Higher feels softer.", value: $response, range: 0.02...0.12, step: 0.005, label: "\(Int(response * 1000)) ms")
                parameter("Steadiness", detail: "Ignore tiny hinge movements.", value: $jitter, range: 0...3, step: 0.5, label: String(format: "%.1f°", jitter))
            }
            card {
                Text("FINISH").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(.secondary)
                parameter("Glass softness", detail: "Progressive blur grows away from the hinge.", value: $strength, range: 0.3...1.6, step: 0.05, label: "\(Int(strength * 100))%")
                HStack { Toggle("Progressive blur", isOn: $blur); Spacer(); Toggle("Perspective", isOn: $perspective); Spacer(); Toggle("Hold image in space", isOn: $tilt) }.toggleStyle(.checkbox).font(.system(size: 11)).padding(.top, 5)
                Divider().opacity(0.5)
                HStack { Text("Motion quality").font(.system(size: 12)); Spacer(); Picker("Motion quality", selection: $quality) { Text("Balanced · 60 Hz").tag(60); Text("ProMotion · up to 120 Hz").tag(120) }.labelsHidden().frame(width: 220) }
                Text("ProMotion adapts to the built-in display. Capture runs at up to 60 fps.").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack { Button("Restore defaults", action: model.reset).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Text("Changes apply immediately.").font(.system(size: 11)).foregroundStyle(.tertiary) }
        }
    }
    private var details: some View {
        VStack(spacing: 16) {
            card {
                setupRow("01", "Connect your screen", model.permission ? "Screen capture is authorized." : "Allow Screen Recording to animate your live desktop.") {
                    Button(model.permission ? "Settings…" : "Allow access", action: model.authorize)
                }
                Divider().padding(.vertical, 5)
                setupRow("02", "Enable and gently fold", "Lower the lid below \(Int(activation))°. Keep your head and the base still.") { EmptyView() }
                Divider().padding(.vertical, 5)
                setupRow("03", "Make it yours", "Tune the start angle and softness in Fine-tune.") { Button("Fine-tune") { page = 1 } }
            }
            card {
                Toggle("Show live angle in the menu bar", isOn: $hud).font(.system(size: 12))
                Divider()
                Toggle("Open Foldable at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).font(.system(size: 12))
                Text("Foldable opens with the effect off. Press Control–Command–L to enable it.").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            card {
                Text("A Mac interpretation of the folding illusion.").font(.system(size: 12, weight: .medium))
                Text("The effect runs on the built-in display while you’re unlocked. Normal lid-close sleep still applies. Protected video may appear blank; transformed pixels don’t move the underlying click targets.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Foldable 1.0 · Local build, ad-hoc signed; not notarized. MacBook Pro hardware testing is still required.").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Link("Built on Lid Plane by Jhey ↗", destination: URL(string: "https://github.com/jh3y/lid-plane")!)
                    Button("GPL-3.0 license") { if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) { NSWorkspace.shared.open(url) } }.buttonStyle(.plain)
                }.font(.system(size: 10)).foregroundStyle(accent)
            }
        }
    }
    private func setupRow<Content: View>(_ number: String, _ title: String, _ detail: String, @ViewBuilder action: () -> Content) -> some View {
        HStack(spacing: 15) {
            Text(number).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(accent).frame(width: 30, height: 30).background(accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            Spacer(); action().controlSize(.small)
        }
    }
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.055)))
    }
    private func parameter(_ name: String, detail: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(name).font(.system(size: 12, weight: .medium)); Spacer(); Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary) }
            Slider(value: value, in: range, step: step).accessibilityLabel(name)
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

struct UnevenNotch: Shape {
    func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerRadius: 4) }
}

final class PreviewMetalView: MTKView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        layer?.contentsScale = window.backingScaleFactor
        drawableSize = CGSize(width: max(2, bounds.width * window.backingScaleFactor), height: max(2, bounds.height * window.backingScaleFactor))
        DispatchQueue.main.async { [weak self] in self?.draw() }
    }
    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        drawableSize = CGSize(width: max(2, bounds.width * scale), height: max(2, bounds.height * scale))
        needsDisplay = true
    }
}
struct FoldMetalPreview: NSViewRepresentable {
    var angle: Double
    var strength: Double
    var warp: Bool
    var perspective: Bool
    final class Coordinator { var renderer: PlaneRenderer? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> MTKView {
        let gpu = MTLCreateSystemDefaultDevice()
        let view = PreviewMetalView(frame: CGRect(x: 0, y: 0, width: 454, height: 274), device: gpu)
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        if let gpu, let renderer = try? PlaneRenderer(gpu: gpu) { context.coordinator.renderer = renderer; view.delegate = renderer }
        return view
    }
    func updateNSView(_ view: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.delta = Float(angle * .pi / 180)
        renderer.blur = strength > 0
        renderer.blurStrength = Float(strength)
        renderer.warp = warp
        renderer.perspective = perspective
        view.layer?.contentsScale = view.window?.backingScaleFactor ?? 2
        view.drawableSize = CGSize(width: max(2, view.bounds.width * (view.window?.backingScaleFactor ?? 2)), height: max(2, view.bounds.height * (view.window?.backingScaleFactor ?? 2)))
        view.needsDisplay = true
    }
}
