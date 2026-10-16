# FinderPlus source project

FinderPlus is a native macOS file explorer built with Swift and SwiftUI.

## Requirements

- macOS 14 or later
- Swift 5.9 or later, included with Xcode or the Xcode Command Line Tools

## Run and package

```sh
swift run
```

To create a standalone app bundle in `build/FinderPlus.app`:

```sh
./bundle.sh
open build/FinderPlus.app
```

## Features

- Search the selected folder, its subfolders, or user files across the Mac.
- Search file names or file contents with contains, exact-match, or regular-expression matching.
- Filter by kind, modification date, and size; optionally include hidden files or match case.
- Switch between sortable list and icon views.
- Browse Home, Desktop, Documents, Downloads, Applications, Macintosh HD, and mounted volumes.
- Preview with Quick Look, navigate with breadcrumbs, and drag and drop files.
- Open, reveal, duplicate, rename, copy paths, move to Trash, and create folders.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Space | Quick Look preview for selected file |
| ⌘ F | Focus search and reveal filters |
| ⌘ ↑ | Go to parent folder |
| ⌘ ↓ | Open selected folder or file |
| ⌘ ⇧ N | Create a folder |
| ⌘ [ / ⌘ ] | Back / forward |
| ⌘ ⇧ H | Go to Home |
| ⌘ ⇧ A | Go to Applications |
| ⌘ ⇧ D | Go to Desktop |
| ⌘ ⇧ O | Go to Documents |

## License

GNU General Public License v3.0. See `LICENSE` in the repository.
