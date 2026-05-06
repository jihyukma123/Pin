import SwiftUI
import PinCore

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct PinApp: App {
    @StateObject private var store = MessageStore()
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = false
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.system.rawValue

    private var appearance: Appearance {
        Appearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup("Pin") {
            AppView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 520)
                .task {
                    store.refreshSessions()
                }
                .background(WindowConfigurator(alwaysOnTop: alwaysOnTop))
                .preferredColorScheme(appearance.scheme)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Picker("Appearance", selection: $appearanceRaw) {
                                ForEach(Appearance.allCases) { a in
                                    Label(a.label, systemImage: a.icon).tag(a.rawValue)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Image(systemName: appearance.icon)
                        }
                        .help("Appearance: \(appearance.label)")
                    }
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
                Divider()
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(Appearance.allCases) { a in
                        Text(a.label).tag(a.rawValue)
                    }
                }
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
