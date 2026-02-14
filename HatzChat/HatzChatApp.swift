import SwiftUI

@main
struct HatzChatApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            AppMenuCommands(store: store)
        }
    }
}

private struct AppMenuCommands: Commands {
    let store: ChatStore

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Replace the system-provided New Window / New Item group
        // so we control the shortcuts cleanly.
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Chat") {
                store.newConversation()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Keep Settings shortcut as you had it
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                store.showSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
