# pin

> AI 대화에서 참조하고 싶은 응답을 화면에 고정한 채로 후속 대화를 이어갈 수 있게 하는 macOS 사이드카 앱.

## 문서

각 문서가 **언제 관련되는지**를 보고 필요한 것만 읽는다 (전부 읽지 말 것).

- [`docs/status.md`](docs/status.md) — **현재 어디까지 왔고 미완 작업이 있는지**. 새 세션 시작 시 가장 먼저 본다. 직전 세션의 작업 상태 스냅샷 + Open threads 체크박스 + 한 줄 State 값.
- [`docs/core-problem.md`](docs/core-problem.md) — **무엇을 푸는가**. 스코프 의문, "이 기능이 필요한가?", 페인 정의를 확인할 때.
- [`docs/approach.md`](docs/approach.md) — **어떻게 풀 것인가** (사이드카 방식, macOS native SwiftUI). 구현/기술 선택을 할 때, 또는 구조적 결정에서 막힐 때.
- [`docs/architecture.md`](docs/architecture.md) — **레이어/데이터 모델/MVP 범위**. 코드를 만지기 직전, 또는 새 기능을 어디에 끼울지 정할 때.
- [`docs/data/claude-code-transcript-format.md`](docs/data/claude-code-transcript-format.md) — **Claude Code JSONL 포맷 사양**. 어댑터를 손볼 때.
- [`docs/history.md`](docs/history.md) — **의사결정 흐름과 근거**. 기존 결정이 의심스럽거나 재논의가 필요할 때, 또는 "왜 이렇게 정해졌지?"가 궁금할 때.

새 세션은 `status.md`만 보면 대개 충분하다. 나머지는 작업 성격이 해당 문서에 닿을 때만 펼친다.

## 빌드 & 실행

**일반 사용 (.app 번들)**:
```bash
./bin/build-app.sh --install     # ~/Applications/Pin.app 설치
# 이후 Spotlight(⌘Space) 'Pin' 또는 Dock에서 실행
```

**개발 (CLI)**:
```bash
swift test                       # 단위 테스트 (빠름)
swift run Pin                    # 디버그 실행 (또는 ./bin/run)
swift build -c release           # 릴리스 빌드만
```

요구사항: macOS 14+, Swift 6.0+ / Xcode 16+. 실행하면 좌측에서 Claude Code / Codex / Gemini 중 도구를 고르고, 가운데에서 세션을 골라, 우측에 메시지가 흐른다. ⌘R로 세션 목록 갱신.

## 세션 종료 시

`docs/status.md`를 **전체 덮어쓰기**로 갱신한다 (단일 스냅샷, 로그 아님). 미해결 Open threads는 반드시 carry-forward. 새 결정이 있었다면 `history.md`에 항목 추가. 자세한 절차는 `docs/status.md` 하단의 "End-of-session protocol" 참조.
