import SwiftUI
import PinCore

@main
struct PinApp: App {
    @StateObject private var store = MessageStore()
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = false

    var body: some Scene {
        WindowGroup("Pin") {
            AppView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 520)
                .task {
                    store.refreshSessions()
                }
                .background(WindowConfigurator(alwaysOnTop: alwaysOnTop))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Toggle(isOn: $alwaysOnTop) {
                            Image(systemName: alwaysOnTop ? "pin.circle.fill" : "pin.circle")
                        }
                        .toggleStyle(.button)
                        .help(alwaysOnTop ? "Floating: window stays on top" : "Floating off: normal window behavior")
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Reload Sessions") {
                    store.refreshSessions()
                }
                .keyboardShortcut("r", modifiers: [.command])
                Toggle("Always on top", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}

/// alwaysOnTop 변경 시마다 NSWindow의 level / collectionBehavior 업데이트.
struct WindowConfigurator: NSViewRepresentable {
    let alwaysOnTop: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.level = alwaysOnTop ? .floating : .normal
            window.collectionBehavior = alwaysOnTop
                ? [.canJoinAllSpaces, .fullScreenAuxiliary]
                : [.fullScreenPrimary]
            window.titlebarAppearsTransparent = true
        }
    }
}
