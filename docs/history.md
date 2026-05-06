# 프로젝트 히스토리 (Decision History)

> 이 프로젝트가 어떤 질문 → 사고 → 결정의 흐름을 거쳐왔는지 기록한다.
> 새 결정이 이루어지거나 기존 결정이 뒤집힐 때마다 위에서 아래 방향으로 추가/갱신한다.
> 단순히 "무엇을 정했는지"가 아니라 "왜 그렇게 정했는지"를 함께 남긴다 — 미래의 재논의가 가능하도록.

---

## 0. 시작점 (2026-05-05)

**문제 정의가 아니라 페인 포인트에서 출발.**

- AI(Claude Code, Codex 등)에게 학습용 질문을 던지고 긴 응답을 받음
- 그 응답을 읽다 자연스럽게 후속 질문이 생김
- 같은 세션에서 후속 질문을 하면 **원본 응답이 위로 밀려 사라짐**
- 결국 스크롤을 오가며 참조하게 되어 맥락이 끊김

→ "특정 응답을 화면에 **고정(pin)** 한 채로 대화를 이어갈 수 있어야 한다."

---

## 1. 페인 포인트를 문서화하기로 결정

**질문:** 매번 AI에게 같은 페인 포인트를 설명하기 싫다. 어디에 적어둘까?

**결정:** `docs/core-problem.md` 생성.

**근거:**
- 모든 develop·planning이 이 문서를 기반으로 진행되도록 단일 진실 원천을 만든다.
- "비-목표(Non-goals)" 섹션을 명시 — 새 LLM, 도구 대체, 검색/아카이브가 아님.

---

## 2. "작업 방식 문서"는 만들지 않기로 결정

**질문:** 이 프로젝트는 사용자가 코드를 한 줄도 쓰지 않는다. 이런 작업 방식을 `CLAUDE.md` 또는 `AGENTS.md`에 박아둘까?

**검토한 것:**
- `CLAUDE.md`만: Claude Code 자동 로드, 다른 도구 미적용
- `AGENTS.md`만: Codex 자동 로드, Claude Code 자동 로드 X
- 본문은 `AGENTS.md`, `CLAUDE.md`는 참조만 — 도구 여러 개 쓸 때의 일반적 패턴
- 최소 한 줄("AI가 모든 변경을 수행한다")만 박아두기

**결정:** **아무것도 박지 않는다.**

**근거:**
- 룰은 추측이 아니라 **반복 관찰된 마찰**에서 나와야 정확하다.
- 사전에 박은 메타 규칙은 모델이 과해석할 위험이 있음 (예: "사용자에게 직접 X 해보라고 제안하면 안 됨" 등으로 경직될 가능성).
- "사용자는 코드를 안 쓴다"는 것조차 규칙이 아니라 **결과적 사실**이다 — 사용자가 그렇게 행동하면 자연스럽게 그렇게 된다.
- 패턴이 쌓이면 그때 한 줄씩 추가하는 것이 가장 정확한 룰 작성 시점.

---

## 3. 에이전트 협업의 본질에 대한 합의

**질문:** "AI 에이전트가 잘 일한다"는 것은 무엇인가? 무엇을 위임하고 무엇을 사람의 역할로 가져갈 것인가?

**합의된 분담:**

| 사람만이 할 수 있는 것 | 위임 가능한 것 |
|---|---|
| 무엇을 만들지 결정 (목표 설정) | 어떻게 만들지 (구현) |
| "이게 맞다"는 감각 (taste/판단) | 탐색, 리서치, 초안 작성 |
| 방향 전환 (피벗, 스코프 변경) | 정해진 제약 안에서의 결정 |
| 최종 수용 ("페인이 풀렸나?") | 검증 가능한 작업 |

**핵심 원칙:** "잘 일한다"의 정의를 **미리** 정하려고 하지 않는다. 첫 결과물이 나오고 사용자가 반응할 때 그 정의가 비로소 드러난다.

---

## 4. 해결 방법 후보 검토

**질문:** core-problem을 어떻게 풀 것인가? 어떤 옵션이 있는가?

