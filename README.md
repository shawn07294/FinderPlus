# FinderPlus

A native macOS file explorer built with Swift and SwiftUI, with scoped live search, list and icon views, Quick Look previews, drag and drop, and common file operations.

## v1.2.0M

- Generates rich thumbnails for the entire current folder when it is opened.
- Stores generated thumbnails in `/Applications/FinderPlus.app/Contents/PREVIEWS`.
- Reuses cached previews when available and regenerates them when they expire or no longer match the file metadata.
- Automatically removes preview files older than 3 days so they can be generated again when needed.
- Limits background thumbnail generation to four concurrent Quick Look jobs.

## Download and install

**For most users, download the app ZIP from the [FinderPlus Releases page](https://github.com/shawn07294/FinderPlus/releases).** Choose the latest macOS release and download the `FinderPlus-<version>-macOS-arm64.zip` asset.

1. Extract the ZIP file.
2. Move `FinderPlus.app` into your `/Applications` folder.
3. Open FinderPlus.

You do not need Swift, Xcode, Git, or the source code to use the prebuilt app. The app is currently built for Apple Silicon Macs (arm64) and requires macOS 14 or later.

The distributed app is not notarized by Apple, so macOS may show a security warning the first time you open it. Only install releases from this official repository.

## Source code and development

The source project is available in this repository and in the optional `FinderPlus-source.zip` archive. To build it yourself, use macOS 14 or later and Swift 5.9 or later (included with Xcode or the Xcode Command Line Tools):

```sh
swift run
```

To package a standalone app:

```sh
./bundle.sh
open build/FinderPlus.app
```

GitHub Actions builds the Apple Silicon app and attaches the ZIP to published releases automatically. You can also manually run the **Build macOS Release App** workflow from the Actions tab for an existing release tag.

FinderPlus is distributed under GPL-3.0; see [LICENSE](LICENSE).
