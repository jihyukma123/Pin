import SwiftUI
import PinCore

struct PinnedFullView: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        if store.pinned.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "pin.slash")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("고정된 메시지가 없습니다")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("List 탭에서 메시지의 핀 아이콘을 눌러 고정하세요.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.pinned) { msg in
                        MessageCardView(
                            message: msg,
                            mode: .full,
                            isPinned: true,
                            isExpanded: false,
                            tintWhenPinned: false,
                            onTogglePin: { store.togglePin(msg.id) },
                            onToggleExpanded: {}
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }
}