**검토한 5가지 접근:**
- A. 브라우저 확장 (웹 채팅 UI 위에 오버레이)
- B. 커스텀 채팅 클라이언트 (자체 웹 앱)
- C. 터미널 tmux 스플릿
- D. 도구 무관 부유 창 (단축키 기반)
- E. 브라우저 PiP

**사용자 결정:** "브라우저 X, CLI 도구(Codex, Claude Code 등)에서 풀고 싶다."

→ 후보가 C, D, 그리고 새로운 안(아키텍처 재검토)으로 좁혀짐.

---

## 5. CLI 환경에서의 아키텍처 결정

**질문:** "커스텀 클라이언트를 만들면 기존 터미널 역할을 다 수행해야 하나?"

**검토한 4가지 아키텍처:**
1. 풀 터미널 에뮬레이터 자체 구현 — 매우 무거움
2. PTY 서브프로세스 래핑 — 70% 정도 무거움, ANSI 파싱 필요
3. **트랜스크립트 파일을 읽는 사이드카** — 터미널 0% 건드림
4. tmux capture — 데이터 품질 낮음(렌더링된 ANSI 텍스트)

**결정:** **옵션 3 — 사이드카.**

**근거:**
- Claude Code, Codex, Gemini 모두 모든 대화를 디스크에 구조화된 파일(JSONL/JSON)로 저장한다는 사실 발견.
- 터미널 자체를 일절 건드리지 않으므로 기존 워크플로우 안 깨짐.
- 데이터가 ANSI가 아닌 구조화된 JSON이라 파싱이 단순하고 견고.
- CLI 도구 업데이트에 깨질 위험 작음.

---

## 6. 다른 CLI 도구 호환성 검증

**질문:** 사이드카 방식이 Codex, Gemini CLI에도 동일하게 적용 가능한가?

**확인 결과 (실제 파일 시스템 직접 확인):**

| 도구 | 저장 위치 | 포맷 | 쓰기 방식 |
|---|---|---|---|
| Claude Code | `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl` | JSONL | append-only |
| Codex CLI | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | JSONL | append-only |
| Gemini CLI | `~/.gemini/tmp/<project-hash>/chats/session-*.json` | JSON | 전체 재기록 |

**결론:** 셋 다 옵션 3 방식 가능. 단, 어댑터 패턴 필요(각 포맷 → 공통 메시지 모델).

**보너스 발견:** Gemini는 `thoughts`(사고 과정)를 별도 필드로 저장 — 향후 pin 대상에 포함 가능성.

---

## 7. compact 영향 검증

**질문:** Claude Code의 `/compact`가 디스크의 트랜스크립트를 건드리는가? compact 이후엔 원본 대화가 사라지는 것 아닌가?

**확인 결과:**
- JSONL은 구조적으로 append-only — 기존 줄을 지우거나 덮어쓰는 것이 구조상 어려움.
- compact가 영향을 주는 것은 **모델에게 보내는 in-memory context**일 뿐.
- 디스크에는 원본 메시지 + (보통) 요약 이벤트가 추가됨.

**결론:** **pin은 compact와 무관하게 원본 응답에 안정적으로 접근할 수 있다.** 이는 사이드카 접근에 결정적으로 유리한 사실.

**남은 검증 항목:** 실제 compact가 일어난 세션에서 정확한 이벤트 형태를 직접 관찰하는 단계 필요 (구현 시).

---

## 8. 방향성 굳힘 → `docs/approach.md` 작성

**결정:** 사이드카 방식을 공식 방향으로 박음.

**사용자가 이 방향을 택한 이유:**
1. **복잡하지 않다.**
2. **문제를 실제로 해결한다.**

→ `docs/approach.md`에 명시.

---

## 9. 형태 결정: 데스크톱 앱

**질문:** 사이드카의 형태는? 데스크톱 앱 / localhost 웹앱 / TUI 중에서.

**결정:** **데스크톱 앱.**

**근거:**
- "옆에 같이 띄워두고 본다"는 사용자 요구 자체가 데스크톱의 강점 호출 (always-on-top, 자유 창 배치, 글로벌 단축키, 독 상주 등).
- 트랜스크립트 watch에 로컬 파일 접근이 필요한데, 브라우저는 권한 우회가 필요함.

