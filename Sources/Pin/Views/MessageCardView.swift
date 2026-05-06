import SwiftUI
import MarkdownUI
import PinCore

enum MessageCardMode {
    case preview      // 짧은 미리보기 (4줄). expand 토글 가능.
    case full         // 핀된 카드. 전체 마크다운 렌더.
}

struct MessageCardView: View {
    let message: ParsedMessage
    let mode: MessageCardMode
    let isPinned: Bool
    let isExpanded: Bool
    let onTogglePin: () -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                roleBadge
                Spacer()
                Text(timeString)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                if mode == .preview {
                    Button(action: onToggleExpanded) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help(isExpanded ? "Collapse" : "Expand")
                }
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(isPinned ? "Unpin" : "Pin")
            }

            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isPinned ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .full:
            Markdown(message.text)
                .markdownTextStyle(\.text) { FontSize(15) }
                .textSelection(.enabled)
        case .preview:
            if isExpanded {
                Markdown(message.text)
                    .markdownTextStyle(\.text) { FontSize(15) }
                    .textSelection(.enabled)
            } else {
                Text(previewText)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
            }
        }
    }

    private var previewText: String {
        let cleaned = message.text
            .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    @ViewBuilder
    private var roleBadge: some View {
        let label: String = {
            switch message.kind {
            case .userInput: return "USER"
            case .assistantFinal: return "AI"
            case .assistantIntermediate: return "AI · intermediate"
            }
        }()
        let color: Color = {
            switch message.kind {
            case .userInput: return .blue
            case .assistantFinal: return .purple
            case .assistantIntermediate: return .secondary
            }
        }()
        Text(label)
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .foregroundStyle(color)
    }

    private var backgroundColor: Color {
        switch message.kind {
        case .userInput:
            return Color(nsColor: .controlBackgroundColor).opacity(0.6)
        case .assistantFinal:
            return Color(nsColor: .textBackgroundColor)
        case .assistantIntermediate:
            return Color(nsColor: .underPageBackgroundColor).opacity(0.4)
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: message.timestamp)
    }
}
