import SwiftUI
import PinCore

struct AppView: View {
    @EnvironmentObject private var store: MessageStore
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            VStack(spacing: 0) {
                ToolSegmentedBar()
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                Divider()
                SessionListView()
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 260)
        } detail: {
            DetailView()
                .navigationTitle(store.selectedTool?.displayName ?? "Pin")
        }
        .navigationSplitViewStyle(.balanced)
        .background(
            // 메뉴 항목 없이도 ⌘B가 동작하도록 hidden 버튼.
            Button("Toggle Sidebar", action: toggleSidebar)
                .keyboardShortcut("b", modifiers: [.command])
                .hidden()
        )
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle session list (⌘B)")
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    store.refreshSessions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload sessions (⌘R)")
                .keyboardShortcut("r", modifiers: [.command])
            }
            ToolbarItem(placement: .principal) {
                Picker("Sort", selection: $store.sortOrder) {
                    ForEach(MessageSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(minWidth: 140)
                .help("Message sort order")
            }
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            sidebarVisibility = (sidebarVisibility == .detailOnly) ? .all : .detailOnly
        }
    }
}

/// 좁은 폭에서도 도구를 빠르게 전환할 수 있는 세그먼트 컨트롤.
/// 시스템 `.segmented` Picker는 macOS에서 높이/아이콘 크기를 강제로 작게 잡아 커스텀으로 구현.
struct ToolSegmentedBar: View {
    @EnvironmentObject private var store: MessageStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SourceTool.allCases) { tool in
                segmentButton(for: tool)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(trackFill)
        )
    }

    private func segmentButton(for tool: SourceTool) -> some View {
        let isSelected = store.selectedTool == tool
        return Button {
            store.selectTool(tool)
        } label: {
            ToolIcon(tool: tool)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? selectedFill : Color.clear)
                        .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 1, y: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText(for: tool))
    }

    private var trackFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.05)
    }

    private var selectedFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.white
    }

    private func helpText(for tool: SourceTool) -> String {
        let count = store.sessionsByTool[tool]?.count ?? 0
        return "\(tool.displayName) — \(count) session\(count == 1 ? "" : "s")"
    }
}

private struct ToolIcon: View {
    let tool: SourceTool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let nsImage = Self.image(for: tool) {
            Image(nsImage: nsImage)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(brandColor)
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: fallbackSymbol)
                .foregroundStyle(brandColor)
        }
    }

    /// Vendor 브랜드 컬러. 다크/라이트 모드별로 가독성 보정.
    private var brandColor: Color {
        switch tool {
        case .claudeCode:
            return Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0) // Claude/Anthropic 코랄
        case .codex:
            // OpenAI 마크는 흑백 — 라이트모드에선 어두운 회색, 다크모드에선 밝은 회색.
            return colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.10)
        case .gemini:
            return Color(red: 0x42 / 255.0, green: 0x85 / 255.0, blue: 0xF4 / 255.0) // Google blue
        }
    }

    private var fallbackSymbol: String {
        switch tool {
        case .claudeCode: return "terminal"
        case .codex: return "chevron.left.slash.chevron.right"
        case .gemini: return "sparkles"
        }
    }

    private static func image(for tool: SourceTool) -> NSImage? {
        let name: String = {
            switch tool {
            case .claudeCode: return "claude"
            case .codex: return "openai"
            case .gemini: return "gemini"
            }
        }()
        guard let url = Bundle.module.url(forResource: name, withExtension: "pdf", subdirectory: "Icons"),
              let img = NSImage(contentsOf: url) else {
            return nil
        }
        img.isTemplate = true
        return img
    }
}
