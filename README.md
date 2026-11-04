# FinderPlus 🗂️

A native, Finder-inspired macOS 27 file explorer crafted in Swift and SwiftUI, featuring an enhanced, scoped search engine.

---

## Highlights & Features

### 🔍 Enhanced Search Experience
- **Default Scoped Search**: By default, search queries inspect **only the selected folder**, keeping results immediate, focused, and free from drive-wide noise.
- **Search Scope Selector**: Instantly switch scope with one click between:
  - **This Folder** (Selected directory only)
  - **Subfolders** (Selected directory + recursive subdirectories)
  - **This Mac** (User files & applications across the Mac)
- **Search Target**: Switch between **File Name** and **File Content** scanning.
- **Match Modes**: Support for **Contains**, **Exact Match**, and **Regular Expressions (Regex)**.
- **Precision Filters**:
  - **Kind**: Filter by All, Folders, Documents, Images, Audio, Movies, Code, or Archives.
  - **Date Modified**: Any Date, Today, Past 7 Days, Past 30 Days, or Past Year.
  - **File Size**: Any Size, < 1 MB, 1–100 MB, or > 100 MB.
- **Case Sensitivity & Hidden Files**: Independent toggles for case sensitivity (`Aa`) and hidden dotfiles (`eye`).
- **Zero-Dependency Live Engine**: Multi-threaded Swift Concurrency (`AsyncStream` + `TaskGroup`) direct filesystem crawler that never misses unindexed files, git repositories, or developer files.

### 🖥️ Authentic Finder Look & Feel
- **View Modes**:
  - **List View**: Sortable tabular columns (Name with system file icons, Date Modified, Size, Kind).
  - **Icon View**: Clean grid layout with system thumbnails and selection highlights.
- **Sidebar**:
  - **Favorites**: Quick access to Home, Desktop, Documents, Downloads, and Applications.
  - **Locations**: Quick access to Macintosh HD and connected Volumes.
- **Clickable Breadcrumb Path Bar**: Bottom path navigation showing every parent folder component with instant click-to-navigate.
- **Status Bar**: Live item counts, selection metrics, and available disk capacity.
- **Quick Look Integration**: Press **Spacebar** or choose Quick Look from the context menu to preview files natively.
- **Drag and Drop**:
  - Drag files or folders from FinderPlus into any folder, sidebar favorite, or external app.
  - Drop files or folders from native Finder, desktop, or other apps directly into FinderPlus.
  - Drop files directly onto any folder row/icon (with visual highlight) to move items inside it.
  - Drop files onto Sidebar favorites (Home, Documents, Downloads, etc.) to quickly organize files.
- **File Operations**:
  - Double-click to open in default macOS applications (`NSWorkspace`).
  - Right-click context menu: Open, Quick Look, Reveal in Finder, Duplicate, Copy Path, Rename, and Move to Trash.
  - New Folder button and keyboard shortcut.

---

## Requirements

- **macOS**: macOS 14.0+ (Tested & optimized for macOS 27)
- **Swift**: Swift 5.9+ / Swift 6.4

---

## Quick Start

### Running in Development Mode
```bash
cd /Users/shawnlee/.gemini/antigravity/scratch/FinderPlus
swift run
```

### Packaging into a Standalone `.app`
Run the bundling script to generate `build/FinderPlus.app`:
```bash
./bundle.sh
open ./build/FinderPlus.app
```

### Opening in Xcode
You can open the project directly in Xcode:
```bash
open FinderPlus.xcodeproj
```
Or double-click `FinderPlus.xcodeproj` in Finder. Press **⌘ + R** in Xcode to build and run!

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Space` | Quick Look preview for selected file |
| `⌘ + F` | Focus Search field & reveal filter shelf |
| `⌘ + +` / `⌘ + =` | **Increase scale of file icons** |
| `⌘ + -` | **Decrease scale of file icons** |
| `⌘ + ]` | **Increase scale of the app** |
| `⌘ + [` | **Decrease scale of the app** |
| `⌘ + 0` | Reset icon and app scale to 100% |
| `⌘ + ↑` | Navigate up to parent folder |
| `⌘ + ↓` | Open selected folder or launch file |
| `⌘ + ←` | Go Back in history |
| `⌘ + →` | Go Forward in history |
| `⌘ + ⇧ + N` | Create New Folder |
| `⌘ + ⇧ + H` | Go to Home directory |
| `⌘ + ⇧ + A` | Go to Applications |
| `⌘ + ⇧ + D` | Go to Desktop |
| `⌘ + ⇧ + O` | Go to Documents |
