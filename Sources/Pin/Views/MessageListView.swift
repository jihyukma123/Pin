import SwiftUI
import PinCore

struct MessageListView: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        VStack(spacing: 0) {
            intermediateToggleBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.visibleMessages) { msg in
                            MessageCardView(
                                message: msg,
                                mode: .preview,
                                isPinned: store.isPinned(msg.id),
                                isExpanded: store.isExpanded(msg.id),
                                onTogglePin: { store.togglePin(msg.id) },
                                onToggleExpanded: { store.toggleExpanded(msg.id) }
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: store.visibleMessages.count) { _, _ in
                    autoScroll(proxy: proxy)
                }
                .onChange(of: store.sortOrder) { _, _ in
                    autoScroll(proxy: proxy)
                }
            }
        }
    }

    private func autoScroll(proxy: ScrollViewProxy) {
        let target: ParsedMessage?
        switch store.sortOrder {
        case .newestFirst: target = store.visibleMessages.first
        case .oldestFirst: target = store.visibleMessages.last
        }
        guard let target else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(target.id, anchor: store.sortOrder == .newestFirst ? .top : .bottom)
        }
    }

    @ViewBuilder
    private var intermediateToggleBar: some View {
        if store.intermediateCount > 0 {
            HStack(spacing: 6) {
                Toggle(isOn: Binding(
                    get: { store.showIntermediate },
                    set: { store.showIntermediate = $0 }
                )) {
                    Text("Show intermediate (\(store.intermediateCount))")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            Divider()
        }
    }
}
