import SwiftUI

public struct ShortcutItem: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var category: String
    public var key: String
    public var modifiers: [String] // "cmd", "shift", "opt", "ctrl"
    public var defaultKey: String
    public var defaultModifiers: [String]

    public var displaySymbols: [String] {
        var syms: [String] = []
        if modifiers.contains("ctrl") { syms.append("⌃") }
        if modifiers.contains("opt") { syms.append("⌥") }
        if modifiers.contains("shift") { syms.append("⇧") }
        if modifiers.contains("cmd") { syms.append("⌘") }
        
        switch key.lowercased() {
        case "space": syms.append("Space")
        case "leftarrow", "left": syms.append("←")
        case "rightarrow", "right": syms.append("→")
        case "uparrow", "up": syms.append("↑")
        case "downarrow", "down": syms.append("↓")
        case "return", "enter": syms.append("↩")
        case "delete", "backspace": syms.append("⌫")
        default: syms.append(key.uppercased())
        }
        return syms
    }
}

@MainActor
public final class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()
    private let defaultsKey = "FinderPlus.CustomShortcuts"

    @Published public var shortcuts: [ShortcutItem] = []

    public init() {
        loadShortcuts()
    }

    public static let defaultItems: [ShortcutItem] = [
        // Navigation
        ShortcutItem(id: "historyBack", title: "Back in History", category: "Navigation", key: "left", modifiers: ["cmd"], defaultKey: "left", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "historyForward", title: "Forward in History", category: "Navigation", key: "right", modifiers: ["cmd"], defaultKey: "right", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "parentFolder", title: "Enclosing Folder (Up)", category: "Navigation", key: "up", modifiers: ["cmd"], defaultKey: "up", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "openItem", title: "Open Selected Item", category: "Navigation", key: "down", modifiers: ["cmd"], defaultKey: "down", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "goHome", title: "Go to Home Folder", category: "Navigation", key: "h", modifiers: ["cmd", "shift"], defaultKey: "h", defaultModifiers: ["cmd", "shift"]),
        ShortcutItem(id: "goApplications", title: "Go to Applications", category: "Navigation", key: "a", modifiers: ["cmd", "shift"], defaultKey: "a", defaultModifiers: ["cmd", "shift"]),
        ShortcutItem(id: "goDesktop", title: "Go to Desktop", category: "Navigation", key: "d", modifiers: ["cmd", "shift"], defaultKey: "d", defaultModifiers: ["cmd", "shift"]),
        ShortcutItem(id: "goDocuments", title: "Go to Documents", category: "Navigation", key: "o", modifiers: ["cmd", "shift"], defaultKey: "o", defaultModifiers: ["cmd", "shift"]),
        ShortcutItem(id: "goDownloads", title: "Go to Downloads", category: "Navigation", key: "l", modifiers: ["cmd", "opt"], defaultKey: "l", defaultModifiers: ["cmd", "opt"]),

        // Zoom & Scaling
        ShortcutItem(id: "zoomInIcons", title: "Zoom In File Icons", category: "View & Scaling", key: "+", modifiers: ["cmd"], defaultKey: "+", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "zoomOutIcons", title: "Zoom Out File Icons", category: "View & Scaling", key: "-", modifiers: ["cmd"], defaultKey: "-", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "zoomInApp", title: "Zoom In Menu & UI Scale", category: "View & Scaling", key: "]", modifiers: ["cmd"], defaultKey: "]", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "zoomOutApp", title: "Zoom Out Menu & UI Scale", category: "View & Scaling", key: "[", modifiers: ["cmd"], defaultKey: "[", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "resetScales", title: "Actual Size (Reset Zoom)", category: "View & Scaling", key: "0", modifiers: ["cmd"], defaultKey: "0", defaultModifiers: ["cmd"]),

        // Actions & Tools
        ShortcutItem(id: "search", title: "Focus Search & Filters", category: "Actions", key: "f", modifiers: ["cmd"], defaultKey: "f", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "quickLook", title: "Quick Look Preview", category: "Actions", key: "space", modifiers: [], defaultKey: "space", defaultModifiers: []),
        ShortcutItem(id: "newFolder", title: "New Folder", category: "Actions", key: "n", modifiers: ["cmd", "shift"], defaultKey: "n", defaultModifiers: ["cmd", "shift"]),
        ShortcutItem(id: "newWindow", title: "New Window", category: "Actions", key: "n", modifiers: ["cmd"], defaultKey: "n", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "moveToTrash", title: "Move to Trash", category: "Actions", key: "delete", modifiers: ["cmd"], defaultKey: "delete", defaultModifiers: ["cmd"]),
        ShortcutItem(id: "shortcutsHelp", title: "Keyboard Shortcuts List", category: "Actions", key: "/", modifiers: ["cmd"], defaultKey: "/", defaultModifiers: ["cmd"])
    ]

    public func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([ShortcutItem].self, from: data) {
            // Merge with defaults to guarantee all IDs exist
            var merged = Self.defaultItems
            for item in saved {
                if let idx = merged.firstIndex(where: { $0.id == item.id }) {
                    merged[idx].key = item.key
                    merged[idx].modifiers = item.modifiers
                }
            }
            self.shortcuts = merged
        } else {
            self.shortcuts = Self.defaultItems
        }
    }

    public func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    public func updateShortcut(id: String, newKey: String, newModifiers: [String]) {
        if let idx = shortcuts.firstIndex(where: { $0.id == id }) {
            shortcuts[idx].key = newKey
            shortcuts[idx].modifiers = newModifiers
            saveShortcuts()
        }
    }

    public func resetToDefaults() {
        self.shortcuts = Self.defaultItems
        saveShortcuts()
    }
}

