# Developing Foldable

Read README.md for build instructions, checks, limitations and attribution. `script/build_fold.sh` is the maintained Foldable build entrypoint; legacy upstream packaging and permission-repair scripts have been removed to avoid targeting the original app. Use `script/package_fold.sh` to export Foldable without recompiling it.

- `Dashboard.swift`: SwiftUI interface, interactive Metal preview and opt-in login item.
- `MenuBarApp.swift`: app lifecycle, permissions, menu, overlay and live motion.
- `Renderer.swift`: Metal perspective and Gaussian blur, original vector artwork.
- `DesktopCapture.swift`: ScreenCaptureKit and adaptive capture frame rate.
- `Sensor.swift`: read-only hinge HID report.
- `OverlayHandoff.swift`: boundary flattening/opacity and fresh-sample wake alignment.
- `MotionSmoothing.swift`: refresh-rate-independent reversible easing.
- `Tests/`: motion/safety and smoothing checks.

Diagnostic PNGs contain only generated artwork. Never save desktop capture buffers. Any future builds should preserve this boundary, correct local attribution and normal sleep behavior.
