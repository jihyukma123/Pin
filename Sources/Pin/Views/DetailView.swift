import SwiftUI
import PinCore

struct DetailView: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        VStack(spacing: 0) {
            if store.selectedSession == nil {
                ContentUnavailableView(
                    "Pick a session",
                    systemImage: "tray",
                    description: Text("좌측에서 도구와 세션을 선택해.")
                )
            } else {
                if !store.pinned.isEmpty {
                    PinnedSection()
                    Divider()
                }
                MessageListView()
            }
        }
    }
}
