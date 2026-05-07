import SwiftUI
import PinCore

struct MessageListView: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        VStack(spacing: 0) {
            intermediateToggleBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.visibleMessages) { msg in
                            bubbleRow(for: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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

    @ViewBuilder
    private func bubbleRow(for msg: ParsedMessage) -> some View {
        let isUser = msg.kind == .userInput
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 40) }
            MessageCardView(
                message: msg,
                mode: .preview,
                isPinned: store.isPinned(msg.id),
                isExpanded: store.isExpanded(msg.id),
                bubble: true,
                onTogglePin: { store.togglePin(msg.id) },
                onToggleExpanded: { store.toggleExpanded(msg.id) }
            )
            .frame(maxWidth: 620, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
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
            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { store.showIntermediate },
                    set: { store.showIntermediate = $0 }
                )) {
                    HStack(spacing: 4) {
                        Text("Show tool-call notes")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(store.intermediateCount)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
