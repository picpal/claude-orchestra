# Claude Orchestra

이 프로젝트는 **Claude Orchestra** 멀티 에이전트 TDD 시스템을 사용합니다.

## Important
: 사용자가 플러그인을 설치해서 사용한다는 가정을 기본 전재로 하고 설계 및 개선 진행.

## 시스템 개요

14개 전문 에이전트가 협력하여 TDD 기반 개발을 수행합니다.
**Maestro가 중앙 허브 역할**을 하며 모든 에이전트를 직접 호출합니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                     MAESTRO (중앙 허브)                          │
│  사용자 대화 + Intent 분류 + 모든 에이전트 호출 + 상태 관리      │
│                           │                                      │
│   ┌───────────────────────┼───────────────────────┐             │
│   │                       │                       │             │
│   ▼                       ▼                       ▼             │
│ ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│ │ Interviewer │    │Plan-Checker │    │Plan-Reviewer│          │
│ │ (계획초안)  │    │ (검토)      │    │ (승인)      │          │
│ └─────────────┘    └─────────────┘    └─────────────┘          │
│                           │                                      │
│                           ▼                                      │
│                    ┌─────────────┐                              │
│                    │   Planner   │  ← 분석만 (실행은 Maestro)   │
│                    └─────────────┘                              │
│                           │                                      │
│   ┌───────────────────────┼───────────────────────┐             │
│   │                       │                       │             │
│   ▼                       ▼                       ▼             │
│ ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│ │ High-Player │    │ Low-Player  │    │  Research   │          │
│ │ (복잡작업)  │    │ (간단작업)  │    │  Agents     │          │
│ └─────────────┘    └─────────────┘    └─────────────┘          │
│         │                 │                                      │
│         └────────┬────────┘                                      │
│                  ▼ (병렬 실행 시)                                │
│           ┌─────────────────┐                                   │
│           │Conflict-Checker │  ← 충돌 감지 → Rework Loop        │
│           │   (충돌 검사)   │                                   │
│           └─────────────────┘                                   │
│                  │                                               │
│          All agents report                                       │
│          back to Maestro                                         │
└─────────────────────────────────────────────────────────────────┘
```

### 핵심 원칙: 보고-결정-실행 패턴

```
┌─────────────────────────────────────────────────────────────────┐
│  Agent → Maestro 보고 (결과 반환)                                │
│  Maestro: 결과 분석 → 다음 에이전트 결정 → 호출                  │
└─────────────────────────────────────────────────────────────────┘
```

- 모든 에이전트는 Maestro에게 결과를 **보고**합니다
- Maestro가 결과를 분석하고 다음 에이전트를 **결정**합니다
- Maestro가 직접 해당 에이전트를 **실행**합니다

## 핵심 원칙

### 1. TDD 필수
- 모든 기능은 테스트 먼저 작성
- `[TEST]` → `[IMPL]` → `[REFACTOR]` 순서 강제
- 테스트 삭제 금지 (Hook으로 보호)
- 최소 80% 커버리지

### 2. 계획 기반 개발
- 모든 작업은 계획 문서로 시작 (`.orchestra/plans/`)
- Plan-Checker: 놓친 질문 확인
- Plan-Reviewer: 계획 검증

### 3. 검증 후 커밋
- 6-Stage Verification Loop 통과 필수
- PR Ready 상태에서만 자동 커밋

## 슬래시 명령어

| 명령어 | 설명 |
|--------|------|
| `/tuning` | Orchestra 초기화 (rules 복사 + 상태 디렉토리 생성) |
| `/start-work` | 작업 세션 시작 |
| `/status` | 현재 상태 확인 |
| `/tdd-cycle` | TDD 사이클 안내 |
| `/verify` | 검증 루프 실행 |
| `/code-review` | 코드 리뷰 실행 |
| `/learn` | 세션에서 패턴 학습 |
| `/update-docs` | 문서 동기화 |

## 컨텍스트 스킬

| 스킬 | 설명 |
|------|------|
| `/claude-orchestra:context-dev` | 개발 모드 — TDD 기반 코드 작성 |
| `/claude-orchestra:context-research` | 탐색 모드 — 코드베이스 분석, 문서 조사 |
| `/claude-orchestra:context-review` | 리뷰 모드 — 보안, 품질, 성능 검토 |

## 디렉토리 구조 (플러그인)

```
claude-orchestra/              # 플러그인 루트
├── agents/                    # 14개 에이전트 정의
├── commands/                  # 슬래시 명령어
├── skills/                    # 컨텍스트 스킬
│   ├── context-dev/SKILL.md
│   ├── context-research/SKILL.md
│   └── context-review/SKILL.md
├── hooks/                     # 자동화 훅
│   ├── hooks.json             # 플러그인 hooks 설정
│   ├── tdd-guard.sh
│   ├── test-logger.sh
│   ├── agent-logger.sh
│   ├── activity-logger.sh
│   ├── mcp-logger.sh
│   ├── skill-logger.sh
│   ├── stdin-reader.sh
│   ├── user-prompt-submit.sh
│   ├── save-context.sh
│   ├── load-context.sh
│   ├── auto-format.sh
│   ├── git-push-review.sh
│   ├── verification/          # 검증 스크립트
│   ├── learning/              # 패턴 학습
│   │   ├── evaluate-session.sh
│   │   └── analyze-session.py
│   └── compact/               # 컨텍스트 압축
├── rules/                     # 코드 규칙 (/tuning 시 프로젝트에 복사)
├── contexts/                  # (호환용) 컨텍스트 파일
├── .claude/
│   ├── settings.json          # 에이전트/권한 설정
│   └── commands/              # 슬래시 명령어 (ship, update-docs)
└── CLAUDE.md
```

### /tuning 후 프로젝트에 생성되는 구조

```
your-project/
├── .claude/rules/             # Orchestra 규칙 (플러그인에서 복사)
├── .orchestra/                # 상태/데이터 디렉토리
│   ├── config.json            # 프로젝트 설정
│   ├── state.json             # 현재 상태
│   ├── plans/                 # 계획 문서
│   ├── journal/               # 작업 일지
│   └── logs/                  # 로그 파일
```

## TDD 워크플로우

```
1. RED   - 실패하는 테스트 작성
2. GREEN - 테스트 통과하는 최소 구현
3. REFACTOR - 코드 개선 (테스트 유지)
```

## Intent 분류

| Intent | 예시 | 처리 |
|--------|------|------|
| TRIVIAL | "안녕", "Orchestra가 뭐야?" | Maestro 직접 응답 (비코드만) |
| EXPLORATORY | "이 함수 설명해줘", "인증 로직 어디있어?" | Explorer 위임 (코드 관련) |
| AMBIGUOUS | "로그인 고쳐줘" | 명확화 질문 |
| OPEN-ENDED | "OAuth 추가해줘" | 전체 플로우 |

## 상태 (Mode)

| Mode | 설명 |
|------|------|
| IDLE | 대기 중 |
| PLAN | 계획 수립 중 |
| EXECUTE | 작업 실행 중 |
| REVIEW | 검토 중 |

## 에이전트 역할

### Central Hub
- **Maestro** (Opus): 중앙 허브 — 사용자 대화, Intent 분류, **모든 에이전트 직접 호출**, Verification, Git Commit, 상태 관리

### Planning Layer
- **Interviewer** (Opus): 요구사항 인터뷰, 계획 초안 작성 → Maestro에게 반환
- **Planner** (Opus): TODO 분석 전용 — 실행 순서 결정, 6-Section 프롬프트 생성 → Maestro에게 반환
- **Plan-Checker** (Sonnet): 놓친 질문 확인
- **Plan-Reviewer** (Sonnet): 계획 검증

### Research Layer
- **Architecture** (Opus): 아키텍처 조언, 디버깅 (분석 결과만 반환)
- **Searcher** (Sonnet): 외부 문서 검색
- **Explorer** (Haiku): 내부 코드 검색
- **Image-Analyst** (Sonnet): 이미지 분석
- **Log-Analyst** (Sonnet): 로그 분석, 오류 진단, 통계 생성

### Execution Layer (Maestro가 직접 호출)
- **High-Player** (Opus): 복잡한 작업 실행
- **Low-Player** (Sonnet): 간단한 작업 실행

### Verification Layer
- **Conflict-Checker** (Sonnet): 병렬 실행 후 충돌 감지 → Rework Loop 트리거

### Review Layer
- **Code-Reviewer** (Sonnet): 25+ 차원 코드 리뷰

## 6-Stage Verification Loop

```
1. Build Verification  - 컴파일 확인
2. Type Check          - 타입 안전성
3. Lint Check          - 코드 스타일
4. Test Suite          - 테스트 + 커버리지
5. Security Scan       - 시크릿/디버그 탐지
6. Diff Review         - 의도치 않은 변경 확인
```

## 프로젝트 규칙

### 코드 스타일
- TypeScript strict 모드
- ESLint + Prettier
- 함수 50줄 이하
- 파일 800줄 이하

### 보안
- 하드코딩된 시크릿 금지
- 입력 검증 필수
- 에러 시 스택 트레이스 숨김

### Git
- 원자적 커밋 (TODO 단위)
- 커밋 메시지 형식 준수
- PR Ready 상태에서만 커밋
