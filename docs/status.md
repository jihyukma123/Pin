# Status

> 직전 세션의 작업 상태 스냅샷. **새 세션은 이 파일 하나로 "이전에 어디까지 했고, 미완 작업이 남아있는지"를 판단한다.**
>
> 단일 스냅샷이며 로그가 아님 — 매 세션 종료 시 **전체 덮어쓰기**.

---

## 한 줄 상태

- **State**: 🟡 in_progress (v0.1.3 — 메시지 정렬 + 첫 git commits)
- **Last session**: 2026-05-06 (autonomous, 네 번째 사이클)
- **Next action**: `~/Applications/Pin.app` 재실행 → 확인:
  1. 기본으로 최신 메시지가 맨 위에 오는지 (newest-first)
  2. 툴바 가운데 정렬 Picker로 oldest-first로 바꿨을 때 자연스러운지
  3. 정렬 바꾸면 자동 스크롤 동작 (위/아래)이 기대대로인지
  4. 다음 실행 시 마지막 정렬 선택이 유지되는지
  + v0.1.2 폰트 / always-on-top 토글, v0.1.1 intermediate 숨김 등 이전 검증 항목들도 같이 점검

> State 값: 🟢 `idle` (보류 항목 없음, 새로 시작 가능) / 🟡 `in_progress` (작업 중) / 🔴 `blocked` (사용자 입력·외부 요인 대기)

---

## 직전 세션 요약

**목표**: 사용자 첫 피드백 3가지 반영.
1. macOS .app 형식 실행 (단, GitHub pull 호환)
2. Claude Code / Codex / Gemini 모두 탐색 → 도구 선택 → 세션 목록 → 메시지 핀
3. 메시지 카드는 preview, 핀하면 전체

**v0.1.3 추가 작업 (이번 사이클의 마지막):**
- `MessageSortOrder` enum (newest/oldest first)
- Store에 `sortOrder` `@Published` + UserDefaults 영속
- `visibleMessages` / `pinned` 둘 다 정렬 적용
- 툴바 정렬 Picker (메뉴 스타일)
- ScrollViewReader 자동 스크롤이 정렬 따라가도록 변경
- `MessageStoreTests` 신설 — 정렬/필터/핀 상호작용 6개 → 총 **31개 통과**
- `_injectMessagesForTesting` 테스트 시em 추가
- **첫 git commits** — 의미 단위로 분할

**v0.1.2 추가 작업:**
- 카드 폰트 사이즈 12 → 14 (preview), 13 → 15 (마크다운)
- `@AppStorage("alwaysOnTop")` 토글 — 기본 OFF (= 일반 윈도우 level)
- 툴바 핀 아이콘 토글 (`pin.circle.fill`/`pin.circle`)
- View 메뉴에 "Always on top" + 단축키 ⌘⇧T
- `WindowConfigurator` (NSViewRepresentable) — 토글 변경 시 `window.level` + `collectionBehavior` 즉시 갱신
- `~/Applications/Pin.app`에 재설치

**v0.1.1 추가 작업:**
- `MessageKind` enum (`userInput` / `assistantFinal` / `assistantIntermediate`) — `ParsedMessage`에 추가
- 어댑터 3개에서 kind 산출:
  - Claude Code: `message.stop_reason == "tool_use"` → intermediate
  - Gemini: `toolCalls` 비어있지 않음 → intermediate
  - Codex: 모두 final (stateful tracking이 필요해서 TODO)
- 실데이터로 검증: 사용자의 모든 Claude 트랜스크립트 중 intermediate가 **49.4%**
- Store: `showIntermediate: Bool` (기본 false), `visibleMessages` 계산 — 핀된 intermediate는 토글과 무관하게 항상 보임
- UI: 메시지 리스트 상단 "Show intermediate (n)" 토글바 (intermediate 0이면 숨김), 카드 시각 구분 (옅은 배경 + "AI · intermediate" 뱃지)
- 테스트 4개 추가 — 총 **25개 통과**

**v0.1.0 완료한 일:**
- **데이터 모델 확장** — `SourceTool`에 codex/gemini 추가. `SessionRef` 신설. `ParsedMessage` id를 String화.
- **3개 어댑터 완성** — `ClaudeCodeAdapter`, `CodexAdapter`, `GeminiAdapter`.
- **3개 로케이터 완성** — 각 도구의 디스크 경로 스캔 + 제목 추출 (ai-title / thread_name / summary / fallback first user msg).
- **Watcher 추상화** — `SessionWatcher` protocol + 두 구현 (`JSONLLineSessionWatcher`, `GeminiFileSessionWatcher`).
- **MessageStore 재설계** — `sessionsByTool`, `selectedTool`, `selectedSession`, `expandedIds` 추가.
- **3-pane UI** — `NavigationSplitView` (SourcesSidebar / SessionListView / DetailView).
- **MessageCardView 모드 분리** — `.preview` (4줄 truncate + expand 토글) / `.full` (마크다운 풀 렌더).
- **`bin/build-app.sh`** — Pin.app 번들 빌드 + ad-hoc codesign + `--install` 옵션.
- **테스트** — 어댑터 3개(8+6+5) + watcher 2 = **21개 통과**.
- **빌드 검증** — debug/release 빌드, `swift run`, `.app` 번들 부팅 모두 통과.
- **문서 갱신** — README, architecture.md, history.md (결정 20번 추가).

