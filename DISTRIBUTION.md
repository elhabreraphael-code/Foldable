# Distribution of Foldable 1.1.0

This delivery contains a locally built, ad-hoc-signed Apple silicon application. It has not been notarized by Apple. These files are ready for a separate v1.1.0 release; this packaging step does not upload them.

Build with `./script/build_fold.sh release`. Bundle LICENSE and COPYRIGHT before signing. Distribute the complete matching source alongside app binaries, under GPL-3.0-or-later; retain the historical LICENSE-MIT in source. The upstream runtime target remains LidPlane, and the app bundle identity is app.fold.mac.

The deliverable source archive excludes .build, .git, temporary diagnostic PNGs and prior upstream binaries. It includes all modified source, build scripts, resources, licenses and this documentation. Source is provided at no additional charge with the binary.

Public distribution should use an appropriate Developer ID signing identity, Apple's notarization workflow and real testing on the target MacBook Pro models. Local validation does not prove compatibility with all MacBooks or Gatekeeper acceptance of downloaded copies.

Version 1.1.0 includes the transparent desktop handoff and fresh-frame wake alignment. Local motion/safety tests and generated-artwork GPU checks cover the new behavior. A physical close → sleep → unlock → open check is still needed to assess wake timing on each target Mac.
