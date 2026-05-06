import SwiftUI
import PinCore

struct AppView: View {
    @EnvironmentObject private var store: MessageStore
    @State private var sourceColumn: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $sourceColumn) {
            SourcesSidebar()
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } content: {
            SessionListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.refreshSessions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload sessions (⌘R)")
                .keyboardShortcut("r", modifiers: [.command])
            }
            ToolbarItem(placement: .principal) {
                Picker("Sort", selection: $store.sortOrder) {
                    ForEach(MessageSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .help("Message sort order")
            }
        }
    }
}

struct SourcesSidebar: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedTool },
            set: { tool in if let tool { store.selectTool(tool) } }
        )) {
            Section("Tools") {
                ForEach(SourceTool.allCases) { tool in
                    HStack {
                        Image(systemName: iconName(for: tool))
                            .foregroundStyle(color(for: tool))
                        Text(tool.displayName)
                        Spacer()
                        Text("\(store.sessionsByTool[tool]?.count ?? 0)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(tool)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func iconName(for tool: SourceTool) -> String {
        switch tool {
        case .claudeCode: return "terminal"
        case .codex: return "chevron.left.slash.chevron.right"
        case .gemini: return "sparkles"
        }
    }

    private func color(for tool: SourceTool) -> Color {
        switch tool {
        case .claudeCode: return .orange
        case .codex: return .green
        case .gemini: return .blue
        }
    }
}
