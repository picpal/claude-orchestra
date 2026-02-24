# Claude Orchestra

이 프로젝트는 **Claude Orchestra** 멀티 에이전트 TDD 시스템을 사용합니다.

## Important
: 사용자가 플러그인을 설치해서 사용한다는 가정을 기본 전재로 하고 설계 및 개선 진행.

## ⛔ 작업 범위 제한 (절대 규칙)

> **이 프로젝트(claude-orchestra) 파일만 수정할 수 있습니다. 다른 프로젝트는 절대 수정하지 마세요.**

### 금지 사항
- ❌ 다른 프로젝트 디렉토리의 파일 Read/Edit/Write 금지
- ❌ api-studio, 사용자의 다른 프로젝트 등 외부 프로젝트 수정 금지
- ❌ 테스트 목적으로 다른 프로젝트에 파일 생성/수정 금지

### 허용 사항
- ✅ 이 프로젝트(`claude-orchestra/`) 내 파일만 수정
- ✅ 플러그인 코드, 문서, 설정 파일 수정
- ✅ `/tmp/` 등 임시 디렉토리에서 테스트

### 테스트 방법
- 사용자가 **다른 프로젝트에서 플러그인을 업데이트**하며 테스트
- 플러그인 설치 후 정상 동작 여부를 사용자가 확인
- 여기서는 플러그인 코드만 수정하고 커밋

## 🚨 플러그인 수정 시 필수: 계획 검증 (Plan Validation Team)

> **이 프로젝트(claude-orchestra 플러그인)를 수정하는 모든 계획은 구현 전에 반드시 4명 검토팀의 병렬 검증을 거쳐야 합니다.**

### 검증 트리거 조건

다음 중 하나라도 해당되면 **반드시** 계획 검증 실행:
- 에이전트 정의 수정/추가 (`agents/*.md`)
- Hook 스크립트 수정/추가 (`hooks/*.sh`, `hooks.json`)
- 설정 파일 수정 (`.claude/settings.json`, `orchestra-init/`)
- 명령어/스킬 수정 (`commands/`, `skills/`)
- 워크플로우 변경 (Phase, State 관련)
- 새로운 기능 추가

### 검증팀 구성 (4명 병렬 실행)

| 팀원 | 에이전트 파일 | 역할 | 검토 관점 |
|------|-------------|------|-----------|
| **Plan Architect** | `agents/plan-architect.md` | 구조 호환성 | 에이전트 통합, Maestro 허브 구조 유지, Phase Gate 호환 |
| **Plan Stability** | `agents/plan-stability.md` | 리스크 분석 | 상태 동기화, 파일 충돌, 실패 복구, 토큰 비용 |
| **Plan UX** | `agents/plan-ux.md` | 사용성 검토 | 설정 복잡도, 학습 곡선, 에러 메시지, 문서화 |
| **Plan Devil's Advocate** | `agents/plan-devils-advocate.md` | 반론 제기 | 필요성 의문, 오버엔지니어링 검토, 대안 제시 |

> **주의**: Plan Architect는 Research Layer의 Architecture 에이전트와 다른 역할입니다.
> - Architecture (Research, Phase 1): 대상 프로젝트의 아키텍처 분석 (범용)
> - Plan Architect (Validation, Phase 2a): Orchestra 플러그인 계획의 구조 호환성 검증 (Orchestra 전용)

### 검증 실행 방법

계획이 준비되면 다음과 같이 4개 Task를 **병렬로** 실행:

> 상세 호출 패턴: `rules/maestro-protocol.md` 참조

### 검증 결과 판정

| 조건 | 판정 | 조치 |
|------|------|------|
| 4명 모두 ✅ | **승인** | 구현 진행 |
| 1명 이상 ⚠️ | **조건부 승인** | 우려 사항 해결 후 진행 |
| 1명 이상 ❌ | **반려** | 계획 재검토 (최대 2회, 초과 시 사용자 에스컬레이션) |

### 검증 실패 피드백 형식

반려 또는 조건부 승인 시 Maestro가 사용자에게 전달하는 형식:

```
[Plan Validation 결과]
- Plan Architect: ✅/⚠️/❌ - {사유}
- Plan Stability: ✅/⚠️/❌ - {사유}
- Plan UX: ✅/⚠️/❌ - {사유}
- Plan Devil's Advocate: ✅/⚠️/❌ - {사유}

최종 판정: ✅ 승인 / ⚠️ 조건부 승인 / ❌ 반려
{조건부/반려 시 수정 필요 사항}
```