---

## 10. 기술 스택 결정: macOS native (SwiftUI)

**질문:** Tauri vs Electron vs native — 무엇을 쓸 것인가?

**검토:**
- Tauri: 크로스플랫폼, 가벼움(Electron 대비 1/10), 웹 프론트
- Electron: 진입 장벽 낮음, 무거움
- macOS native (SwiftUI): macOS 통합 깊이 최고, 메모리 최소

**사용자 선호:** "macOS만 쓰니 native로 가고 싶다."

**결정:** **SwiftUI 기반 macOS native 앱.** AppKit 보강은 필요 시.

**근거:**
- 사용자 환경이 macOS 전용이라 크로스플랫폼 추상화 비용을 낼 이유가 없음.
- 창 관리(always-on-top, 모든 Space 표시 등)가 1급 시민.
- FSEvents 기반 파일 watch가 가장 효율적.
- 한글 폰트·합자·시스템 폰트가 자동.

**기술 요소 후보:**
- 셸: SwiftUI + 필요 시 AppKit (`NSWindow` 등)
- 파일 watch: `FSEventStream` / `DispatchSource`
- 글로벌 단축키: `KeyboardShortcuts` (오픈소스)
- JSONL 파싱: `Codable` + 표준 라이브러리
- 마크다운: `swift-markdown-ui` 우선, 한계 시 `WKWebView` 하이브리드

---

## 11. 자기점검: 에이전트 협업 환경 평가

**질문:** 지금까지 만들어진 환경이 에이전트가 일을 잘 할 수 있는 구조인가?

**점검 결과:**

✅ **강점**
- 목표(`core-problem.md`)와 결정 근거(`approach.md`)가 명확히 보존됨
- "비-목표"가 명시되어 스코프 드리프트 방지
- 룰을 미리 박지 않음 — 모델 경직 방지

⚠️ **약점**
- **피드백 루프 없음** — 결과물이 0이라 검증 불가
- 진입점 문서 부재 — 새 세션이 어떤 순서로 읽어야 할지 안내 없음
- 현재 상태 문서 부재 — "어디까지 왔고 다음에 뭘 할지"가 머릿속과 git에만
- 결정 경계 미정 — 구현 시 "에이전트가 알아서 vs 물어보기"가 마찰 될 가능성

**처방 우선순위:**
1. `README.md` (진입점) ← 가벼움
2. `docs/status.md` (현재 상태) ← 가벼움
3. **MVP 스코프 결정** ← 가장 큰 결정. 이게 정해져야 첫 코드가 나오고 피드백 루프 시작.
4. (구현 직전) 결정 경계 한 줄 가이드

**현재 상태 종합:** 계획 단계 협업 환경으로는 80점. 구현 단계로 넘어가는 순간 60점으로 떨어질 위험 — 피드백 루프 부재 때문.

---

## 12. 히스토리 문서 작성 결정 (이 문서)

**질문:** 지금까지의 사고 흐름과 의사결정을 어디에 남길 것인가?

**결정:** `docs/history.md` 생성. 시간순 + 각 결정마다 "검토한 것 / 결정 / 근거" 구조.

**근거:**
- 미래의 재논의(피벗, 의문 제기) 시 *왜 그렇게 정했는지*를 빠르게 복원할 수 있어야 한다.
- 새 세션이 차갑게 시작했을 때 단편적 결정이 아니라 흐름을 이해할 수 있어야 한다.
- 단순한 ADR(결정만 기록)이 아니라 **사고 흐름**까지 남기는 형식으로 — taste·판단의 기준도 함께 보존.

---

## 13. status.md 도입 (sessions.md 폐기)

**질문:** 세션 핸드오프를 위해 어떤 형태의 파일이 필요한가?

**검토:**
- 처음 제안: `sessions.md` — 최근 3개 세션 rolling log
- 사용자 카운터 제안: `status.md` — 단일 스냅샷, 매 세션 종료 시 덮어쓰기

**결정:** **`status.md` 단일 스냅샷.**

