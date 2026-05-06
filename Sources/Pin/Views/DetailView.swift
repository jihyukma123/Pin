import SwiftUI
import PinCore

enum SessionTab: Hashable {
    case pinned
    case list
}

struct DetailView: View {
    @EnvironmentObject private var store: MessageStore
    @State private var tab: SessionTab = .list

    var body: some View {
        VStack(spacing: 0) {
            if store.selectedSession == nil {
                ContentUnavailableView(
                    "Pick a session",
                    systemImage: "tray",
                    description: Text("좌측에서 도구와 세션을 선택해.")
                )
            } else {
                tabBar
                Divider()
                switch tab {
                case .pinned:
                    PinnedFullView()
                case .list:
                    MessageListView()
                }
            }
        }
        .onChange(of: store.selectedSession?.id) { _, _ in
            tab = .list
        }
        .background(shortcutHooks)
    }

    private var tabBar: some View {
        Picker("", selection: $tab) {
            Text("Pinned (\(store.pinned.count))").tag(SessionTab.pinned)
            Text("List").tag(SessionTab.list)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: 320)
    }

    private var shortcutHooks: some View {
        ZStack {
            Button("Pinned tab") { tab = .pinned }
                .keyboardShortcut("1", modifiers: .command)
            Button("List tab") { tab = .list }
                .keyboardShortcut("2", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