### 검증 없이 진행 불가

```
❌ 잘못된 패턴:
사용자: "새 기능 추가해줘"
→ 바로 구현 시작 (검증 생략)

✅ 올바른 패턴:
사용자: "새 기능 추가해줘"
→ 계획 수립
→ 4명 검토팀 병렬 검증 (계획 검증)
→ 검증 결과 종합
→ 사용자에게 결과 보고
→ 승인 시 구현 진행
→ 구현 완료
→ 4명 검토팀 병렬 검증 (구현 검증)
→ 승인 시 커밋
```

---

### 전체 워크플로우 (시작 ~ 끝)

```
┌─────────────────────────────────────────────────────────────┐
│  🚀 시작                                                     │
│  사용자 요청 → 계획 수립                                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  🔍 Phase 2a: Plan Validation Team (계획 검증, 4명 병렬)     │
│  ┌──────────┬──────────┬──────────┬──────────┐              │
│  │Architect │Stability │ UX Expert│ Devil's  │              │
│  └──────────┴──────────┴──────────┴──────────┘              │
│  → 승인 시 구현 진행, 반려 시 계획 재검토                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  ⚙️ Phase 3-5: 분석 → 구현 (병렬 Task 호출) → 충돌 검사          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  ✅ Phase 6: Verification (6-Stage)                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  🔍 Phase 6a-CR: Code-Review Team (5명 병렬)                 │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐   │
│  │Security  │Quality   │Perform.  │Standards │  TDD     │   │
│  │Guardian  │Inspector │Analyst   │Keeper    │Enforcer  │   │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘   │
│  → Approved 시 커밋, Block 시 Rework Loop                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  📝 Phase 7: Commit + Journal                                │
│  🏁 완료                                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 시스템 개요

20개 전문 에이전트가 협력하여 TDD 기반 개발을 수행합니다.
(11개 기본 + 5개 Code-Review Team + 4개 Plan Validation Team)
**Claude Code가 Main Agent(Maestro)로서** 모든 에이전트를 직접 호출합니다.

### 핵심 구조: Claude Code = Maestro (Main Agent)

```
┌─────────────────────────────────────────────────────────────────┐
│  Claude Code (Main Agent = Maestro)                              │
│  ─────────────────────────────────────────────────────────────  │
│  • 사용자 요청 수신                                               │
│  • Intent 분류 (TRIVIAL/EXPLORATORY/AMBIGUOUS/OPEN-ENDED)        │
│  • Task 도구로 모든 Subagent 호출                                 │
│  • 결과 수신 및 다음 행동 결정                                    │
│  • Verification, Git Commit, 상태 관리                           │
│                                                                  │
│  📋 규칙: rules/maestro-protocol.md                              │
│     (/tuning 시 .claude/rules/에 복사됨)                         │
└─────────────────────────────────────────────────────────────────┘
         │
         ├── Task(Interviewer)      → 요구사항 인터뷰
         ├── Task(Planner)          → TODO 분석 (실행은 Main Agent)
         ├── Task(High-Player)      → 복잡한 작업 실행
         ├── Task(Low-Player)       → 간단한 작업 실행
         ├── Task(Explorer)         → 코드베이스 탐색
         ├── Task(Conflict-Checker) → 충돌 검사
         ├── Task(Plan Validation Team) → 계획 검증 (4명 병렬)
         │   ├── Plan Architect
         │   ├── Plan Stability
         │   ├── Plan UX
         │   └── Plan Devil's Advocate
         ├── Task(Code-Review Team) → 코드 리뷰 (5명 병렬)
         │   ├── Security Guardian
         │   ├── Quality Inspector
         │   ├── Performance Analyst
         │   ├── Standards Keeper
         │   └── TDD Enforcer
         └── Task(Research Agents)  → 검색, 분석
```

### 왜 Claude Code가 Main Agent인가?

```
❌ 잘못된 구조 (이전):
   Claude Code → Task(Maestro) → Task(다른 에이전트) ← Subagent는 Task 호출 불가!

✅ 올바른 구조 (현재):
   Claude Code = Maestro → Task(모든 에이전트) ← Main Agent라서 Task 호출 가능