**근거:**
- "지금 상태"가 본질이지 "최근 활동 로그"가 본질이 아님. 이름이 정직.
- 루프 use case에 정확히 맞음. 직전 상태 1개만 필요.
- carry-forward 규율로 정보 손실 방지.
- `history.md`(영구 결정)와 책임 분리 깔끔.

**부수 결정**: Open threads는 `[ ]`/`[~]`/`[?]` 체크박스로 구조화 → 새 세션이 미완 작업 여부를 스캔만으로 판단 가능.

---

## 14. MVP 빌드 시스템: Swift Package Manager 단독

**질문:** macOS native 앱을 어떻게 빌드할 것인가? Xcode 프로젝트 vs SwiftPM.

**검토:**
- Xcode 프로젝트: 정식 .app 번들, Info.plist, 권한 설정 등 풀 macOS 통합
- SwiftPM 단독: `swift build`, `swift run`만으로 동작. Package.swift 한 파일로 의존성·타겟 관리.

**결정:** **SwiftPM 단독.**

**근거:**
- 에이전트가 빌드/테스트/실행을 CLI로 회전할 수 있어야 협업 효율이 좋음. Xcode 의존이면 GUI 외엔 자동화 어려움.
- MVP에서 필요한 것은 GUI 창과 파일 read뿐 — 권한·번들·서명 등이 시급하지 않음.
- 후일 Xcode 프로젝트가 필요해지면 `swift package generate-xcodeproj` 또는 Xcode가 직접 Package.swift를 열 수 있음.

**대가:** `.app` 번들 형태가 아니라서 Dock에서 일반 앱처럼 보이진 않음. MVP 검증 단계에선 무관.

---

## 15. MVP 의존성 결정

**결정:**
- `swift-markdown-ui` 채택 (마크다운 렌더링)
- `KeyboardShortcuts` 등은 MVP에서 보류 (글로벌 단축키는 post-MVP)

**근거:**
- AI 응답은 마크다운 (헤더, 코드블록, 리스트)이 핵심이라 plain text 렌더는 가독성 손실이 큼.
- swift-markdown-ui는 SwiftPM 호환, SwiftUI 네이티브, 활발한 유지보수.
- 그 외 의존성은 추가하지 않음 — 외부 라이브러리는 자산이자 부채. MVP 범위 안에서 표준 라이브러리(FileHandle, DispatchSource, JSONSerialization)로 충분히 가능.

---

## 16. user 메시지 필터 규칙

**질문:** Claude Code의 `user` 이벤트에는 시스템 주입 텍스트(`<command-name>`, `<local-command-caveat>` 등)가 섞여 들어옴. 어떻게 처리?

**결정:** content가 string이면서 `<...>` 태그로 시작하면 nil 반환 (skip).

**근거:**
- 사용자 학습 흐름과 무관한 노이즈를 카드에 보이지 않게 함.
- 단순 prefix 체크로 충분 — 정교한 파서 불필요.
- 트레이드오프: 사용자가 진짜로 `<` 로 시작하는 발화를 했다면 누락됨. 실측 빈도 낮음. 마찰 발생 시 그때 정교화.

---

## 17. 데이터 모델: Swift Codable + 도구 enum

**결정:** `ParsedMessage` 단일 구조체. `sourceTool` enum으로 출처 표시.

**근거:**
- MVP는 Claude Code 단일 어댑터지만, 이후 Codex/Gemini 추가 시 동일 모델 재사용.
- 어댑터 패턴은 "파서가 도구별 포맷 → 공통 모델"로 변환하는 단순 함수 형태(`parse(line:) -> ParsedMessage?`)로 충분. Protocol 추상화는 어댑터가 2개 이상 생길 때 도입.

---

## 18. UI 패턴: SwiftUI + `@MainActor` Store

**결정:** `MessageStore`를 `@MainActor ObservableObject`로 두고 SwiftUI 뷰가 `@EnvironmentObject`로 주입받음.

**근거:**
- Swift 6 strict concurrency 환경. UI 상태는 main actor 위에 있어야 안전.
- Watcher는 `@unchecked Sendable` 경계로 두고 콜백이 main에서 실행되도록 큐 지정.
- 단일 store로 messages·pinnedIds·currentSessionFile을 한 곳에서 관리 → SwiftUI 갱신이 단순.

