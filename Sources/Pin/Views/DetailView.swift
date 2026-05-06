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
                Group {
                    switch tab {
                    case .pinned: PinnedFullView()
                    case .list: MessageListView()
                    }
                }
            }
        }
        .onChange(of: store.selectedSession?.id) { _, _ in
            tab = .list
        }
        .background(shortcutHooks)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Pinned",
                count: store.pinned.count,
                isActive: tab == .pinned
            ) { tab = .pinned }

            TabButton(
                title: "List",
                count: nil,
                isActive: tab == .list
            ) { tab = .list }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
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

private struct TabButton: View {
    let title: String
    let count: Int?
    let isActive: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.08))
                            )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)

                Rectangle()
                    .fill(isActive ? Color.accentColor : .clear)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .background(
                hovering && !isActive
                    ? Color.primary.opacity(0.04)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
}
