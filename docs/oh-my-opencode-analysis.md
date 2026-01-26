# Oh-My-OpenCode 에이전트 시스템 분석

> **분석일**: 2026-01-25
> **목적**: claude-orchestra 프로젝트에 멀티 에이전트 오케스트레이션 구조 적용을 위한 참고 자료

---

## 1. 개요

Oh-My-OpenCode는 **OpenCode**라는 AI 코딩 도구를 위한 플러그인으로, 멀티모델 에이전트 오케스트레이션 시스템을 구현합니다. 10개의 특화된 에이전트가 역할 분담하여 복잡한 개발 작업을 처리합니다.

### 핵심 특징
- 멀티모델 지원 (Claude, GPT, Gemini, Grok, GLM)
- 31개의 라이프사이클 훅
- 20개 이상의 도구
- 카테고리 기반 작업 위임
- 스킬 시스템을 통한 도메인 지식 주입

---

## 2. 에이전트 계층 구조

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AGENT HIERARCHY                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐     ┌─────────────┐                                        │
│  │  Sisyphus   │     │ Prometheus  │  ← 사용자와 직접 대화하는 Primary       │
│  │  (Primary)  │     │  (Planner)  │                                        │
│  └──────┬──────┘     └──────┬──────┘                                        │
│         │                   │                                                │
│         │  delegate_task    │  call_omo_agent                               │
│         ▼                   ▼                                                │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │
│  │    Atlas    │     │   Metis     │     │   Momus     │                    │
│  │(Orchestrator)│    │(Pre-Planner)│     │ (Reviewer)  │                    │
│  └──────┬──────┘     └─────────────┘     └─────────────┘                    │
│         │                                                                    │
│         │  delegate_task (category + skills)                                │
│         ▼                                                                    │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │              Sisyphus-Junior (Executor Pool)                   │          │
│  │  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │          │
│  │  │   quick     │  ultrabrain │visual-engin │  artistry   │   │          │
│  │  │  (haiku)    │  (gpt-5.2)  │ (gemini-3)  │ (gemini-3)  │   │          │
│  │  └─────────────┴─────────────┴─────────────┴─────────────┘   │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │              Specialist Agents (Read-Only)                     │          │
│  │  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │          │
│  │  │   Oracle    │  Librarian  │   Explore   │ Multimodal  │   │          │
│  │  │  (GPT-5.2)  │ (GLM-4.7)   │(gpt-5-nano) │(Gemini-3)   │   │          │
│  │  │ 아키텍처조언 │ 외부문서검색 │ 내부코드검색│ PDF/이미지  │   │          │
│  │  └─────────────┴─────────────┴─────────────┴─────────────┘   │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. 에이전트별 상세 역할

| Agent | Model | 비용 | 역할 | 제한된 도구 |
|-------|-------|------|------|-------------|
| **Sisyphus** | Claude Opus 4.5 | EXPENSIVE | Primary 오케스트레이터, 사용자와 대화 | call_omo_agent |
| **Atlas** | Claude Opus 4.5 | EXPENSIVE | Todo 리스트 완료 전담 오케스트레이터 | task, call_omo_agent |
| **Prometheus** | Claude Opus 4.5 | EXPENSIVE | 요구사항 인터뷰 & 작업 계획 생성 | .md 파일만 작성 가능 |
| **Metis** | Claude Sonnet 4.5 | CHEAP | 계획 전 분석, 놓친 질문 확인 | - |
| **Momus** | Claude Sonnet 4.5 | CHEAP | 계획 검증/리뷰 | - |
| **Oracle** | GPT-5.2 | EXPENSIVE | 아키텍처 조언, 디버깅 | write, edit, task, delegate_task |
| **Librarian** | GLM-4.7-free | CHEAP | 외부 문서/GitHub 검색 | write, edit, task, delegate_task |
| **Explore** | GPT-5-nano | FREE | 내부 코드베이스 검색 | write, edit, task, delegate_task |
| **Multimodal** | Gemini 3 Flash | CHEAP | PDF/이미지 분석 | read만 허용 |
| **Sisyphus-Junior** | 카테고리별 다름 | 다양 | 실제 작업 실행 | task, delegate_task |

