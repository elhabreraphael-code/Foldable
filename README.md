# Foldable for Mac · 1.1.1 Final

A native macOS menu bar app that turns your MacBook lid into a live animation control. Your desktop folds with the hinge, then gently flattens and dissolves back into the real screen as you open it.

Downlaod now: 
<p align="center">
  <a href="https://github.com/elhabreraphael-code/Foldable/releases/tag/V1.1.1">
    <img src="https://img.shields.io/badge/Download_for_Mac-V1.1.1_Final-007AFF?style=for-the-badge&logo=apple&logoColor=white&labelColor=111827" alt="Download Foldable for Mac" height="52">
  </a>
</p>

## Open

Open **Foldable.app**, or drag it from the disk image into Applications. Foldable starts quietly in the menu bar with the effect off. Click its icon or angle for quick settings, then choose **Open Foldable Settings…** for the full window.

1. Click **Allow screen access**, then approve Foldable in System Settings → Privacy & Security → Screen & System Audio Recording. macOS may require quitting and reopening after approval.
2. Click **Enable Foldable**. Gently lower the lid below the start angle (110° by default).
3. Choose **Motion** to try Direct, Balanced, or Silky, or fine-tune the start angle, smoothing, desktop handoff, steadiness, and blur.

**Control–Command–L** (default) toggles the effect. **Option-click** the menu bar item to toggle quickly; **click or right-click** for live sliders, animation styles, presets, capture settings, anchor controls, and Quit. Settings supports **Command–comma**, **Command–1…5** navigation, **Command–W**, and **Command–Q**. The interactive preview uses generated artwork and requires no screen permission.

## Opening refinement · 1.1.1 Final (build 5)

Opening now preserves the continuous spring between whole-degree hinge samples. A short, display-driven handoff filter softens the boundary, then sheds its delay as the desktop becomes flat. The raw activation cutoff and fresh-frame wake alignment remain in place. This revision only changes opening motion and its matching preview; existing features and preferences are preserved.

## Features in 1.1.1 Final

- **V1 · Classic** keeps the original continuous-plane fold. **V2 · Origami (Beta)** introduces three articulated panels that collapse toward the hinge, with adjustable depth and soft crease shading. Select either in Overview, Motion, the window toolbar, or the menu bar. Changes morph between the styles rather than jumping.
- **Flatten, then dissolve.** The final transition reduces geometric displacement before revealing the live desktop, avoiding a crossfade between two visibly displaced images. A quintic curve gives zero endpoint slope and curvature; a hinge boundary envelope flattens even a lagging spring. The configurable span remains 8–22°.
- The top-right Enable/Disable action has a full-width text label, alongside a separate quick-settings control. Native light/dark settings include five pages, compact layouts, keyboard navigation, and a quick-settings toolbar menu.
- **Custom toggle shortcut:** record two or more modifiers plus a letter, number, or Space. Try the recommendations or reset to Control–Command–L. Registration conflicts preserve the previous shortcut; Escape, focus loss, and leaving the recorder restore the existing registration. No Accessibility or Input Monitoring permission is used.
- **Menu-bar settings:** click the icon to adjust the start angle, smoothing, handoff, softness, prewarm, steadiness, Origami depth, style, presets, and refresh rate without opening the full window.
- **Pause for 10 minutes** stops capture and resumes automatically. Choose Resume Now to return sooner. Preview playback can loop; Reset restores the flat preview. Settled previews no longer redraw because unrelated dashboard counters changed.
- Capture prewarms 10–15° before activation (12° by default), then stops after opening 3° beyond the preparation zone for 650 ms. Screen frames remain in memory. Low Power Mode support and 60/120 Hz limits are preserved.


Existing saved preferences are preserved. New settings receive defaults. Opening at login remains opt-in, and never enables the effect automatically.

## Requirements and limits

- Apple silicon MacBook with a readable lid-angle sensor; macOS 13 or newer. The sensor interface is undocumented.
- 60 Hz or up to 120 Hz, capped to the built-in display's refresh capability. Capture and overlay share the selected cadence and sRGB color space. Capture uses full backing resolution; progressive blur uses half-resolution textures.
- Capture sleeps outside the preparation zone in activation-angle mode. Motion/auto-anchor mode keeps capture ready while enabled because it has no absolute activation threshold. Turning off both visual effects also pauses capture.
- Very fast lid movement can outrun capture startup. A 15° preparation zone gives more time but cannot guarantee startup latency on every Mac.
- Capture pauses on lid-close, display sleep, lock, missing/mirrored built-in display, or sensor failure. External monitors are never a fallback. Recovery waits for stable availability, a new sensor sample, and a fresh frame.
- Normal macOS lid-close sleep and the secure lock screen remain in place. If you open past the threshold before the unlocked desktop is available, no synthetic catch-up animation plays.
- Frames stay in local memory. No disk recording, networking, audio capture, camera, Accessibility, or Input Monitoring is used.
- Protected video may be blank. Capture is SDR. The illusion assumes a fixed viewpoint; keep your head and the laptop base still. Underlying click targets do not follow transformed pixels.

## Build and verify

Requires Apple's Command Line Tools. No third-party dependencies.

```sh
./script/build_fold.sh release
open dist/Foldable.app
swift run LidPlaneChecks
swift run LidPlane --probe
swift run LidPlane --preview
```

If moving an existing source checkout causes a stale module-cache error, run `swift package clean` before rebuilding.

The motion checks cover capture thresholds, teardown/hysteresis, reversals, refresh cadence, Low Power Mode, invalid input, raw-ceiling enforcement, and fresh-frame wake alignment. The Metal checks verify identity pixels, premultiplied alpha, and progressive edge blur using generated artwork only.

Quit other Foldable copies before the visible-window check:

```sh
open -n -W dist/Foldable.app --args --window-check
open -n -W dist/Foldable.app --args --dashboard-check
```

These briefly show generated artwork and synthetic settings states. They save only this app's test window, never other applications' screen contents. The dashboard check exercises light/dark appearance and compact layouts. Diagnostic PNGs/reports in `dist/` are excluded from source exports.

V2 is explicitly Beta. A real close → sleep → unlock → open test remains necessary to judge physical feel and wake timing on each target MacBook. Automated local checks do not establish 120 Hz performance or compatibility across all MacBooks. See `VALIDATION.md` for this build's actual results. “Final” names this local revision; it does not imply Apple certification or eliminate the Beta status of V2.

## Local distribution

The bundle identity remains `app.fold.mac`, the bundle executable `Fold`, and the SwiftPM target `LidPlane`. Preserve LICENSE and COPYRIGHT. Package the already-built app and matching source with:

```sh
./script/package_fold.sh '../Releases/1.1.1 Final'
```

This is a local ad-hoc-signed build, **not notarized**. Rebuilding can invalidate Screen Recording approval; macOS may require approving the new installed build again. Permission changes are never performed by the build scripts. Public distribution requires appropriate signing/notarization and hardware validation. Do not disable Gatekeeper.

## Attribution and source

Based on [Lid Plane](https://github.com/jh3y/lid-plane), Copyright (c) 2026 Jhey, GPL-3.0-or-later. Foldable is an independent derivative, not an Apple or official Lid Plane release.

Foldable changes are dated September 13–14, 2026. The matching Corresponding Source accompanies this release as `Foldable-1.1.1-Final-source.zip`, including build scripts, resources, LICENSE, COPYRIGHT, and the historical LICENSE-MIT notice. Historical MIT permissions remain unchanged.
