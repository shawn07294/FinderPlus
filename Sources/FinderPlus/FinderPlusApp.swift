import SwiftUI
import AppKit

@main
struct FinderPlusApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .frame(minWidth: 700, minHeight: 450)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    if let url = Bundle.main.executableURL {
                        Process.launchedProcess(launchPath: url.path, arguments: [])
                    }
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

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
}