---

## 4. 개발 요청 처리 프로세스

### Phase 0: Intent Gate (Sisyphus)

사용자 요청을 분류하고 적절한 처리 방식 결정:

| 유형 | 신호 | 액션 |
|------|------|------|
| **Trivial** | 단일 파일, 알려진 위치, 직접 답변 | 직접 도구만 사용 |
| **Explicit** | 특정 파일/라인, 명확한 명령 | 직접 실행 |
| **Exploratory** | "X가 어떻게 작동해?", "Y 찾아줘" | explore (1-3개) + 도구 병렬 실행 |
| **Open-ended** | "개선해줘", "리팩토링", "기능 추가" | 코드베이스 먼저 평가 |
| **Ambiguous** | 불명확한 범위, 다중 해석 | 명확화 질문 1개 |

### Phase 1: 탐색 & 연구 (병렬 실행)

```typescript
// 항상 백그라운드로 병렬 실행
delegate_task(subagent="explore", run_in_background=true,
              prompt="인증 구현 찾아줘")
delegate_task(subagent="explore", run_in_background=true,
              prompt="에러 처리 패턴 찾아줘")
delegate_task(subagent="librarian", run_in_background=true,
              prompt="JWT 베스트 프랙티스 찾아줘")

// 즉시 다음 작업 진행, 필요시 background_output()으로 결과 수집
```

### Phase 2A: 계획 수립 (Prometheus)

1. 사용자 인터뷰 (요구사항 명확화)
2. explore/librarian으로 컨텍스트 수집
3. Metis 상담 (놓친 질문 확인)
4. 작업 계획 생성 → `.sisyphus/plans/{name}.md`
5. (선택) Momus 검증

계획 파일 예시:
```markdown
# Auth Refactor Plan

## TODOs
- [ ] [P:2] 기존 인증 로직 분석
- [ ] [P:1] JWT 토큰 검증 구현
- [ ] [P:3] 에러 처리 개선
- [ ] [P:2] 테스트 작성
```

### Phase 2B: 실행 (Atlas → Sisyphus-Junior)

Atlas가 각 TODO에 대해 delegate_task 호출:

```typescript
delegate_task(
  category="ultrabrain",  // 작업 성격에 맞는 카테고리
  load_skills=["tdd-workflow", "security-patterns"],  // 도메인 지식
  run_in_background=false,
  prompt=`
    ## 1. TASK
    JWT 토큰 검증 로직 구현

    ## 2. EXPECTED OUTCOME
    - src/auth/jwt.ts 생성
    - 테스트 파일 동반

    ## 3. REQUIRED TOOLS
    - grep: 기존 인증 코드 참조
    - lsp_diagnostics: 검증

    ## 4. MUST DO
    - 테스트 먼저 작성 (TDD)
    - 노트패드에 결과 기록

    ## 5. MUST NOT DO
    - 다른 파일 수정 금지
    - 의존성 추가 금지

    ## 6. CONTEXT
    - 노트패드: .sisyphus/notepads/auth-refactor/
  `
)
```

### Phase 3: 검증 (Atlas)

매 delegation 후 Atlas가 직접 검증:

- [ ] `lsp_diagnostics(filePath=".")` → 에러 0개
- [ ] `bun run build` → exit code 0
- [ ] `bun test` → 모든 테스트 통과
- [ ] 변경된 파일 직접 읽어서 요구사항 충족 확인

실패 시 세션 재사용:
```typescript
delegate_task(
  resume="ses_xyz789",  // 기존 세션 재사용! (70% 토큰 절약)
  prompt="검증 실패: {에러 내용}. 수정해."
)
```

