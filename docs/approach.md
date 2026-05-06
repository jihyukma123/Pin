# 접근 방향 (Approach)

> `core-problem.md`의 페인 포인트를 어떻게 풀 것인가.

---

## 결정한 방향

**Sidecar(사이드카) — AI CLI 도구의 트랜스크립트 파일을 읽는 별도 앱**

CLI 도구(Claude Code, Codex CLI, Gemini CLI)는 모든 대화를 구조화된 파일(JSONL/JSON)로 디스크에 기록한다. 사이드카 앱은 이 파일들을 watch하고, 새 메시지가 추가되면 자체 UI에 카드로 띄운다. 사용자는 카드의 📌 버튼으로 응답을 고정하고, 고정된 카드는 항상 보이는 영역에 머문다.

```
[기존 터미널]                  [사이드카 앱]
claude code 평소처럼 사용      ┌──────────────────────┐
$ claude                       │ 📌 Pinned            │
> 질문                         │   (고정된 응답)      │
< 긴 응답 ...                  ├──────────────────────┤
> 후속 질문                    │ 최근 메시지          │
                               │ [응답] [📌]          │
                               └──────────────────────┘
                               ▲ 트랜스크립트 파일 watch
```

---

## 이 방향을 택한 이유

1. **복잡하지 않다.**
   - 터미널을 재구현하지 않는다 (PTY/ANSI 파싱 불필요).
   - 데이터가 이미 구조화된 JSON으로 저장되어 있어 파싱이 단순.
   - 기존 CLI 도구를 일절 건드리지 않으므로, 도구 업데이트로 깨질 위험이 작다.

2. **문제를 실제로 해결한다.**
   - 사용자의 핵심 페인 — "참조하고 싶은 응답이 후속 질문 때문에 스크롤에 묻힌다" — 을 정확히 겨냥.
   - 사이드카 화면은 메인 터미널과 독립이라, 본 대화 흐름을 유지하면서 참조 대상을 별도 영역에 고정 가능.
   - compact가 발생해도 디스크의 트랜스크립트는 원본을 보존하므로, 과거 응답에도 안정적으로 접근 가능.

---

## 형태

**macOS native 데스크톱 앱 (SwiftUI)**

- 셸/창/상태 관리: SwiftUI + 필요 시 AppKit 보강 (`NSWindow`로 always-on-top 등)
- 파일 watch: `FSEventStream` / `DispatchSource`
- 글로벌 단축키: `KeyboardShortcuts` (오픈소스)
- JSONL 파싱: `Codable` + 표준 라이브러리
- 마크다운 렌더링: `swift-markdown-ui` 우선, 한계 시 메시지 영역만 `WKWebView` 하이브리드

선택 이유:
- 창 배치(옆에 띄워두기, always-on-top, 모든 Space 표시 등)가 1급 시민
- FSEvents 기반 파일 watch가 가장 효율적
- 메모리/바이너리 사이즈 최소
- 한글 폰트·합자·시스템 폰트가 자동으로 자연스러움
- macOS 전용 사용 환경이라 크로스플랫폼 추상화의 비용을 낼 이유가 없음

---

## 검증된 사실

세 도구 모두 트랜스크립트를 구조화된 파일로 저장한다는 것을 실제로 확인:

| 도구 | 저장 위치 | 포맷 |
|---|---|---|
| Claude Code | `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl` | JSONL (append-only) |
| Codex CLI | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | JSONL (append-only) |
| Gemini CLI | `~/.gemini/tmp/<project-hash>/chats/session-*.json` | JSON (전체 재기록) |

---

## 비-목표 (Non-goals)

- 터미널 에뮬레이터를 만들지 않는다.
- 기존 CLI 도구를 래핑하거나 입력을 가로채지 않는다.
- 사이드카에서 CLI로 명령을 보내지 않는다 (단방향, 읽기 전용).
- AI 모델/API를 직접 호출하지 않는다.

핵심은 오직 — **이미 디스크에 있는 대화 데이터를 사용자가 더 잘 활용하게 하는 것.**
