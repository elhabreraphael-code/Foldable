# Distribution of Foldable 1.1.1 Final (build 5)

This local Apple silicon application is ad-hoc signed and has not been notarized. Packaging does not upload or publish a release, install signing identities, change permissions, or replace the everyday installed app.

Build using `./script/build_fold.sh release`. Verify the bundle and run the checks described in README.md. Package that exact bundle without recompiling:

```sh
./script/package_fold.sh '../Releases/1.1.1 Final'
```

Deliver `Foldable-1.1.1-Final-arm64.zip`, `Foldable-1.1.1-Final-arm64.dmg`, `Foldable-1.1.1-Final-source.zip`, and `SHA256SUMS.txt` together. The source archive includes all modified source, scripts, resources, LICENSE, COPYRIGHT, and historical LICENSE-MIT. It excludes build caches, Git internals, diagnostic images, and previous binaries. Matching source is provided at no additional charge under GPL-3.0-or-later.

The bundle ID is `app.fold.mac`; the runtime target remains `LidPlane`. Binary, source, metadata, and checksums must refer to the same version. See VALIDATION.md for actual local results and remaining physical-device checks. Do not interpret local tests or checksums as notarization, publisher authentication, or compatibility with every MacBook.

This revision retains CFBundleShortVersionString 1.1.1 and increments CFBundleVersion to 5. The earlier build 4 Final release is retained in Archives/1.1.1 Final build 4; build 3 remains in its original release folder. V2 Origami is Beta; Final refers to the app revision.