3번 연속 실패 시:
1. 모든 편집 중단
2. 마지막 정상 상태로 복원
3. Oracle 상담
4. 해결 안되면 사용자에게 질문

### Phase 4: 완료

```
ORCHESTRATION COMPLETE
TODO LIST: .sisyphus/plans/auth-refactor.md
COMPLETED: 4/4
FILES MODIFIED: src/auth/jwt.ts, tests/auth/jwt.test.ts
```

---

## 5. 핵심 설계 원칙

| 원칙 | 설명 |
|------|------|
| **Delegation First** | 직접 작업보다 위임이 기본. 단순한 것만 직접 처리 |
| **Parallel by Default** | explore/librarian은 항상 병렬 백그라운드 실행 |
| **Session Resume** | 실패 시 새 세션 생성 금지, 기존 세션 재사용 (70% 토큰 절약) |
| **6-Section Prompt** | 모든 delegation은 TASK/OUTCOME/TOOLS/MUST DO/MUST NOT/CONTEXT 필수 |
| **Verify Everything** | "에이전트를 믿지 마라" - 항상 직접 검증 |
| **Notepad System** | 서브에이전트는 stateless → 노트패드로 지식 전달 |
| **Category + Skills** | 작업 성격에 맞는 모델 + 도메인 지식 조합 |

---

## 6. 카테고리 시스템

| Category | Model | Temperature | 용도 |
|----------|-------|-------------|------|
| `quick` | Claude Haiku 4.5 | 0.1 | 단순 작업, 타이포 수정 |
| `visual-engineering` | Gemini 3 Pro | 0.5 | UI/UX, 프론트엔드 |
| `ultrabrain` | GPT-5.2 Codex | 0.1 | 복잡한 아키텍처, 깊은 로직 |
| `artistry` | Gemini 3 Pro | 0.7 | 창의적 작업 |
| `writing` | Gemini 3 Flash | 0.5 | 문서, 기술 글쓰기 |
| `unspecified-low` | Claude Sonnet 4.5 | 0.3 | 분류 안되는 중간 난이도 |
| `unspecified-high` | Claude Opus 4.5 | 0.3 | 분류 안되는 고난이도 |

---

## 7. 도구 제한 패턴

```typescript
// Read-Only 에이전트 (Oracle, Librarian, Explore)
const restrictions = createAgentToolRestrictions([
  "write",
  "edit",
  "task",
  "delegate_task",
])

// Executor 에이전트 (Sisyphus-Junior)
const restrictions = createAgentToolRestrictions([
  "task",
  "delegate_task",  // 재위임 방지
])
```

---

## 8. 노트패드 시스템

서브에이전트는 **stateless**이므로 노트패드를 통해 지식 전달:

```
.sisyphus/
├── plans/           # 작업 계획 (READ ONLY)
│   └── {name}.md
└── notepads/        # 누적 지식 (READ/APPEND)
    └── {name}/
        ├── learnings.md   # 패턴, 관례
        ├── decisions.md   # 아키텍처 결정
        ├── issues.md      # 문제, 함정
        └── problems.md    # 미해결 이슈
```

---

## 9. Claude Code 적용 시 고려사항

### 제약 사항
- Claude Code는 **플러그인 시스템이 없음**
- Hooks는 **셸 스크립트** 기반
- 에이전트는 `.claude/agents/` 마크다운 파일로 정의

### 적용 가능한 개념
1. **에이전트 마크다운 파일로 역할 분리**
2. **CLAUDE.md에 프로세스 정의**
3. **슬래시 명령어로 모드 전환**
4. **상태 파일로 컨텍스트 유지**
5. **Hook으로 TDD 원칙 강제**

### 적용 불가능한 개념
1. 멀티모델 선택 (Claude만 사용)
2. 런타임 에이전트 설정 변경
3. TypeScript 기반 동적 프롬프트 빌딩
4. 카테고리 기반 모델 라우팅