```

- **Subagent는 Task 도구를 사용할 수 없습니다**
- Maestro가 Subagent가 되면 다른 에이전트를 호출할 수 없음
- 따라서 Claude Code 자체가 Maestro 역할을 수행해야 함

### 핵심 원칙: 보고-결정-실행 패턴

```
┌─────────────────────────────────────────────────────────────────┐
│  Subagent → Main Agent(Claude Code) 보고                        │
│  Main Agent: 결과 분석 → 다음 에이전트 결정 → Task 호출          │
└─────────────────────────────────────────────────────────────────┘
```

- 모든 Subagent는 Main Agent에게 결과를 **보고**합니다
- Main Agent가 결과를 분석하고 다음 에이전트를 **결정**합니다
- Main Agent가 Task 도구로 해당 에이전트를 **실행**합니다

## 핵심 원칙

### 1. TDD 필수
- 모든 기능은 테스트 먼저 작성
- `[TEST]` → `[IMPL]` → `[REFACTOR]` 순서 강제
- 테스트 삭제 금지 (Hook으로 보호)
- 최소 80% 커버리지

### 2. 계획 기반 개발
- 모든 작업은 계획 문서로 시작 (`.orchestra/plans/`)
- Plan Validation Team (4명 병렬): 계획 검증 (구조 호환, 리스크, 사용성, 반론)

### 3. 검증 후 리뷰 후 커밋
- 6-Stage Verification Loop 통과 필수
- Code-Review (25+ 차원) 통과 필수
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
| `/checkpoint` | 현재 상태 체크포인트 저장 |
| `/context` | 컨텍스트 모드 전환 |
| `/e2e` | E2E 테스트 실행 |
| `/execute-plan` | 계획 실행 (Phase 4-7) |
| `/refactor-clean` | 코드 리팩토링 (안전 모드) |

## 컨텍스트 스킬

| 스킬 | 설명 |
|------|------|
| `/claude-orchestra:context-dev` | 개발 모드 — TDD 기반 코드 작성 |
| `/claude-orchestra:context-research` | 탐색 모드 — 코드베이스 분석, 문서 조사 |
| `/claude-orchestra:context-review` | 리뷰 모드 — 보안, 품질, 성능 검토 |

## 디렉토리 구조 (플러그인)

```
claude-orchestra/              # 플러그인 루트
├── agents/                    # 20개 에이전트 정의 (11 기본 + Code-Review 5명 + Plan Validation 4명)
├── commands/                  # 슬래시 명령어
├── skills/                    # 컨텍스트 스킬
│   ├── context-dev/SKILL.md
│   ├── context-research/SKILL.md
│   └── context-review/SKILL.md
├── hooks/                     # 자동화 훅
│   ├── hooks.json             # 플러그인 hooks 설정
│   ├── user-prompt-submit.sh  # 프롬프트 제출 시 처리
│   ├── maestro-guard.sh       # Maestro 규칙 보호
│   ├── tdd-guard.sh           # TDD 순서 보호
│   ├── tdd-post-check.sh      # TDD 사후 검증
│   ├── phase-gate.sh          # Phase Gate 제어
│   ├── agent-logger.sh        # 에이전트 활동 로깅
│   ├── test-logger.sh         # 테스트 실행 로깅
│   ├── change-logger.sh       # 파일 변경 로깅
│   ├── team-logger.sh         # 팀 활동 로깅
│   ├── team-idle-handler.sh   # 유휴 팀원 처리
│   ├── journal-tracker.sh     # 작업 일지 추적
│   ├── verify-before-commit.sh # Code-Review 미완료 시 커밋 차단
│   ├── execution-parallel-check.sh # 병렬 실행 경고
│   ├── explorer-hint.sh       # 탐색 힌트 제공
│   ├── find-root.sh           # 프로젝트 루트 탐색
│   ├── run-hook.sh            # 훅 실행 유틸리티
│   ├── stdin-reader.sh        # 표준 입력 처리
│   ├── save-context.sh        # 컨텍스트 저장
│   ├── load-context.sh        # 컨텍스트 복원
│   ├── auto-format.sh         # 자동 포맷팅
│   ├── git-push-review.sh     # Git Push 전 리뷰
│   ├── stop-handler.sh        # 세션 종료 처리
│   ├── verification/          # 검증 스크립트
│   ├── learning/              # 패턴 학습
│   │   ├── evaluate-session.sh
│   │   └── analyze-session.py
│   └── compact/               # 컨텍스트 압축
├── rules/                     # 코드 규칙 (/tuning 시 프로젝트에 복사, call-templates.md 포함)
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

