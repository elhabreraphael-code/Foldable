# Distribution of Foldable 1.0.0

This delivery contains a locally built, ad-hoc-signed Apple silicon application. It has not been notarized by Apple. There is no public release or website.

Build with `./script/build_fold.sh release`. Bundle LICENSE and COPYRIGHT before signing. Distribute the complete matching source alongside app binaries, under GPL-3.0-or-later; retain the historical LICENSE-MIT in source. The upstream runtime target remains LidPlane, and the app bundle identity is app.fold.mac.

The deliverable source archive excludes .build, .git, temporary diagnostic PNGs and prior upstream binaries. It includes all modified source, build scripts, resources, licenses and this documentation. Source is provided at no additional charge with the binary.

Public distribution should use an appropriate Developer ID signing identity, Apple's notarization workflow and real testing on the target MacBook Pro models. Local validation does not prove compatibility with all MacBooks or Gatekeeper acceptance of downloaded copies.