public struct KeyboardShortcutsSheet: View {
    @ObservedObject var shortcutManager = ShortcutManager.shared
    @Binding var isPresented: Bool
    @State private var filterQuery: String = ""
    @State private var selectedShortcutID: String? = nil
    @State private var editingKey: String = ""
    @State private var editingModifiers: [String] = ["cmd"]
    @State private var isEditingModalOpen: Bool = false

    private var categories: [String] {
        Array(Set(shortcutManager.shortcuts.map { $0.category })).sorted()
    }

    private func filteredItems(for category: String) -> [ShortcutItem] {
        let items = shortcutManager.shortcuts.filter { $0.category == category }
        if filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(filterQuery) ||
            $0.key.localizedCaseInsensitiveContains(filterQuery)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.title2.bold())
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                    Text("View and customize keybindings for FinderPlus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Search Filter Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter shortcuts...", text: $filterQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 140)
                    if !filterQuery.isEmpty {
                        Button(action: { filterQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                Button("Reset Defaults") {
                    shortcutManager.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Shortcuts Table
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(categories, id: \.self) { cat in
                        let items = filteredItems(for: cat)
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(cat)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 1) {
                                    ForEach(items) { item in
                                        HStack {
                                            Text(item.title)
                                                .font(.system(size: 13))

                                            Spacer()

                                            // Visual Key Badge
                                            HStack(spacing: 4) {
                                                ForEach(Array(item.displaySymbols.enumerated()), id: \.offset) { _, sym in
                                                    Text(sym)
                                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Color(NSColor.controlBackgroundColor))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 4)
                                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                                        )
                                                        .cornerRadius(4)
                                                }
                                            }

                                            // Change / Rebind Button
                                            Button("Change") {
                                                selectedShortcutID = item.id
                                                editingKey = item.key
                                                editingModifiers = item.modifiers
                                                isEditingModalOpen = true
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                            .padding(.leading, 8)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 480)
        .sheet(isPresented: $isEditingModalOpen) {
            if let id = selectedShortcutID, let item = shortcutManager.shortcuts.first(where: { $0.id == id }) {
                EditShortcutView(
                    item: item,
                    editingKey: $editingKey,
                    editingModifiers: $editingModifiers,
                    onSave: {
                        shortcutManager.updateShortcut(id: id, newKey: editingKey, newModifiers: editingModifiers)
                        isEditingModalOpen = false
                    },
                    onCancel: {
                        isEditingModalOpen = false
                    }
                )
            }
        }
    }
}

private struct EditShortcutView: View {
    let item: ShortcutItem
    @Binding var editingKey: String
    @Binding var editingModifiers: [String]
    let onSave: () -> Void
    let onCancel: () -> Void

    private let availableKeys = [
        "+", "-", "[", "]", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "/", "space", "left", "right", "up", "down", "return", "delete"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Customize Shortcut")
                .font(.headline)

            Text("Action: \(item.title)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Select Modifiers:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    modifierToggle(name: "⌘ Command", id: "cmd")
                    modifierToggle(name: "⇧ Shift", id: "shift")
                    modifierToggle(name: "⌥ Option", id: "opt")
                    modifierToggle(name: "⌃ Control", id: "ctrl")
                }

                Divider()

                Text("Select Key:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Picker("Key", selection: $editingKey) {
                    ForEach(availableKeys, id: \.self) { k in
                        Text(keyLabel(k)).tag(k.lowercased())
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Button("Reset to Default") {
                    editingKey = item.defaultKey
                    editingModifiers = item.defaultModifiers
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button("Save Shortcut", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func modifierToggle(name: String, id: String) -> some View {
        let isSelected = editingModifiers.contains(id)
        return Button(action: {
            if isSelected {
                editingModifiers.removeAll { $0 == id }
            } else {
                editingModifiers.append(id)
            }
        }) {
            Text(name)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func keyLabel(_ k: String) -> String {
        switch k.lowercased() {
        case "space": return "Spacebar"
        case "left": return "Left Arrow (←)"
        case "right": return "Right Arrow (→)"
        case "up": return "Up Arrow (↑)"
        case "down": return "Down Arrow (↓)"
        case "return": return "Return / Enter (↩)"
        case "delete", "backspace": return "Delete / Backspace (⌫)"
        default: return k
        }
    }
}