---

## 19. 테스트 전략

**결정:**
- `PinCore`만 테스트 대상 (UI는 시각 검증).
- Adapter는 단위 테스트, Watcher는 통합 테스트(임시 파일 + append).
- 픽스처는 `Tests/PinCoreTests/Fixtures/sample.jsonl`에 두고 Bundle.module로 로드.

**근거:**
- 어댑터 동작이 깨지면 사용자가 즉시 모를 수 있음(빈 화면처럼 보임). 회귀 방지 우선순위 높음.
- Watcher는 FSEvents/DispatchSource 동작이 platform-dependent라 직접 검증 가치 큼.
- UI는 매 변경마다 시각 확인 가능하고, 자동 테스트 비용 대비 가치 낮음.

---

## 20. v0.1.0: 멀티 소스 + preview 카드 + .app 번들 (사용자 첫 피드백 반영)

**사용자 피드백:**
1. SwiftPM `swift run` 말고 macOS .app으로도 실행하고 싶다 — 단, GitHub pull로 활용 가능해야 함.
2. 도구를 골라서 (Claude Code / Codex / Gemini), 세션 목록 보고, 그 중 메시지를 핀.
3. 메시지를 카드로 짧게만 보이게 + 핀하면 전체.

**결정 1 — 데이터 레이어 확장 (개선 #2):**
- `SourceTool` enum에 `.codex`, `.gemini` 추가 (`CaseIterable`)
- `SessionRef` 모델 신설 — `{id, title, sourceTool, fileURL, lastModified}`
- `SessionDiscovery` 단일 진입점 — 도구별 Locator 호출 통합
- `ParsedMessage.id`/`sessionId`를 `UUID`에서 `String`으로 변경 — 도구마다 ID 포맷 달라서

**근거:**
- 어댑터/로케이터별 책임 분리. Sub-Module 추가 시 한 곳만 손보면 됨.
- `String` id 채택 — Codex의 message id가 nil인 경우도 있어 fallback UUID 생성이 필요. UUID 강제는 모델을 경직시킴.

**결정 2 — Watcher 추상화:**
- `SessionWatcher` protocol 신설. `start()` / `stop()` / `onMessages([ParsedMessage]) -> Void`.
- JSONL 도구는 `JSONLLineSessionWatcher` (incremental tail + 누적). Gemini는 `GeminiFileSessionWatcher` (변경 시 전체 재파싱).
- `MessageStore`는 protocol에만 의존, 구체 구현은 `SessionWatcherFactory`.

**근거:**
- Claude/Codex(append-only)와 Gemini(전체 재기록)의 watch 전략이 본질적으로 다름. 같은 추상 위에 두 구현을 두는 게 명료.
- Store가 매번 전체 메시지 리스트를 받아 갱신 — diff는 SwiftUI `Identifiable`이 처리. 내부 incremental 효율은 watcher 안에서.

**결정 3 — 카드 모드 분리 (개선 #3):**
- `MessageCardView`에 `mode: preview | full` 파라미터 추가.
- preview: 4줄 truncate + expand 토글(▼) — 핀하지 않고도 즉석에서 펼쳐볼 수 있음.
- full: 마크다운 풀 렌더, Pinned 영역에서만 사용.
- expand 상태도 Store가 관리(`expandedIds`).

**근거:**
- 사용자 피드백 그대로: "조금만 표시 + 핀하면 전체". 그러나 핀 안 하고도 펼치고 싶을 때(빠른 글랜스)가 분명히 있을 것 → expand 토글 추가.
- preview에서 줄바꿈을 공백으로 평탄화해 한정된 4줄 안에서 정보 밀도를 올림.

**결정 4 — UI 패턴: NavigationSplitView (3-pane):**
- 좌: SourcesSidebar (도구 선택, 도구별 세션 개수 표시).
- 가운데: SessionListView (도구 내 세션 목록, 제목·상대시간·짧은 ID).
- 우: DetailView (Pinned 섹션 + 메시지 리스트).

**근거:**
- macOS 표준 패턴. 사용자가 익숙함. 컬럼 width 조절 자동.
- 세션 단위로 '핀 상태 / expand 상태'가 리셋되는 게 자연스러움 — 다른 세션 골라도 핀 유지하고 싶지 않을 것 (의문 발생 시 다음 iteration에서 결정).

**결정 5 — .app 빌드 스크립트 (개선 #1):**
- `bin/build-app.sh` 추가. SwiftPM 릴리스 빌드 → 수동으로 .app 번들 구성 → ad-hoc codesign.
- `--install` 플래그로 `~/Applications/`에 직접 설치.
- `Pin.app/`는 `.gitignore` (소스만 commit, 결과물은 빌드 시).

**근거:**
- 사용자의 의문 "GitHub pull과 호환되나?" — 그대로 호환. `git clone && ./bin/build-app.sh --install`로 한 번에.
- Xcode 프로젝트 추가는 보류 — Package.swift 단일 진실 원천 유지가 에이전트 협업에 유리. .app은 그 산출물에 plist만 얹는 가벼운 wrapper.
- 코드 서명은 ad-hoc(`-`). 배포·노타라이즈는 멀리. 본인 머신에서 Gatekeeper 우회는 ad-hoc로 충분.

**결정 6 — Codex thread_name index 활용:**
- `~/.codex/session_index.jsonl`에 thread_name이 있어 Codex의 세션 제목으로 활용. 없으면 첫 user message로 fallback.
- Claude Code는 `ai-title` 이벤트가 트랜스크립트 안에 있어 첫 256KB만 스캔.
- Gemini는 단일 JSON 안에 `summary` 필드.

**근거:**
- "session-19df3da3" 같은 hex가 아니라 자연어 제목으로 식별 가능해야 사용자가 선택 가능. 도구마다 title 위치가 다르므로 Locator가 흡수.

**테스트:** 어댑터 3개 + watcher 1개 = 21개 테스트 모두 통과. .app 부팅 스모크 통과.

---

## 21. assistant final vs intermediate 구분

**사용자 피드백:** Claude Code 카드를 보면, 최종 답변뿐 아니라 도구 호출 사이의 짧은 코멘트(예: "Let me check the file")까지 모두 별개의 메시지 카드로 보여서 화면이 산만하다.

**관찰**:
- Claude Code의 트랜스크립트에서 `message.stop_reason`이 깨끗한 신호.
  - `tool_use` → 이 응답 다음에 도구가 호출됨 → **intermediate**.
  - 그 외(`end_turn`, `null`, `max_tokens`, `stop_sequence`) → **final**.
- 실측: 한 사용자 트랜스크립트 전체에서 intermediate가 **49.4%**. 거의 절반.
- Gemini는 메시지 객체에 `toolCalls` 필드가 있어 비어있지 않으면 intermediate. 같은 의미.
- Codex는 `function_call`이 별도 response_item이라 단일 이벤트로 판별 불가. stateful 트래킹 필요. 일단 모두 final 취급.

**결정**:
- `MessageKind` enum 신설: `userInput` / `assistantFinal` / `assistantIntermediate`.
- `ParsedMessage.kind` 필드로 노출.
- 어댑터 3개 모두 kind를 산출:
  - ClaudeCode: `stop_reason` 기반.
  - Gemini: `toolCalls` 기반.
  - Codex: 항상 final (TODO note 남김).
- 기본 동작: intermediate **숨김**. UI 상단 "Show intermediate (n)" 토글로 보일 수 있음.
- 핀된 intermediate는 토글과 무관하게 항상 표시 — 사용자가 의도적으로 핀했으므로.
- 카드 시각 구분: intermediate는 옅은 배경 + "AI · intermediate" 뱃지.

**근거**:
- 49% 노이즈를 기본으로 숨기면 학습 use case에서 신호가 명확히 살아남.
- "intermediate 숨김" 자체가 user 발화 → AI 최종 답변의 깔끔한 Q&A 흐름을 회복.
- 핀과의 상호작용: 사용자가 "이 commentary가 흥미롭다"고 의도적으로 핀하면 그 뜻을 존중. 토글 OFF여도 살림.
- 어댑터 단계에서 kind를 결정 — UI는 단순한 필터만. 책임 분리.

**테스트**: 25개 통과 (kind 검증용 4개 추가).

---

## 22. 폰트 키움 + always-on-top 토글화

**사용자 피드백**:
1. 카드 안 글씨가 작다 — 키워달라.
2. 앱이 다른 앱 위에 무조건 고정되어 있는 게 버그처럼 느껴진다.

**결정 1 — 폰트 사이즈 상향**:
- preview 텍스트: 12 → **14**
- 마크다운 본문: 13 → **15**
- pin된 full 카드도 동일.

**근거**:
- 학습 use case에서 가독성이 곧 product value. 12-13은 노트북 화면에서 작음.
- 시스템 기본 본문 사이즈가 macOS에서 13인데, 사이드카는 본문보다 살짝 큰 게 자연스러움.
- 향후 사용자 사이즈 토글(S/M/L) 추가는 보류 — 현시점에선 단일 기본값 변경으로 충분.

**결정 2 — always-on-top을 토글로 빼고 기본 OFF**:
- 처음 셋업 시 `window.level = .floating`을 강제했었음. "사이드카는 항상 위"가 직관이라 생각했지만, 사용자 입장에선 다른 앱 작업 시 가려지지 않아 방해.
- 이제 `@AppStorage("alwaysOnTop")` Bool 토글. 기본 false (= `.normal` level — 일반 윈도우).
- 툴바 우측에 핀 아이콘 토글 (`pin.circle.fill` / `pin.circle`).
- 메뉴: View > "Always on top" (단축키 ⌘⇧T).
- `WindowConfigurator` (NSViewRepresentable)가 `alwaysOnTop` 변경 시마다 `level` + `collectionBehavior` 갱신.

**근거**:
- "기본 OFF + 토글 ON 가능"이 통제권을 사용자에게 돌려주는 깨끗한 모델. 처음 강제했던 건 추측에 가까웠음.
- collectionBehavior도 토글 따라감: ON일 때만 `.canJoinAllSpaces` (모든 스페이스에서 보임). OFF면 일반 윈도우 동작 — 다른 스페이스로 이동하면 같이 따라감(`.fullScreenPrimary`).
- 환경 변경 시점 — `@AppStorage`는 SwiftUI가 자동 invalidate → `updateNSView` 재호출 → `level` 즉시 반영.
- 토글 위치: 핀 아이콘은 의미상 "이 창을 핀할까"라 직관적. 메시지 핀과 다른 종류임을 시각적으로 차별 (circle 변형 사용).

---

## 23. 메시지 정렬: 기본 newest-first + 토글

**사용자 피드백**: 최신 대화가 위에 오면 좋겠다 + 정렬 변경 가능했으면 좋겠다.

**결정**:
- `MessageSortOrder` enum: `.newestFirst` / `.oldestFirst`. 기본 `.newestFirst`.
- `MessageStore.sortOrder` `@Published`. UserDefaults에 영속(`pin.messageSortOrder` 키).
- `visibleMessages` / `pinned` 둘 다 `applySort` 통과.
- 툴바 가운데에 Picker (메뉴 스타일) — 작은 표시로 두 옵션 선택.
- ScrollViewReader: 정렬 따라 스크롤 anchor 동적 변경 — newestFirst면 맨 위로, oldestFirst면 맨 아래로 자동 스크롤. `onChange(of: sortOrder)`도 트리거.

**근거**:
- 학습 use case에서 가장 최근 응답이 가장 보고 싶은 것. 매번 끝까지 스크롤하는 마찰이 사라짐.
- 단 일부 use case(처음부터 흐름 따라 읽기)는 oldest-first가 자연스러움 → 토글로 둘 다 지원.
- 메시지는 도착 순(=시간 오름차순)으로 누적되므로 정렬은 단순 `reversed()`로 충분.
- UserDefaults 영속화로 사용자 기호가 다음 실행에도 유지.
- Pinned 영역도 같은 정렬 적용 — 시각적 일관성.

**테스트 추가**: `MessageStoreTests` 신설 (정렬·필터·핀 상호작용 6개). 총 **31개 통과**.

---

> **현재 상태 / 다음 작업은 `docs/status.md`에 있음.** 이 문서는 의사결정 narrative만 담는다.
