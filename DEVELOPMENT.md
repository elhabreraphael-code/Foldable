# Developing Foldable 1.1.1 Final

Foldable is a standalone SwiftPM macOS app with no third-party dependencies. Read README.md before changing onboarding, capture, or packaging.

- `Dashboard.swift`: native SwiftUI sidebar/settings, system appearance, presets, and a display-driven generated-artwork Metal preview. Hidden/settled previews pause; Reduce Motion disables preview interpolation.
- `MenuBarApp.swift`: app lifecycle, independent sensing timer, capture policy integration, native menu/shortcuts, raw activation guard, display safety, and fresh-frame alignment.
- `DesktopCapture.swift`: cancellable ScreenCaptureKit discovery/stream, complete-frame validation, app exclusion, matched sRGB/cadence, no audio or disk storage.
- `Renderer.swift`: Metal perspective, progressive Gaussian edge blur, in-flight frame retention, unchanged-frame suppression, and idle texture release.
- `CapturePolicy.swift`: deterministic 10–15° prewarm gate, 3° hysteresis, 650 ms shutdown delay, and display/Low Power cadence clamping.
- `MotionSmoothing.swift`: analytic critically damped spring with velocity continuity, bounded target arrival, and stall-safe elapsed time.
- `OverlayHandoff.swift`: quintic boundary flattening/fade and fresh-sample resume gate.
- `Tests/`: executable assertions for motion, capture timing, display safety, invalid input, and cadence. Run `swift run LidPlaneChecks` in debug mode so all preconditions execute.

Build with `./script/build_fold.sh release`. Moving a checkout can invalidate Swift's absolute module-cache paths; `swift package clean` repairs this without changing app permissions. Bundle once after source checks, then use `script/package_fold.sh` to export that exact binary without rebuilding it.

`--preview` checks Metal offscreen. `--window-check` briefly shows generated artwork and verifies visible pixels, Retina scaling, hide/show, click-through, GPU completion and hotkey dispatch. `--dashboard-check` briefly presents synthetic settings in light/dark appearance and compact layouts. These modes never save desktop capture frames.

Keep the raw angle ceiling independent of smoothing. Cancel old discovery synchronously before awaiting stop. Every restarted capture must pair a new sensor sample with a complete frame; never resume a pre-lock frame. Clear retained textures at idle, but let in-flight command buffers retain their resources until GPU completion.

## Final build additions

`ShortcutConfiguration.swift` contains the portable chord model, validation, and V1/V2 style identity. `GlobalShortcut.swift` replaces registration transactionally and pauses it only while the focused shortcut recorder is active. `ShortcutRecorder.swift` restores registration on completion, Escape, focus loss, or dismantling. `ShortcutChecks.swift` exercises actual Carbon registration, replacement, conflict rollback, and local recorder input during the window check.

The final `OverlayHandoff.presentation` stages geometry and alpha separately. Opening no longer caps the spring displacement to raw whole-degree samples outside the handoff. `HandoffSmoothing` reconstructs the boundary at display cadence with a short response, releasing its latency near zero to avoid a delayed cutoff. Reset it alongside the fold spring at capture start/stop, activation exit, and motion reset. The dashboard uses the same path. The independent raw visibility guard remains immediate. RenderChecks exercises V2 identity, distinct projection, and alpha during style morphs. Origami uses inverse projection for three panels; all modes retain matching color spaces, progressive edge coverage, and premultiplied alpha.

The menu-bar menu exposes sliders; the window toolbar exposes quick choices. The normal toggle shortcut is the only persistent registered chord. Recording test events are sent to this app only. A ten-minute pause keeps the effect preference enabled while stopping capture; a Date deadline survives system sleep. No automatic re-enable is persisted across relaunch.
