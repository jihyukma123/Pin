import SwiftUI
import MarkdownUI
import PinCore

enum MessageCardMode {
    case preview
    case full
}

struct MessageCardView: View {
    let message: ParsedMessage
    let mode: MessageCardMode
    let isPinned: Bool
    let isExpanded: Bool
    var tintWhenPinned: Bool = true
    var bubble: Bool = false
    let onTogglePin: () -> Void
    let onToggleExpanded: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var justCopied: Bool = false
    @State private var hovering: Bool = false

    var body: some View {
        if bubble {
            bubbleBody
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: 0) {
            // Pin accent: 좌측 미니멀 바
            Rectangle()
                .fill(isPinned ? Color.pinHighlight : .clear)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                header
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        .textSelection(.enabled)
        .onHover { hovering = $0 }
    }

    private var bubbleBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isPinned ? Color.pinHighlight.opacity(0.5) : borderColor,
                              lineWidth: isPinned ? 1 : 0.5)
        )
        .textSelection(.enabled)
        .onHover { hovering = $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(roleColor)
                    .frame(width: 6, height: 6)
                Text(roleLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if message.kind == .assistantIntermediate {
                    Text("tool-call note")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Text(timeString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            actionButtons
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            if mode == .preview {
                iconButton(
                    system: isExpanded ? "chevron.up" : "chevron.down",
                    tint: .secondary,
                    help: isExpanded ? "Collapse" : "Expand",
                    action: onToggleExpanded
                )
            }
            iconButton(
                system: justCopied ? "checkmark" : "doc.on.doc",
                tint: justCopied ? .green : .secondary,
                help: justCopied ? "Copied" : "Copy",
                action: copyAll
            )
            iconButton(
                system: isPinned ? "pin.fill" : "pin",
                tint: isPinned ? Color.pinHighlight : .secondary,
                help: isPinned ? "Unpin" : "Pin",
                action: onTogglePin
            )
        }
        .opacity(hovering || isPinned || justCopied ? 1.0 : 0.55)
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private func iconButton(system: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Content

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
                    .font(.system(size: 13.5))
                    .foregroundStyle(.primary.opacity(0.86))
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .lineSpacing(2)
            }
        }
    }

    private var previewText: String {
        message.text
            .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(message.text, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            justCopied = false
        }
    }

    // MARK: - Style

    private var roleLabel: String {
        switch message.kind {
        case .userInput: return "User"
        case .assistantFinal, .assistantIntermediate:
            switch message.sourceTool {
            case .claudeCode: return "Claude"
            case .codex: return "Codex"
            case .gemini: return "Gemini"
            }
        }
    }

    private var roleColor: Color {
        switch message.kind {
        case .userInput: return .blue
        case .assistantFinal: return .purple
        case .assistantIntermediate: return .gray
        }
    }

    private var backgroundColor: Color {
        if isPinned && tintWhenPinned {
            return colorScheme == .dark
                ? Color.pinHighlight.opacity(0.12)
                : Color.pinHighlight.opacity(0.08)
        }
        if bubble {
            switch message.kind {
            case .userInput:
                return colorScheme == .dark
                    ? Color.blue.opacity(0.22)
                    : Color.blue.opacity(0.12)
            case .assistantFinal:
                return colorScheme == .dark
                    ? Color.white.opacity(0.06)
                    : Color(red: 0.93, green: 0.93, blue: 0.95)
            case .assistantIntermediate:
                return colorScheme == .dark
                    ? Color.white.opacity(0.03)
                    : Color(red: 0.96, green: 0.96, blue: 0.97)
            }
        }
        switch message.kind {
        case .userInput:
            return colorScheme == .dark
                ? Color.white.opacity(0.03)
                : Color(nsColor: .controlBackgroundColor)
        case .assistantFinal:
            return colorScheme == .dark
                ? Color.white.opacity(0.05)
                : Color(nsColor: .textBackgroundColor)
        case .assistantIntermediate:
            return colorScheme == .dark
                ? Color.white.opacity(0.02)
                : Color(nsColor: .windowBackgroundColor).opacity(0.5)
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }
}

extension Color {
    /// 핀 강조용 앰버. 시스템 액센트(빨강 등)에 흔들리지 않도록 고정 색.
    static let pinHighlight = Color(red: 0.851, green: 0.624, blue: 0.180)
}
