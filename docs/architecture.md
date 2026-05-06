# Architecture

> MVP 기준 사이드카 앱의 내부 구조.

## 레이어

```
┌──────────────────────────────────────────────────────────┐
│  UI Layer (SwiftUI)                                      │
│   - SourcesSidebar / SessionListView / DetailView        │
│   - MessageCardView (preview/full 모드)                  │
│   - PinnedSection (full 마크다운 렌더)                   │
└─────────────▲────────────────────────────────────────────┘
              │ ObservableObject (@Published)
┌─────────────┴────────────────────────────────────────────┐
│  MessageStore (@MainActor)                               │
│   - sessionsByTool, selectedTool, selectedSession        │
│   - messages, pinnedIds, expandedIds                     │
└─────────────▲────────────────────────────────────────────┘
              │
┌─────────────┴────────────────────────────────────────────┐
│  SessionWatcher (protocol)                               │
│   - JSONLLineSessionWatcher  (Claude Code, Codex)        │
│       · 한 줄 = 한 메시지, append-only tail              │
│   - GeminiFileSessionWatcher (Gemini)                    │
│       · 단일 JSON 변경 시 전체 재파싱                    │
└─────────────▲────────────────────────────────────────────┘
              │ ParsedMessage[]
┌─────────────┴────────────────────────────────────────────┐
│  Adapters (도구별)                                       │
│   - ClaudeCodeAdapter, CodexAdapter, GeminiAdapter       │
│     · 각자의 포맷 → 공통 ParsedMessage                   │
└─────────────▲────────────────────────────────────────────┘
              │
┌─────────────┴────────────────────────────────────────────┐
│  Locators (도구별)                                       │
│   - SessionDiscovery.list(for: tool) → [SessionRef]      │
│   - 각자의 디스크 경로 스캔 + title 추출                 │
└──────────────────────────────────────────────────────────┘
```

## 공통 데이터 모델

```swift
struct ParsedMessage: Identifiable, Equatable, Hashable {
    let id: String              // 도구별 고유 메시지 id
    let sessionId: String
    let role: Role              // .user | .assistant
    let text: String
    let timestamp: Date
    let sourceTool: SourceTool
}

struct SessionRef: Identifiable, Hashable {
    let id: String              // 세션 id
    let title: String           // ai-title / thread_name / summary / fallback first user msg
    let sourceTool: SourceTool
    let fileURL: URL
    let lastModified: Date
}

enum Role { case user, assistant }
enum SourceTool: CaseIterable { case claudeCode, codex, gemini }
```

`id`는 String — 도구마다 UUID 형식이 다를 수 있어 확장 대비. 메시지에 가능한 식별자가 없으면 어댑터가 fallback을 만든다.

## MVP 기능 범위 (v0.1.0)

- ✅ Claude Code / Codex / Gemini 세션 자동 탐색 (3-pane: 도구 / 세션 / 메시지)
- ✅ 메시지 카드 = preview (4줄 truncate) + expand 토글 + 📌 pin
- ✅ 핀하면 상단 Pinned 영역에 **전체 마크다운** 렌더
- ✅ JSONL append-only 도구 (Claude/Codex)는 incremental tail
- ✅ Gemini는 파일 변경 감지 시 전체 재파싱
- ✅ Always-on-top, 모든 Space 표시
- ✅ macOS .app 번들 빌드 (`bin/build-app.sh`)
- ❌ tool_use / thinking 표시 (post-MVP — 토글 옵션)
- ❌ 부분 텍스트 선택 핀 (post-MVP)
- ❌ 글로벌 단축키 (post-MVP)
- ❌ 코드 블록 syntax highlighting (post-MVP)

## 빌드 시스템

**Swift Package Manager 단독 (Xcode 프로젝트 X)** — 이유는 `history.md` "결정: 빌드 시스템" 항목 참조.

- `swift build` / `swift run` 으로 개발 사이클 회전
- 의존성: SPM 호환 라이브러리만 (`swift-markdown-ui`, `KeyboardShortcuts` 등)

## 파일 watch 전략

JSONL은 append-only. 효율적인 watch:

1. 파일 열고 `seek(toEnd)`로 현재 byte offset 저장
2. FSEventStream으로 파일 변경 이벤트 구독
3. 이벤트 발생 시: 저장된 offset부터 EOF까지 read → 새 줄만 추출
4. 각 줄을 Adapter에 넘김

세션이 바뀌면 (다른 파일이 가장 최근이 되면) Locator가 재결정 → 새 watcher.
