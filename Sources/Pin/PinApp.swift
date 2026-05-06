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
