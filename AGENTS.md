# Working on Fold

Standalone macOS SwiftPM menu bar app. Work from this directory using SwiftPM. No third-party dependencies.

## Commands

- Build without launching: `./script/build_fold.sh release`.
- Build and launch the bundle: `open dist/Fold.app`.
- Motion checks: `swift run LidPlaneChecks` (custom executable, not XCTest).
- Metal preview: `swift run LidPlane --preview`.
- Visible-pixel regression and hotkey dispatch: `open -n -W dist/Fold.app --args --window-check`. Briefly shows generated artwork and exits; tell the user before running it.
- Package without changing the everyday app: `./script/package_fold.sh`.
- Matching source is exported automatically by `script/package_fold.sh`.

## Preserve these behaviours

- Start off, as a menu bar app, without stealing focus.
- Keep the overlay click-through and non-key; normal input passes through.
- Keep sensing on an independent timer while the overlay is hidden.
- Set the Metal layer's `contentsScale` to the display backing scale when sizing it. Zero scale produces invisible content even when GPU commands succeed. Keep the visible-pixel regression check.
- Soften warped image coverage with the progressive blur; do not return a hard background colour outside UV bounds before blurring the boundary. Keep `RenderChecks` in the preview command: it verifies blur outside both side edges, tighter falloff near the hinge and blur-off behaviour.
- Retain capture buffers until GPU work completes; exclude this app from capture.
- Keep desktop frames in memory. No disk recording, networking, audio, camera, login service or broad input monitor without explicit authorization. Diagnostic PNGs must contain generated artwork only.
- Preserve ordinary lid-close sleep and graceful sensor/capture failure handling.
- Activation angle is an optional absolute ceiling, not movement from an anchor. Raw readings above it must always hide the effect. Angle mode uses a fixed threshold anchor; motion mode keeps auto-anchor.
- Default to activation-angle mode at 110° and 0° jitter tolerance; preserve explicitly saved preferences. Keep jitter tolerance separate. Compare against the last accepted reading so slow cumulative movement is not lost.
- Closed, unavailable, asleep or mirrored built-in displays must pause capture, never redirect it to an external monitor. Wait for stable recovery and fresh sensor readings before restarting. Cancel pending capture discovery when stopping.
- Register only the toggle hotkey. Report conflicts without adding Accessibility or Input Monitoring requirements.

## Shipping and permissions

- Preserve `Copyright (c) 2026 Jhey` and GPL-3.0-or-later notices. Bundle LICENSE and COPYRIGHT; include them and historical LICENSE-MIT in source exports. Publish matching Corresponding Source alongside GPL binaries. Do not relabel old MIT releases or imply those permissions were revoked. These instructions add no license terms.

- Read `README.md`, `DEVELOPMENT.md` and `DISTRIBUTION.md` before changing onboarding or packaging.
- Only distributable ZIPs/DMGs, `dist/SHA256SUMS.txt` and `dist/README.md` belong in Git. Exclude caches, loose bundles, screenshots and exported copies.
- Keep binary versions, download links, signatures and checksums consistent.
- Ad-hoc builds are experimental, not notarized. Never imply otherwise or advise disabling Gatekeeper.
- Rebuilding can invalidate Screen Recording approval. Avoid unnecessarily rebuilding the working bundle; permission repair requires authorization and must target only `app.fold.mac`.
- Do not create a public repo, change the source license, upload a release, change permissions or install signing identities without authorization.
- Report what was actually verified. Local tests do not establish compatibility with every MacBook or Gatekeeper acceptance of a downloaded app.