**구조 (2026-05-05 v0.1.0)**:

```
pin/
├── Package.swift
├── README.md (=CLAUDE.md=AGENTS.md, 심볼릭 링크)
├── bin/
│   ├── run                    # swift run Pin
│   └── build-app.sh           # Pin.app 빌드 (--install 옵션)
├── docs/
│   ├── core-problem.md, approach.md, history.md, status.md, architecture.md
│   └── data/claude-code-transcript-format.md
├── Sources/
│   ├── PinCore/
│   │   ├── Models/ParsedMessage.swift           (ParsedMessage + SessionRef + SourceTool)
│   │   ├── Adapters/{ClaudeCodeAdapter,CodexAdapter,GeminiAdapter}.swift
│   │   ├── Locator/{Locators,ClaudeCodeLocator,CodexLocator,GeminiLocator}.swift
│   │   ├── Watcher/{JSONLTailWatcher,SessionWatcher}.swift
│   │   └── Store/MessageStore.swift
│   └── Pin/
│       ├── PinApp.swift, AppView.swift
│       └── Views/{SessionListView,DetailView,MessageListView,MessageCardView,PinnedSection}.swift
└── Tests/PinCoreTests/
    ├── {ClaudeCodeAdapter,CodexAdapter,GeminiAdapter,JSONLTailWatcher}Tests.swift
    └── Fixtures/sample.jsonl
```

---

## Open threads (미완 항목)

체크박스 의미: `[ ]` = 미해결, `[~]` = 진행 중, `[?]` = 검증·확인 필요

- [?] **사용자 다음 시각 검증 필요** — 실제 흐름:
    1. 빌드 → 설치 (`./bin/build-app.sh --install`)
    2. Spotlight에서 Pin 실행
    3. 좌측에서 도구 선택 / 가운데에서 세션 선택
    4. **기본으로 intermediate가 숨겨져 화면이 깔끔한지** (v0.1.1 핵심)
    5. "Show intermediate (n)" 토글로 켜고 끄기 자연스러운지
    6. preview 카드 expand / 핀 / 핀된 intermediate가 토글 OFF에서도 보이는지
    7. 도구·세션 전환 시 동작 자연스러운가
    → 마찰 항목을 다음 iteration의 첫 작업으로.
- [?] 실제 compact 발생한 세션의 정확한 이벤트 형태 미관찰 — 실제 사용 중 만나면 어댑터 보완.
- [?] Gemini 세션 listing 성능 — 세션 파일이 매번 전체 JSON parse라 많아지면 느려질 수 있음. 미루어 측정.
- [?] Codex 세션 fixture 기반 통합 테스트 — 현재는 단위 테스트만. 실제 rollout-*.jsonl 한 줄씩 파싱하는 회귀 테스트 추가 가치 있음.
- [ ] **Post-MVP 후보들** (사용자 피드백에 따라 우선순위 결정):
    - [ ] tool_use / thinking 인디케이터 표시 (간략 배지 또는 숨김 토글)
    - [ ] 부분 텍스트 선택 핀 (드래그 → 핀)
    - [ ] 글로벌 단축키 (예: ⌘⇧P로 Pin 윈도우 활성화)
    - [ ] 코드 블록 syntax highlighting (Splash 등)
    - [ ] 도구·세션 전환 시 핀 보존 옵션 (현재는 reset)
    - [ ] 새 세션 자동 감지 (현재는 ⌘R 수동 새로고침)
- [ ] 빌드 자동화 — GitHub Actions로 `Pin.app` 릴리스 빌드 + 노타라이즈 (멀리)
- [ ] "에이전트 자율 결정 vs 사용자 confirm" 경계 가이드 — 마찰 패턴이 충분히 쌓이면 한 줄 추가

---

## End-of-session protocol

세션 종료 시 다음을 수행한다:
1. 이 파일 **전체를 덮어쓴다** (이전 내용 보존하지 않음 — 로그가 아니라 스냅샷).
2. **Carry-forward**: 위 Open threads 중 아직 미해결인 항목은 새 status.md의 Open threads에도 반드시 다시 적는다. 빠뜨리면 영구히 잊힘.
3. 직전 세션에서 새로 만들어진 **결정**(설계·기술 선택 등)은 `history.md`에 항목 추가 (status.md엔 짧게 요약만).
4. State 값을 다시 평가: 깔끔히 끝났으면 🟢, 작업 중이면 🟡, 사용자 결정 대기면 🔴.