### Main Agent (Claude Code = Maestro)
- **Claude Code**: Main Agent로서 Maestro 역할 수행
  - 사용자 대화, Intent 분류
  - Task 도구로 **모든 Subagent 호출**
  - Verification, Git Commit, 상태 관리
  - 규칙: `rules/maestro-protocol.md`

### Planning Layer (Subagents)
- **Interviewer** (Opus): 요구사항 인터뷰, 계획 초안 작성 → Main Agent에게 반환
- **Planner** (Opus): TODO 분석 전용 — 실행 순서 결정, 6-Section 프롬프트 생성 → Main Agent에게 반환

### Research Layer (Subagents)
- **Architecture** (Opus): 아키텍처 조언, 디버깅 (분석 결과만 반환)
- **Searcher** (Sonnet): 외부 문서 검색
- **Explorer** (Haiku): 내부 코드 검색
- **Image-Analyst** (Sonnet): 이미지 분석
- **Log-Analyst** (Sonnet): 로그 분석, 오류 진단, 통계 생성

### 🚀 Research Team (병렬 Task 호출)

복잡한 요구사항 분석 시 Research Layer 에이전트 3개를 **병렬로** 호출하여 컨텍스트를 빠르게 수집합니다.

```
┌─────────────────────────────────────────────────────────────┐
│  Research Team (Phase 1 병렬 실행)                           │
│  ┌──────────┬──────────┬──────────┐                         │
│  │ Explorer │ Searcher │Architecture│                       │
│  │ (haiku)  │ (sonnet) │  (opus)   │                        │
│  └────┬─────┴────┬─────┴────┬──────┘                        │
│       │          │          │                               │
│       ▼          ▼          ▼                               │
│   내부 코드   외부 문서   아키텍처                            │
│   탐색       검색        분석                               │
│       │          │          │                               │
│       └──────────┴──────────┘                               │
│              ↓                                              │
│       Maestro가 결과 종합                                    │
└─────────────────────────────────────────────────────────────┘
```

**사용 조건:**
- 복잡한 기능 개발 (새로운 모듈, 아키텍처 변경)
- 외부 라이브러리 통합 필요
- 기존 코드 이해가 필요한 대규모 수정

**장점:**
- 3개 에이전트가 **동시에** 실행되어 시간 단축
- 모두 **읽기 전용**이라 충돌 위험 없음
- 각 영역(내부/외부/설계)의 전문성 활용

**호출 방법:**
```
Maestro가 3개 Task를 한 메시지에서 병렬 호출:
├─ Task(Explorer): 코드베이스 탐색
├─ Task(Searcher): 외부 문서 검색
└─ Task(Architecture): 아키텍처 분석
```

> 상세 호출 패턴: `rules/maestro-protocol.md` 참조

### Validation Layer: Plan Validation Team (4명 병렬)

> Phase 2a에서 계획 검증 시 병렬 실행. 모두 **읽기 전용**.

| 팀원 | 모델 | 담당 영역 | 항목 수 |
|------|------|----------|--------|
| **Plan Architect** | Sonnet | 구조 호환성 | 5 |
| **Plan Stability** | Sonnet | 리스크 분석 | 5 |
| **Plan UX** | Sonnet | 사용성 검토 | 5 |
| **Plan Devil's Advocate** | Sonnet | 반론 제기 | 5 |

> 상세 내용: `agents/plan-architect.md`, `agents/plan-stability.md`,
> `agents/plan-ux.md`, `agents/plan-devils-advocate.md`

### Execution Layer (Subagents - Main Agent가 Task로 호출)
- **High-Player** (Opus): 복잡한 작업 실행
- **Low-Player** (Sonnet): 간단한 작업 실행

> **병렬 실행**: Level의 TODO가 2개 이상이면 Maestro가 한 메시지에 여러 Task()를 병렬 호출합니다.
> 충돌은 Phase 5 Conflict-Checker가 감지합니다.

### Verification Layer (Subagents)
- **Conflict-Checker** (Sonnet): 병렬 실행 후 충돌 감지 → Rework Loop 트리거

