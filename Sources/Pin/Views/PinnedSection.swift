import SwiftUI
import PinCore

struct PinnedFullView: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        if store.pinned.isEmpty {
            ContentUnavailableView(
                "고정된 메시지가 없습니다",
                systemImage: "pin.slash",
                description: Text("List 탭에서 메시지의 핀 아이콘을 눌러 고정해.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.pinned) { msg in
                        MessageCardView(
                            message: msg,
                            mode: .full,
                            isPinned: true,
                            isExpanded: false,
                            onTogglePin: { store.togglePin(msg.id) },
                            onToggleExpanded: {}
                        )
                    }
                }
                .padding(10)
            }
        }
    }
}
