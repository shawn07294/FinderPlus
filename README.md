# FinderPlus

A native macOS file explorer built with Swift and SwiftUI, with scoped live search, list and icon views, Quick Look previews, drag and drop, and common file operations.

## Downloads

- [Prebuilt macOS app (Apple Silicon)](FinderPlus-macOS-arm64.zip)
- [Source project](FinderPlus-source.zip)

The prebuilt app is ad hoc signed and not notarized, so macOS may ask you to confirm opening it. It targets Apple Silicon (arm64). The source project can be built for Intel or Apple Silicon.

## Build

Requires macOS 14 or later and Swift 5.9 or later (included with Xcode or the Xcode Command Line Tools). Download and extract `FinderPlus-source.zip`, then run:

```sh
swift run
```

To package a standalone app:

```sh
./bundle.sh
open build/FinderPlus.app
```

See the source archive's README for features and keyboard shortcuts. FinderPlus is distributed under GPL-3.0; see [LICENSE](LICENSE).
