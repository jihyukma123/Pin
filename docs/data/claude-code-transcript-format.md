# Claude Code Transcript Format

> Claude Code가 디스크에 기록하는 JSONL 트랜스크립트의 정밀 분석.
> 사이드카 앱의 파싱 어댑터 설계 기반.

## 파일 위치

```
~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
```

- `<encoded-cwd>`: 절대 경로의 `/`를 `-`로 치환 (예: `/Users/jihyukma/Documents/c/pin` → `-Users-jihyukma-Documents-c-pin`)
- `<session-id>`: UUID
- 한 프로젝트(cwd)당 여러 세션 파일이 누적

## 파일 형태

JSONL — 한 줄에 한 JSON 이벤트, **append-only**.

## 이벤트 타입

`type` 필드로 구분. 실측 통계 (한 프로젝트 내):

| type | 처리 우선도 | 의미 |
|---|---|---|
| `assistant` | **★ MVP 필수** | AI 응답 메시지 |
| `user` | **★ MVP 필수** | 사용자 입력 |
| `system` | 무시 (MVP) | 환경/메타 안내 |
| `attachment` | 무시 (MVP) | 첨부 파일 |
| `last-prompt` | 무시 | 내부 트래킹 |
| `permission-mode` | 무시 | 권한 모드 변경 |
| `ai-title` | 옵션 | 세션 제목 자동 생성 |
| `file-history-snapshot` | 무시 | 파일 변경 추적 |

## user / assistant 메시지 구조

공통 필드:
- `uuid`, `parentUuid` — 메시지 그래프
- `sessionId` — 세션 식별
- `timestamp` — ISO 8601
- `cwd`, `gitBranch`, `version` — 메타
- `message` — 실제 메시지 객체

`message` 객체:
- `role`: `"user"` 또는 `"assistant"`
- `model`: assistant만 (예: `claude-opus-4-7`)
- `content`: **string 또는 list**

### content가 string인 경우 (user만 관찰됨)

대부분 시스템 주입 텍스트 (`<local-command-caveat>`, `<command-name>` 등)와 일반 사용자 텍스트가 섞여 있음.

샘플:
- `<local-command-caveat>...` — 메타 안내, **필터링 권장**
- `<command-name>/clear</command-name>...` — 슬래시 명령, **필터링 권장**
- `soul.md와 기타 설정용 파일 말고는 다 삭제해줄래?` — 실제 사용자 발화

→ MVP에서는 `<` 로 시작하면서 XML-like 태그가 있으면 노이즈로 필터.

### content가 list인 경우

`content` 배열 안의 각 블록은 `type` 필드로 종류 구분:

#### `text` block

```json
{"type": "text", "text": "..."}
```

- 가장 단순. 마크다운 본문이 그대로 들어있음.
- **MVP 핵심 표시 대상**.

#### `tool_use` block (assistant만)

```json
{"type": "tool_use", "id": "toolu_...", "name": "Bash", "input": { ... }}
```

- AI가 도구를 호출하는 시점.
- MVP에서는 **간단한 인디케이터만 표시** 또는 숨김.
- 관찰된 도구: Bash, Read, Write, Edit, TaskUpdate, TaskCreate, ToolSearch

#### `tool_result` block (user만)

```json
{"type": "tool_result", "tool_use_id": "toolu_...", "content": "...", "is_error": false}
```

- 도구 실행 결과 (시스템이 user 메시지로 주입).
- MVP에서는 **숨김** (사용자가 적극 보고 싶은 것이 아님).

#### `thinking` block (assistant만)

```json
{"type": "thinking", "thinking": "..."}
```

- AI의 사고 과정.
- MVP에서는 **숨김** (옵션 토글 가능성).

## MVP에서 사이드카가 표시할 것

1. **user 메시지의 일반 텍스트** (시스템 태그 필터 후)
2. **assistant 메시지의 `text` 블록**
3. (참조용) `timestamp`, `sessionId`

표시하지 않을 것:
- system / attachment / last-prompt / permission-mode / file-history-snapshot 이벤트
- user의 `tool_result` 블록
- assistant의 `tool_use` / `thinking` 블록 (post-MVP에서 옵션)

## 알려진 미관찰 항목

- `summary` / `compact` 이벤트 — compact가 실제 발생한 세션이 손에 없음. 실구현 중 만나면 처리 추가.
- 매우 긴 응답에서의 분할 여부 — 현재 관찰: 단일 assistant 이벤트 내 단일 text 블록.

## final vs intermediate 구분

`assistant` 메시지의 `message.stop_reason` 필드로 결정:
- `"tool_use"` → **intermediate** — 다음 턴에 도구 호출이 이어진다는 신호. 본문 텍스트는 도구 호출 직전의 commentary.
- `"end_turn"` / `null` / `"max_tokens"` / `"stop_sequence"` 등 → **final** — 사용자에게 보여줄 답변.

실측 (한 사용자의 모든 트랜스크립트 합산): final 50.6% / intermediate 49.4%. 즉 절반은 도구 호출 사이의 코멘트. 사이드카는 기본적으로 intermediate를 숨기고 토글로 보이게 한다.

## 파싱 어댑터 책임

이 포맷을 **공통 메시지 모델**로 변환:

```
ParsedMessage {
    id: UUID                  // event uuid
    sessionId: UUID
    role: .user | .assistant
    text: String              // 추출·정리된 텍스트
    timestamp: Date
    sourceTool: .claudeCode
}
```

- 타입이 user/assistant가 아닌 이벤트는 nil 반환 (skip)
- content가 string이면서 시스템 태그면 nil
- content가 list면 모든 `text` 블록을 줄바꿈 두 개로 join하여 text 필드에 저장
- text 블록이 0개면 nil (tool_use·tool_result만 있는 메시지)
