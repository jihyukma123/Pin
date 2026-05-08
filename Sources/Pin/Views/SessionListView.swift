import SwiftUI
import PinCore

struct SessionListView: View {
    @EnvironmentObject private var store: MessageStore

    var sessions: [SessionRef] {
        guard let tool = store.selectedTool else { return [] }
        return store.sessionsByTool[tool] ?? []
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if sessions.isEmpty {
                    emptyState
                } else {
                    ForEach(sessions) { ref in
                        SessionRow(
                            ref: ref,
                            isSelected: store.selectedSession?.id == ref.id,
                            onSelect: { store.openSession(ref) }
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            if let tool = store.selectedTool {
                Text("No sessions for \(tool.displayName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Select a tool")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct SessionRow: View {
    let ref: SessionRef
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ref.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let label = ref.projectLabel, !label.isEmpty {
                        Text(label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                    Text(relativeTime)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }

    private var backgroundFill: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.accentColor.opacity(0.22)
                : Color.accentColor.opacity(0.14)
        }
        if hovering {
            return colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.04)
        }
        return .clear
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: ref.lastModified, relativeTo: .now)
    }
}
