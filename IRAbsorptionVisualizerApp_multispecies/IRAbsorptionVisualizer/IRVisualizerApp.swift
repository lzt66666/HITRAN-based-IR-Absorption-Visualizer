import SwiftUI



struct SaveActionKey: FocusedValueKey { typealias Value = () -> Void }
struct HelpActionKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var saveAction: (() -> Void)? {
        get { self[SaveActionKey.self] }
        set { self[SaveActionKey.self] = newValue }
    }
    var helpAction: (() -> Void)? {
        get { self[HelpActionKey.self] }
        set { self[HelpActionKey.self] = newValue }
    }
}

@main
struct IRVisualizerApp: App {
    @FocusedValue(\.saveAction) private var saveAction
    @FocusedValue(\.helpAction) private var helpAction

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .saveItem) {
                if let save = saveAction {
                    Button("Save figure data as...", action: save)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            CommandGroup(after: .help) {
                if let help = helpAction {
                    Button("Help", action: help)
                }
            }
        }
    }
}
