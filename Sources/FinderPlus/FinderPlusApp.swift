import SwiftUI
import AppKit

@main
struct FinderPlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "main-window") {
            MainContentView()
                .frame(minWidth: 700, minHeight: 450)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        WindowGroup(for: URL.self) { $url in
            MainContentView(initialDirectory: url ?? FileManager.default.homeDirectoryForCurrentUser)
                .frame(minWidth: 700, minHeight: 450)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            FileCommands()

            CommandMenu("View") {
                Button("Zoom In Icons") {
                    NotificationCenter.default.post(name: .increaseIconScaleTriggered, object: nil)
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out Icons") {
                    NotificationCenter.default.post(name: .decreaseIconScaleTriggered, object: nil)
                }
                .keyboardShortcut("-", modifiers: [.command])

                Divider()

                Button("Zoom In Menu & UI") {
                    NotificationCenter.default.post(name: .increaseAppScaleTriggered, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command])

                Button("Zoom Out Menu & UI") {
                    NotificationCenter.default.post(name: .decreaseAppScaleTriggered, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command])

                Divider()

                Button("Actual Size") {
                    NotificationCenter.default.post(name: .resetScalesTriggered, object: nil)
                }
                .keyboardShortcut("0", modifiers: [.command])
            }

            CommandMenu("Go") {
                Button("Back") {
                    NotificationCenter.default.post(name: .goBackTriggered, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Button("Forward") {
                    NotificationCenter.default.post(name: .goForwardTriggered, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Enclosing Folder") {
                    NotificationCenter.default.post(name: .goUpTriggered, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])

                Divider()

                Button("Home") {
                    NotificationCenter.default.post(name: .goToDirectory, object: FileManager.default.homeDirectoryForCurrentUser)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Applications") {
                    NotificationCenter.default.post(name: .goToDirectory, object: URL(fileURLWithPath: "/Applications"))
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("Desktop") {
                    NotificationCenter.default.post(name: .goToDirectory, object: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Documents") {
                    NotificationCenter.default.post(name: .goToDirectory, object: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"))
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Downloads") {
                    NotificationCenter.default.post(name: .goToDirectory, object: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }

            CommandMenu("Help") {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .toggleShortcutsSheetTriggered, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let goBackTriggered = Notification.Name("FinderPlus.goBack")
    static let goForwardTriggered = Notification.Name("FinderPlus.goForward")
    static let goUpTriggered = Notification.Name("FinderPlus.goUp")
    static let goToDirectory = Notification.Name("FinderPlus.goToDirectory")
    static let increaseIconScaleTriggered = Notification.Name("FinderPlus.increaseIconScale")
    static let decreaseIconScaleTriggered = Notification.Name("FinderPlus.decreaseIconScale")
    static let increaseAppScaleTriggered = Notification.Name("FinderPlus.increaseAppScale")
    static let decreaseAppScaleTriggered = Notification.Name("FinderPlus.decreaseAppScale")
    static let resetScalesTriggered = Notification.Name("FinderPlus.resetScales")
    static let toggleShortcutsSheetTriggered = Notification.Name("FinderPlus.toggleShortcutsSheet")
    static let moveToTrashTriggered = Notification.Name("FinderPlus.moveToTrash")
    static let previewThumbnailsDidUpdate = Notification.Name("FinderPlus.previewThumbnailsDidUpdate")
}

struct FileCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "main-window")
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Move to Trash") {
                NotificationCenter.default.post(name: .moveToTrashTriggered, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()

        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(openNewWindowAction), keyEquivalent: "")
        newWindowItem.target = self
        dockMenu.addItem(newWindowItem)
        dockMenu.addItem(NSMenuItem.separator())

        let eligibleWindows = NSApp.windows.filter { window in
            window.canBecomeKey && !window.isMiniaturized && window.isVisible && window.styleMask.contains(.titled)
        }

        if !eligibleWindows.isEmpty {
            let sectionHeader = NSMenuItem(title: "Open Windows", action: nil, keyEquivalent: "")
            sectionHeader.isEnabled = false
            dockMenu.addItem(sectionHeader)

            for window in eligibleWindows {
                let title = window.title.isEmpty ? "FinderPlus" : window.title
                let item = NSMenuItem(title: title, action: #selector(selectWindowAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = window
                if window == NSApp.keyWindow {
                    item.state = .on
                }
                dockMenu.addItem(item)
            }
        }

        return dockMenu
    }

    @objc private func openNewWindowAction() {
        NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
    }

    @objc private func selectWindowAction(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? NSWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