### Review Layer: Code-Review Team (5명 병렬)

> **기존 Code-Reviewer는 폐기되었습니다. 5명 전문팀으로 대체.**

| 팀원 | 모델 | 가중치 | 담당 영역 | 항목 수 |
|------|------|--------|----------|--------|
| **Security Guardian** | Sonnet | 4 | 보안 취약점 | 7 |
| **Quality Inspector** | Sonnet | 3 | 코드 품질 | 8 |
| **Performance Analyst** | Haiku | 2 | 성능 이슈 | 6 |
| **Standards Keeper** | Haiku | 2 | 표준 준수 | 5 |
| **TDD Enforcer** | Sonnet | 4 | TDD 검증 | 7 |

**총 가중치**: 15 (4+3+2+2+4)

**자동 Block 조건:**
- Security Guardian: Critical 보안 이슈 발견
- TDD Enforcer: 테스트 삭제 감지

**실행 방식:**
- Verification 통과 후 5명이 **동시에** 병렬 실행
- Maestro가 5개 결과를 종합하여 가중치 점수 계산
- ≥0.80 Approved, 0.50-0.79 Warning, <0.50 Block

```
┌─────────────────────────────────────────────────────────────┐
│  Code-Review Team (Phase 6a-CR 병렬 실행)                    │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐   │
│  │Security  │Quality   │Perform.  │Standards │  TDD     │   │
│  │Guardian  │Inspector │Analyst   │Keeper    │Enforcer  │   │
│  │(sonnet)  │(sonnet)  │(haiku)   │(haiku)   │(sonnet)  │   │
│  │ w=4      │ w=3      │ w=2      │ w=2      │ w=4      │   │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘   │
│                        ↓                                     │
│       Maestro: 결과 종합 → 가중치 점수 계산 → 판정           │
└─────────────────────────────────────────────────────────────┘
```

> 상세 내용: `agents/security-guardian.md`, `agents/quality-inspector.md`,
> `agents/performance-analyst.md`, `agents/standards-keeper.md`, `agents/tdd-enforcer.md`

## 6-Stage Verification Loop

```
1. Build Verification  - 컴파일 확인
2. Type Check          - 타입 안전성
3. Lint Check          - 코드 스타일
4. Test Suite          - 테스트 + 커버리지
5. Security Scan       - 시크릿/디버그 탐지
6. Diff Review         - 의도치 않은 변경 확인
```

## Verification → Code-Review Team → Commit 흐름

```
Phase 4: Level별 Execution 완료
    │ TODO >= 2: 병렬 Task 호출 (한 메시지에 여러 Task)
    │ TODO = 1: 단일 Task 호출
    │
    ▼
Phase 5: Conflict Check (조건부 - Skip 가능)
    │ 실행: Level 중 TODO 2개+ 또는 Level 2개+
    │ Skip: 단일 Level, 단일 TODO (순차 실행)
    ▼
Phase 6: Verification (6-Stage) - 모든 Level 완료 후 1회
    │
    ▼
Phase 6a-CR: Code-Review Team (5명 병렬)
    │ ┌──────────┬──────────┬──────────┬──────────┬──────────┐
    │ │Security  │Quality   │Perform.  │Standards │  TDD     │
    │ │Guardian  │Inspector │Analyst   │Keeper    │Enforcer  │
    │ └──────────┴──────────┴──────────┴──────────┴──────────┘
    │ Maestro: 5개 결과 종합 → 가중치 점수 계산
    │
    ├── ✅ Approved (≥0.80) → Phase 7
    ├── ⚠️ Warning (0.50-0.79) → 경고 기록 후 진행
    └── ❌ Block (<0.50 또는 Auto-Block) → Rework Loop (최대 3회)
    │
    ▼
Phase 7: Commit + Journal
```

### Rework Loop (Block 시)

```
❌ Block 발생 (Code-Review Team)
    ↓
Maestro: Block 사유 분석
    ↓
Player 재호출 (원래 프롬프트 + 수정 컨텍스트)
    ↓
Verification (Phase 6) → Code-Review Team (재실행)
    ↓
├─ 해결됨 → Phase 7 (Commit)
├─ 미해결 + 시도 < 3 → Loop 반복
└─ 시도 >= 3 → 사용자 에스컬레이션
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
