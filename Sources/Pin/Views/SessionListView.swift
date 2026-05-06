import SwiftUI
import PinCore

struct SessionListView: View {
    @EnvironmentObject private var store: MessageStore

    var sessions: [SessionRef] {
        guard let tool = store.selectedTool else { return [] }
        return store.sessionsByTool[tool] ?? []
    }

    var body: some View {
        List(selection: Binding<SessionRef?>(
            get: { store.selectedSession },
            set: { ref in if let ref { store.openSession(ref) } }
        )) {
            if sessions.isEmpty {
                emptyState
            } else {
                ForEach(sessions) { ref in
                    SessionRow(ref: ref)
                        .tag(ref)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(store.selectedTool?.displayName ?? "Sessions")
    }

    @ViewBuilder
    private var emptyState: some View {
        if let tool = store.selectedTool {
            Text("No sessions for \(tool.displayName)")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            Text("Select a tool")
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

struct SessionRow: View {
    let ref: SessionRef

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ref.title)
                .font(.system(.body, design: .default))
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(relativeTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(String(ref.id.prefix(8)))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: ref.lastModified, relativeTo: .now)
    }
}
