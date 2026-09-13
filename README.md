# Foldable for Mac · 1.1.0

A native menu bar app that turns the MacBook lid into a live, physical animation control. Foldable combines an original dark interface and interactive Metal preview with live screen capture, hinge-driven perspective and progressive blur.

This is a local, ad-hoc-signed build. It is not notarized or affiliated with Apple. The illusion is a Mac interpretation; it is not Apple's proprietary animation or a lock-screen replacement.

[⬇ Download Foldable for Mac — v1.1.0](https://github.com/elhabreraphael-code/Foldable/releases/tag/v1.1.0)

## Open

Open **Foldable.app**, or drag it from the disk image into Applications. Click the laptop/angle in the menu bar to open Foldable. The effect starts off each launch.

1. Click **Allow screen access**, approve Foldable under System Settings → Privacy & Security → Screen & System Audio Recording. macOS may require quitting and reopening Foldable after approval.
2. Click **Enable Foldable**. Lower your lid gently below the start angle (110° by default).
3. Use **Fine-tune** to adjust the start angle, softness, smoothing and steadiness. Use current lid angle sets the starting point to your preferred viewing position.

**Control–Command–L** toggles the effect. Right-click the menu bar icon for quick controls and Quit. The preview uses original bundled artwork and needs no screen permission. Drag its slider, press Play, or enable Live hinge.

Open at login is optional and only registers when you select it. The app still starts with the effect off.

## Updating from an earlier version

1. Quit Foldable from its menu bar menu.
2. Open the new DMG, drag Foldable into Applications, and choose **Replace**. You do not need to delete the app first; existing preferences remain saved.
3. Open Foldable from Applications and enable the effect.

If **Enable Foldable** does nothing even though screen access appears allowed, macOS may still have approval for the older ad-hoc-signed build:

1. Quit Foldable.
2. Open **System Settings → Privacy & Security → Screen & System Audio Recording**.
3. Select Foldable and click **−** to remove the old entry.
4. Click **+**, select **/Applications/Foldable.app**, and enable its switch. Authenticate if macOS asks.
5. Reopen Foldable and enable the effect.

Select the installed app in Applications, not a copy on the DMG or an old test build. This refreshes approval for this build; macOS may require approval again for a future ad-hoc update.

## What changed in 1.1.0

- The last 10° before the start angle progressively flatten and fade the overlay into the actual desktop. The raw activation ceiling still applies, even with smoothing or jitter tolerance enabled.
- Reopening resumes at the current lid angle after a fresh post-wake frame, instead of easing from an old flat state into a fold. The first fresh frame fades in over 120 ms.
- Capture and output use matching sRGB color space, full backing resolution, and matching active frame cadence. Aligned rendering no longer darkens the screen’s boundary pixels.

macOS controls display wake and the lock screen. Foldable cannot draw while the Mac sleeps or over the secure lock screen. If the lid has already passed your start angle by the time the unlocked desktop is available, no folding effect is shown. This release improves the available opening portion; it does not replace the system wake animation or play a synthetic fold after a fast opening.

## Requirements and limits

- Apple silicon MacBook with a readable lid-angle sensor, macOS 13 or newer. The sensor interface is undocumented.
- Verified locally on an M3 MacBook Air: sensor reads, native UI, Metal pixel rendering and automated motion/display checks. MacBook Pro hardware and ProMotion performance require device testing; the 120 Hz setting is capped to the actual display maximum.
- Live capture starts at full cadence and runs at up to the selected 60/120 fps near the activation threshold, capped to the display refresh rate, reducing to 5 fps away from it. Capture uses the built-in display’s full backing resolution and explicitly matches the overlay’s sRGB color space. The overlay stops drawing when aligned. Gaussian blur textures use half resolution to reduce memory and GPU work.
- Only the built-in, unmirrored display is used. Capture pauses on lid-close, display sleep, lock, missing display or sensor failure. Normal macOS sleep remains in place. An enabled effect resumes after stable recovery and a fresh frame, aligned to a fresh lid reading. Wake recovery waits at least 150 ms of stable display/sensor availability; display topology changes retain the longer 500 ms check.
- Screen frames stay in local memory. No recording to disk, networking, audio capture, camera, Accessibility or Input Monitoring is used.
- Protected video may be blank. Capture is SDR. A fixed viewpoint is assumed; keep your head and laptop base still for the strongest illusion.
- This is a visual overlay: underlying click targets do not follow transformed pixels. Pause lid motion for precise clicks.

## Build from corresponding source

Requires Apple's Command Line Tools. No third-party dependencies.

```sh
./script/build_fold.sh release
open dist/Foldable.app
```

The SwiftPM executable target retains the upstream name `LidPlane`; the bundle executable remains named `Fold`. The bundle ID remains `app.fold.mac`, preserving existing settings and app identity. Permission normally persists for the installed build across launches and restarts. macOS controls authorization and may require it again after an app update, permission reset or system security change.

```sh
swift run LidPlaneChecks        # Motion, display lifecycle and easing checks
swift run LidPlane --probe      # Read-only hinge diagnostic
swift run LidPlane --preview    # Generated-artwork GPU checks; PNGs in dist/
```

To run the visible-window check, first quit Foldable and run `open -n -W dist/Foldable.app --args --window-check`. It briefly covers the built-in screen with generated artwork, tests hide/show, Retina presentation, click-through and the hotkey, and writes `dist/window-check.txt`. It never saves other applications' screen contents. Screen Recording permission may be required for pixel inspection on newer macOS.

Replacing an ad-hoc build can invalidate Screen Recording permission while the Settings switch still looks on. If this happens, quit Foldable, remove its old Screen Recording entry, then add the installed /Applications/Foldable.app and reopen it. Do not reset permissions for other apps.

The local bundle is ad-hoc signed. `FOLD_SIGN_IDENTITY` optionally specifies an existing signing identity when building; this script does not notarize. Do not disable Gatekeeper. If distributing publicly, obtain Developer ID signing/notarization and test on other hardware first.

## Attribution and source

Based on [Lid Plane](https://github.com/jh3y/lid-plane), Copyright (c) 2026 Jhey, GPL-3.0-or-later. The rendering, capture, sensor and lifecycle foundation comes from that project. Foldable adds its interface, procedural artwork/icon, settings/preview, time-based display-refresh smoothing, blur-memory optimization, adaptive capture rate and lock handling.

All changes are dated September 13, 2026. Preserve LICENSE and COPYRIGHT. The complete corresponding source accompanies this build in Foldable-1.1.0-source.zip. LICENSE-MIT is the historical upstream notice and does not apply to new GPL changes.
