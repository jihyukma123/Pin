import SwiftUI
import PinCore

struct PinnedSection: View {
    @EnvironmentObject private var store: MessageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.tint)
                    .font(.caption)
                Text("Pinned (\(store.pinned.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
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
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 360)
        }
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }
}
