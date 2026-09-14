# Foldable 1.1.1 Final — build 5 validation

Verified locally September 14, 2026 on Apple M3 and macOS 27.0. Release-optimized Apple silicon binary; ad-hoc signed, not notarized. The public version remains 1.1.1 Final. Build 4 is retained in Archives/1.1.1 Final build 4.

## Scope

This revision fixes opening motion only, including the matching artwork preview. The old opening path capped the smoothed displacement to whole-degree raw sensor readings, bypassing the spring as the lid opened. The new path preserves the spring outside the handoff and reconstructs the boundary between display refreshes. Its short filter releases latency near the ceiling so the fold is flat before removal. Closing's established curve, raw activation visibility guard, fresh-frame wake alignment, capture policy, styles, settings, and shortcut behavior are preserved.

## Passed for build 5

- Debug `swift run LidPlaneChecks`: all existing motion, capture, safety, handoff, shortcut-model and anchor regressions pass.
- New opening regression: whole-degree samples held across two refreshes at 60 and 120 Hz, using Direct, Balanced and Silky response values. The rendered angle follows the continuous spring monotonically outside the handoff; discrete acceleration energy is below 25% of the previous raw-clamped trace in every tested configuration. This is a deterministic trajectory check, not a measured end-to-end frame-rate or subjective smoothness claim.
- Closing-curve equivalence across 1,000 sample positions. Opening traces at 15, 45, 90 and 180 degrees/second across 8, 15 and 22-degree handoffs remain finite, monotonic and fully transparent at the ceiling. Through 90 degrees/second, the largest final pre-cutoff displacement across these configurations is 0.056 degrees. Fresh-stream reset and invalid/above-ceiling boundary handling pass.
- Release `--preview`: V1 and V2 Metal rendering, distinct Origami projection, exact identity at zero, transparent and premultiplied output, and progressive edge blur all pass.
- Release `--window-check`: generated CVPixelBuffer presentation, visible pixels, 2× Retina scaling, 3420×2224 drawable, hide/show, no missing drawables, click-through/non-key overlay, slider dispatch and actual Carbon hotkey registration/rollback/recording checks all pass. Report: `shortcutChecks=true pixelBuffer=true visiblePixels=true onScreen=true attempts=30 missing=0 completed=29`.
- Release compilation, property-list lint, strict ad-hoc signature verification and diff whitespace checks pass.

Build 4's full five-page light/dark and compact settings snapshot review remains documented in the archived release; that unchanged interface was not re-snapshotted for this motion-only fix.

## Physical-device validation

The rebuilt app reported `permission=false` during the window check. Screen Recording permission was not requested, reset or modified. GPU tests use generated artwork; no desktop frames were saved.

Actual lid feel and a close → sleep → unlock → open cycle still require testing with the updated app authorized on the user's Mac. Synthetic 120 Hz traces do not establish hardware presentation performance or ScreenCaptureKit startup latency. Wake still requires a new capture and sensor sample; pre-sleep frames are never replayed. V2 remains Beta.
