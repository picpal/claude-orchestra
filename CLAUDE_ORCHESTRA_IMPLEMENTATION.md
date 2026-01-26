# Claude Orchestra 멀티 에이전트 TDD 시스템

## 목차
1. [설계 및 플랜](#설계-및-플랜)
2. [구현 결과](#구현-결과)
3. [디렉토리 구조](#디렉토리-구조)
4. [사용 방법](#사용-방법)

---

# 설계 및 플랜

## 개요

11개 에이전트 기반의 TDD 개발 오케스트레이션 시스템 구현

## 에이전트 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER INTERACTION LAYER                        │
│                    ┌─────────────┐                              │
│                    │   Maestro   │  ← 사용자 대화, Intent 분류  │
│                    │ (Opus 4.5)  │                              │
│                    └──────┬──────┘                              │
├───────────────────────────┼─────────────────────────────────────┤
│                    PLANNING LAYER                                │
│   ┌─────────────┐  ┌──────┴──────┐  ┌─────────────┐            │
│   │ Interviewer │  │   Planner   │  │Plan-Reviewer│            │
│   │ (Opus 4.5)  │  │ (Opus 4.5)  │  │(Sonnet 4.5) │            │
│   │요구사항인터뷰│  │ Todo 완료   │  │ 계획 검증   │            │
│   └──────┬──────┘  └──────┬──────┘  └─────────────┘            │
│          │                │         ┌─────────────┐            │
│          └────────────────┼────────→│Plan-Checker │            │
│                           │         │(Sonnet 4.5) │            │
│                           │         │놓친 질문 확인│            │
│                           │         └─────────────┘            │
├───────────────────────────┼─────────────────────────────────────┤
│                    RESEARCH LAYER (Read-Only)                    │
│   ┌─────────────┬─────────┴───┬─────────────┬─────────────┐    │
│   │Architecture │   Searcher  │  Explorer   │Image-Analyst│    │
│   │ (Opus 4.5)  │(Sonnet 4.5) │  (Haiku)    │(Sonnet 4.5) │    │
│   │아키텍처조언 │외부문서검색 │내부코드검색 │ 이미지분석  │    │
│   └─────────────┴─────────────┴─────────────┴─────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│                    EXECUTION LAYER                               │
│   ┌─────────────────────────┬─────────────────────────┐        │
│   │     High-Player         │      Low-Player          │        │
│   │       (Opus)            │       (Sonnet)           │        │
│   │   복잡한 작업 실행      │   간단한 작업 실행       │        │
│   └─────────────────────────┴─────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

## 개발 요청 처리 플로우

```
Phase 0: Intent Gate (Maestro)
    │
    ├── TRIVIAL → 직접 처리
    ├── EXPLORATORY → Research 에이전트 병렬 호출
    ├── AMBIGUOUS → 명확화 질문
    └── OPEN-ENDED → Phase 1로 진행
           │
Phase 1: 탐색 & 연구 (병렬)
    │    - Explorer: 내부 코드 검색
    │    - Searcher: 외부 문서 검색
    │    - Architecture: 패턴 분석 (필요시)
    │
Phase 2A: 계획 수립 (Interviewer)
    │    1. 요구사항 인터뷰
    │    2. Plan-Checker 상담 (놓친 질문)
    │    3. 계획 생성 (.orchestra/plans/{name}.md)
    │    4. Plan-Reviewer 검증
    │
Phase 2B: 실행 (Planner → Executor)
    │    각 TODO에 대해:
    │    - 복잡도 판단 (High/Low Player)
    │    - TDD 사이클 강제 ([TEST] → [IMPL] → [REFACTOR])
    │    - 6-Section 프롬프트로 위임
    │    - ⭐ 6단계 Verification Loop 실행
    │    - ✅ 자동 Git Commit (Planner가 직접 수행)
    │
Phase 3: 검증 (6-Stage Verification Loop)
    │    1. Build Verification - 컴파일 확인
    │    2. Type Check - 타입 안전성 검증
    │    3. Lint Check - 코드 스타일 검사
    │    4. Test Suite - 테스트 + 커버리지 (80%+)
    │    5. Security Scan - 시크릿/디버그 문 탐지
    │    6. Diff Review - 의도치 않은 변경 확인
    │    → PR Ready 평가
    │
Phase 4: 완료 (Maestro)
         - 결과 보고
```

## 구현 항목 설계

### 1. 에이전트 마크다운 파일

**경로**: `templates/.claude/agents/`

| 파일명 | Model | 역할 |
|--------|-------|------|
| `maestro.md` | opus | 사용자 대화, Intent 분류, 전체 조율 |
| `planner.md` | opus | Todo 완료 전담, Executor 위임, 검증 |
| `interviewer.md` | opus | 요구사항 인터뷰, 계획 작성 (.md만) |
| `plan-checker.md` | sonnet | 계획 전 분석, 놓친 질문 확인 |
| `plan-reviewer.md` | sonnet | 계획 검증, TDD 원칙 준수 확인 |
| `architecture.md` | opus | 아키텍처 조언, 디버깅 지원 |
| `searcher.md` | sonnet | 외부 문서/GitHub 검색 |
| `explorer.md` | haiku | 내부 코드베이스 검색 |
| `image-analyst.md` | sonnet | 이미지 분석 (Read만) |
| `high-player.md` | opus | 복잡한 작업 실행 |
| `low-player.md` | sonnet | 간단한 작업 실행 |

### 2. 디렉토리 구조 설계

```
templates/
├── .claude/
│   ├── agents/           # 11개 에이전트
│   ├── commands/
│   │   ├── start-work.md
│   │   ├── tdd-cycle.md
│   │   └── status.md
│   └── settings.json     # hooks 설정
├── .orchestra/
│   ├── config.json       # 프로젝트 설정
│   ├── hooks/
│   │   ├── tdd-guard.sh  # 테스트 삭제 방지
│   │   └── test-logger.sh
│   └── state.json        # 상태 템플릿
└── CLAUDE.md             # 프로젝트 가이드
```

### 3. TDD 강제 메커니즘 설계

#### 3.1 계획 단계
- TODO 형식: `[TEST]`, `[IMPL]`, `[REFACTOR]` 태그 필수
- `[IMPL]` 앞에 반드시 `[TEST]`가 있어야 함

#### 3.2 실행 단계
- Planner가 순서 강제 (TEST 완료 후 IMPL 시작)
- Executor 프롬프트에 "테스트 먼저" 명시

#### 3.3 Hook
- `tdd-guard.sh`: 테스트 파일/케이스 삭제 차단

### 4. 6-Section 프롬프트 구조

```markdown
## 1. TASK
{TODO 내용}

## 2. EXPECTED OUTCOME
- 생성/수정 파일
- 기능 동작
- 검증 명령어

## 3. REQUIRED TOOLS
- 허용된 도구 목록

## 4. MUST DO
- TDD 사이클 준수
- 노트패드 기록
- 최소 구현

## 5. MUST NOT DO
- 범위 외 수정 금지
- 테스트 삭제 금지
- 재위임 금지

## 6. CONTEXT
- 노트패드 경로
- 관련 파일
```

### 5. 6-Stage Verification Loop 설계

#### 검증 플로우

```
TODO 완료
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: BUILD VERIFICATION                                │
│  ─────────────────────────────                              │
│  명령어: npm run build / tsc --noEmit                       │
│  실패 시 → STOP (이후 단계 진행 불가)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓ 성공
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: TYPE CHECK                                        │
│  ─────────────────                                          │
│  명령어: tsc --noEmit --strict                              │
│  TypeScript/Python 타입 안전성 검증                         │
│  라인별 에러 리포트 생성                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: LINT CHECK                                        │
│  ───────────────────                                        │
│  명령어: eslint . --max-warnings=0                          │
│  ESLint/Prettier 코드 스타일 검사                           │
│  경고/에러 목록 생성                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: TEST SUITE + COVERAGE                             │
│  ─────────────────────────────                              │
│  명령어: npm test -- --coverage                             │
│  전체 테스트 실행                                            │
│  커버리지 메트릭 수집 (목표: 80%+)                           │
│  80% 미만 → BLOCK                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 5: SECURITY SCAN                                     │
│  ──────────────────────                                     │
│  검사 항목:                                                  │
│  - 하드코딩된 시크릿 탐지 (API_KEY=, sk-, password=)        │
│  - console.log/디버그 문 검색                               │
│  - .env 파일 스테이징 여부 확인                             │
│  - 노출된 자격증명 확인                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 6: DIFF REVIEW                                       │
│  ─────────────────────                                      │
│  검사 항목:                                                  │
│  - git diff --name-only 확인                                │
│  - TODO 범위 외 파일 수정 경고                              │
│  - 의도치 않은 수정 탐지                                     │
│  - git status 확인                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  VERIFICATION REPORT                                        │
│  ════════════════════                                       │
│  Build:    ✅ PASS / ❌ FAIL                                │
│  Types:    ✅ PASS / ❌ FAIL (N errors)                     │
│  Lint:     ✅ PASS / ⚠️ N warnings / ❌ N errors           │
│  Tests:    ✅ N/N passed (Coverage: N%)                     │
│  Security: ✅ No issues / ❌ N issues found                 │
│  Diff:     ✅ N files changed / ⚠️ unexpected changes      │
│  ──────────────────────────────────────────────             │
│  PR Ready: ✅ YES / ❌ NO                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    PR Ready인 경우만
                            ↓
                      Git Commit
```

#### 검증 실행 모드

| 모드 | 실행 단계 | 사용 시점 |
|------|-----------|-----------|
| `quick` | Build + Types | 빠른 확인 (개발 중) |
| `standard` | Build + Types + Lint + Tests | TODO 완료 시 |
| `full` | 전체 6단계 | 커밋 전 |
| `pre-pr` | 전체 + 보안 스캔 강화 | PR 제출 전 |

#### 커버리지 기준

| 코드 유형 | 최소 커버리지 |
|-----------|---------------|
| 일반 코드 | 80% |
| 금융/결제 로직 | 100% |
| 인증/보안 로직 | 100% |
| 핵심 비즈니스 로직 | 100% |

### 6. Git Commit 자동화 설계

#### 커밋 플로우

```
Planner
    └── TODO 완료
        └── 6-Stage Verification Loop
            ├── Phase 1: Build ✓
            ├── Phase 2: Types ✓
            ├── Phase 3: Lint ✓
            ├── Phase 4: Tests (80%+) ✓
            ├── Phase 5: Security ✓
            └── Phase 6: Diff ✓
                │
                ▼
            PR Ready: YES
                │
                ▼
            Git Commit 수행
                ├── git add {변경된 파일}
                └── git commit -m "{커밋 메시지}"
```

#### 커밋 메시지 형식

```
[{TODO-TYPE}] {TODO 내용}

- 변경 파일: {파일 목록}
- TDD Phase: {RED/GREEN/REFACTOR}

TODO: {TODO-ID}
Plan: {plan-name}
```

### 7. 상태 관리 설계

**state.json 스키마**:
```typescript
{
  mode: 'IDLE' | 'PLAN' | 'EXECUTE' | 'REVIEW',
  currentContext: 'dev' | 'research' | 'review',  // NEW: 컨텍스트 모드
  currentPlan: { path, name, startedAt },
  todos: [{ id, content, status, executor, sessionId, commitHash? }],
  tddMetrics: { testCount, redGreenCycles, testDeletionAttempts },
  commitHistory: [{ todoId, hash, message, timestamp, files }],

  // Verification Loop 메트릭
  verificationMetrics: {
    lastRun: 'ISO-8601',
    mode: 'quick' | 'standard' | 'full' | 'pre-pr',
    results: {
      build: { status: 'pass' | 'fail', duration: number },
      types: { status: 'pass' | 'fail', errors: number, warnings: number },
      lint: { status: 'pass' | 'warn' | 'fail', errors: number, warnings: number },
      tests: {
        status: 'pass' | 'fail',
        passed: number,
        failed: number,
        skipped: number,
        coverage: {
          lines: number,
          branches: number,
          functions: number,
          statements: number
        }
      },
      security: {
        status: 'pass' | 'fail',
        issues: [{ type, file, line, message }]
      },
      diff: {
        status: 'pass' | 'warn',
        filesChanged: number,
        unexpectedChanges: string[]
      }
    },
    prReady: boolean,
    blockers: string[]
  },

  // NEW: Continuous Learning 메트릭
  learningMetrics: {
    totalSessions: number,
    patternsExtracted: number,
    lastLearningRun: 'ISO-8601',
    activePatterns: string[],  // 활성화된 패턴 ID 목록
    recentPatterns: [{
      id: string,
      category: 'error_resolution' | 'debugging' | 'workaround' | 'project_specific',
      title: string,
      extractedAt: 'ISO-8601',
      usageCount: number
    }]
  },

  // NEW: Strategic Compact 메트릭
  compactMetrics: {
    totalCompactions: number,
    lastCompaction: 'ISO-8601',
    currentToolCount: number,
    suggestedAt: number | null,  // 마지막 제안 시점의 tool count
    phaseHistory: [{
      phase: string,
      compactedAt: 'ISO-8601',
      contextSizeBefore: number,
      contextSizeAfter: number
    }]
  },

  // NEW: Code Review 기록
  codeReviewHistory: [{
    reviewId: string,
    timestamp: 'ISO-8601',
    filesReviewed: string[],
    result: 'approve' | 'warning' | 'block',
    issuesFound: {
      critical: number,
      high: number,
      medium: number,
      low: number
    },
    todoId?: string  // 관련 TODO
  }],

  // NEW: 체크포인트
  checkpoints: [{
    id: string,
    name: string,
    createdAt: 'ISO-8601',
    description: string,
    stateSnapshot: object  // 해당 시점의 전체 state
  }]
}
```

## 구현 순서 (플랜)

### Phase 1: 기초 구조
1. [x] 에이전트 마크다운 파일 11개 생성
2. [x] CLAUDE.md 템플릿 작성
3. [x] 디렉토리 구조 생성

### Phase 2: TDD Hook
4. [x] tdd-guard.sh 구현
5. [x] settings.json 에 hook 등록
6. [x] test-logger.sh 구현

### Phase 3: 상태 관리
7. [x] state.json 스키마 확장
8. [x] TypeScript 타입 정의

### Phase 4: CLI
9. [x] init-orchestra 명령어 구현
10. [x] orchestra-status 명령어 구현
11. [x] install 명령어에 Orchestra 초기화 통합

### Phase 5: 6-Stage Verification Loop
12. [ ] verification-loop.sh 스크립트 구현
    - [ ] Phase 1: build-check.sh
    - [ ] Phase 2: type-check.sh
    - [ ] Phase 3: lint-check.sh
    - [ ] Phase 4: test-coverage.sh
    - [ ] Phase 5: security-scan.sh
    - [ ] Phase 6: diff-review.sh
13. [ ] verification-report.sh 리포트 생성기
14. [ ] state.json에 verificationMetrics 타입 추가
15. [ ] Planner 에이전트에 Verification Loop 통합
16. [ ] /verify 명령어 추가
17. [ ] settings.json에 검증 Hook 등록

### Phase 6: Continuous Learning (연속 학습)
18. [ ] learning/ 디렉토리 구조 생성
    - [ ] config.json (학습 설정)
    - [ ] evaluate-session.sh (세션 평가 스크립트)
    - [ ] learned-patterns/ (학습된 패턴 저장소)
19. [ ] state.json에 learningMetrics 타입 추가
20. [ ] /learn 명령어 추가
21. [ ] Stop 훅에 evaluate-session.sh 등록
22. [ ] Plan-Reviewer에 learned-patterns 참조 로직 추가

### Phase 7: Strategic Compact (전략적 컴팩션)
23. [ ] compact/ 디렉토리 구조 생성
    - [ ] suggest-compact.sh (컴팩션 제안 스크립트)
    - [ ] compact-config.json (컴팩션 설정)
24. [ ] state.json에 compactMetrics 타입 추가
25. [ ] Phase 전환 시 자동 컴팩션 제안 로직
26. [ ] PreToolUse 훅에 suggest-compact.sh 등록

### Phase 8: Code Review Enhancement
27. [ ] code-reviewer.md 에이전트 추가 (12번째 에이전트)
28. [ ] /code-review 명령어 추가
29. [ ] handoff-document.md 템플릿 생성
30. [ ] 에이전트 간 핸드오프 로직 구현
31. [ ] Planner에 Code Reviewer 호출 로직 추가

### Phase 9: 추가 명령어 및 훅 확장
32. [ ] 추가 명령어 구현
    - [ ] /checkpoint (상태 스냅샷)
    - [ ] /e2e (E2E 테스트 실행)
    - [ ] /refactor-clean (리팩토링 모드)
    - [ ] /update-docs (문서 동기화)
    - [ ] /context (컨텍스트 모드 전환)
33. [ ] 훅 확장
    - [ ] auto-format.sh (Prettier 자동 포맷팅)
    - [ ] git-push-review.sh (push 전 검토)
    - [ ] load-context.sh (세션 시작 시 컨텍스트 로드)
    - [ ] save-context.sh (세션 종료 시 상태 저장)
34. [ ] settings.json에 확장 훅 등록

### Phase 10: Rules & Contexts 시스템
35. [ ] rules/ 디렉토리 생성
    - [ ] security.md (보안 규칙)
    - [ ] testing.md (테스팅 규칙)
    - [ ] git-workflow.md (Git 워크플로우)
    - [ ] coding-style.md (코딩 스타일)
    - [ ] performance.md (성능 가이드라인)
    - [ ] agent-rules.md (에이전트 사용 규칙)
36. [ ] contexts/ 디렉토리 생성
    - [ ] dev.md (개발 모드)
    - [ ] research.md (연구 모드)
    - [ ] review.md (리뷰 모드)
37. [ ] CLAUDE.md에 rules 및 contexts 참조 추가

### Phase 11: MCP 통합 (Context7)
38. [ ] mcp-configs/ 디렉토리 생성
    - [ ] context7.json (Context7 MCP 설정)
39. [ ] settings.json에 MCP 서버 등록
40. [ ] Searcher 에이전트에 Context7 연동

### Phase 12: Claude 플러그인 배포 (사용자 편의성)
41. [ ] .claude-plugin/ 디렉토리 구조 생성
    - [ ] plugin.json (플러그인 메타데이터)
    - [ ] marketplace.json (마켓플레이스 설정)
42. [ ] 설치 스크립트
    - [ ] install.sh (수동 설치용)
    - [ ] uninstall.sh (제거용)
43. [ ] 플러그인 문서화
    - [ ] README.md (설치/사용 가이드)
    - [ ] CHANGELOG.md (버전 이력)
44. [ ] GitHub Release 자동화
    - [ ] .github/workflows/release.yml
45. [ ] 마켓플레이스 등록 준비
    - [ ] 스크린샷/데모
    - [ ] 설명 문서

---

# 구현 결과

## 구현 완료 항목

### 1. 에이전트 파일 (11개) ✅

**위치:** `templates/.claude/agents/`

| 파일명 | 모델 | 역할 |
|--------|------|------|
| `maestro.md` | Opus | 사용자 대화, Intent 분류, 전체 조율 |
| `planner.md` | Opus | TODO 완료 전담, Executor 위임, 검증, Git Commit |
| `interviewer.md` | Opus | 요구사항 인터뷰, 계획 작성 |
| `plan-checker.md` | Sonnet | 계획 전 분석, 놓친 질문 확인 |
| `plan-reviewer.md` | Sonnet | 계획 검증, TDD 원칙 준수 확인 |
| `architecture.md` | Opus | 아키텍처 조언, 디버깅 지원 |
| `searcher.md` | Sonnet | 외부 문서/GitHub 검색 |
| `explorer.md` | Haiku | 내부 코드베이스 검색 |
| `image-analyst.md` | Sonnet | 이미지 분석 |
| `high-player.md` | Opus | 복잡한 작업 실행 |
| `low-player.md` | Sonnet | 간단한 작업 실행 |

### 2. 명령어 파일 (3개) ✅

**위치:** `templates/.claude/commands/`

| 파일명 | 설명 |
|--------|------|
| `start-work.md` | 개발 작업 세션 시작 |
| `tdd-cycle.md` | TDD 사이클 안내 (RED → GREEN → REFACTOR) |
| `status.md` | 현재 시스템 상태 확인 |

### 3. TDD 보호 Hook (2개) ✅

**위치:** `templates/.orchestra/hooks/`

| 파일명 | 설명 |
|--------|------|
| `tdd-guard.sh` | 테스트 파일/케이스 삭제 방지 |
| `test-logger.sh` | 테스트 결과 기록 및 TDD 메트릭 업데이트 |

### 4. 6-Stage Verification Loop (NEW) 🚧

**위치:** `templates/.orchestra/hooks/verification/`

| 파일명 | 설명 | 상태 |
|--------|------|------|
| `verification-loop.sh` | 메인 검증 오케스트레이터 | 🚧 TODO |
| `build-check.sh` | Phase 1: 빌드 검증 | 🚧 TODO |
| `type-check.sh` | Phase 2: 타입 체크 | 🚧 TODO |
| `lint-check.sh` | Phase 3: 린트 검사 | 🚧 TODO |
| `test-coverage.sh` | Phase 4: 테스트 + 커버리지 | 🚧 TODO |
| `security-scan.sh` | Phase 5: 보안 스캔 | 🚧 TODO |
| `diff-review.sh` | Phase 6: 변경사항 검토 | 🚧 TODO |
| `verification-report.sh` | 검증 리포트 생성 | 🚧 TODO |

**검증 대상 (security-scan.sh)**:
```bash
# 하드코딩된 시크릿 패턴
- API_KEY=["']?[A-Za-z0-9_-]+["']?
- sk-[A-Za-z0-9]+
- password\s*=\s*["'][^"']+["']
- secret\s*=\s*["'][^"']+["']

# 디버그 문
- console\.log\(
- console\.debug\(
- debugger;

# 민감한 파일
- .env 스테이징 여부
- credentials.json
- *.pem, *.key
```

### 4. 설정 파일 ✅

| 파일 경로 | 설명 |
|-----------|------|
| `templates/.claude/settings.json` | 에이전트 설정, 권한, Hook 등록 |
| `templates/.orchestra/config.json` | 프로젝트 설정 (언어, 테스트 러너 등) |
| `templates/.orchestra/state.json` | 상태 관리 템플릿 |
| `templates/CLAUDE.md` | 프로젝트 가이드 문서 |

### 5. TypeScript 타입 확장 ✅

**위치:** `oh-my-opencode/src/features/boulder-state/types.ts`

추가된 타입:
- `OrchestraMode` - 작업 모드 (IDLE, PLAN, EXECUTE, REVIEW)
- `IntentType` - Intent 분류 (TRIVIAL, EXPLORATORY, AMBIGUOUS, OPEN_ENDED)
- `TodoItem` - TODO 항목 정의
- `TddMetrics` - TDD 메트릭 (테스트 수, RED/GREEN 사이클 등)
- `CommitRecord` - Git 커밋 기록
- `OrchestraState` - 전체 Orchestra 상태
- `SixSectionPrompt` - Executor 위임용 6섹션 프롬프트 구조
- `PlanValidationResult` - 계획 검증 결과
- `ComplexityAssessment` - 복잡도 평가 결과
- `OrchestraConfig` - Orchestra 설정

### 6. CLI 명령어 추가 ✅

**위치:** `oh-my-opencode/src/cli/`

| 명령어 | 설명 |
|--------|------|
| `init-orchestra` | Orchestra 시스템 초기화 |
| `orchestra-status` | Orchestra 상태 확인 |
| `install` 통합 | 설치 시 Orchestra 초기화 옵션 추가 |

**새 파일:**
- `oh-my-opencode/src/cli/orchestra-init.ts` - Orchestra 초기화 로직

---

# 디렉토리 구조

## 최종 구조

```
claude-orchestra/
├── .claude-plugin/                # Claude 플러그인 배포
│   ├── plugin.json                # 플러그인 메타데이터
│   └── marketplace.json           # 마켓플레이스 설정
├── install.sh                     # 수동 설치 스크립트
├── uninstall.sh                   # 제거 스크립트
├── README.md                      # 설치/사용 가이드
├── CHANGELOG.md                   # 버전 이력
├── .github/
│   └── workflows/
│       └── release.yml            # GitHub Release 자동화
│
├── templates/                     # 설치 시 복사될 템플릿
│   ├── .claude/
│   ├── agents/                    # 12개 에이전트 정의
│   │   ├── maestro.md
│   │   ├── planner.md
│   │   ├── interviewer.md
│   │   ├── plan-checker.md
│   │   ├── plan-reviewer.md
│   │   ├── architecture.md
│   │   ├── searcher.md
│   │   ├── explorer.md
│   │   ├── image-analyst.md
│   │   ├── high-player.md
│   │   ├── low-player.md
│   │   └── code-reviewer.md       # NEW: 코드 리뷰 전문 에이전트
│   ├── commands/                  # 슬래시 명령어 (10개)
│   │   ├── start-work.md
│   │   ├── tdd-cycle.md
│   │   ├── status.md
│   │   ├── verify.md              # 검증 명령어
│   │   ├── code-review.md         # NEW: 코드 리뷰
│   │   ├── learn.md               # NEW: 패턴 학습
│   │   ├── checkpoint.md          # NEW: 상태 스냅샷
│   │   ├── e2e.md                 # NEW: E2E 테스트
│   │   ├── refactor-clean.md      # NEW: 리팩토링
│   │   ├── update-docs.md         # NEW: 문서 동기화
│   │   └── context.md             # NEW: 컨텍스트 모드 전환
│   └── settings.json              # 설정 파일
├── .orchestra/
│   ├── config.json                # 프로젝트 설정
│   ├── state.json                 # 상태 템플릿
│   ├── hooks/                     # 훅 스크립트
│   │   ├── tdd-guard.sh
│   │   ├── test-logger.sh
│   │   ├── auto-format.sh         # NEW: Prettier 자동 포맷팅
│   │   ├── git-push-review.sh     # NEW: push 전 검토
│   │   ├── load-context.sh        # NEW: 세션 시작 시 로드
│   │   ├── save-context.sh        # NEW: 세션 종료 시 저장
│   │   ├── verification/          # 6단계 검증 루프
│   │   │   ├── verification-loop.sh
│   │   │   ├── build-check.sh
│   │   │   ├── type-check.sh
│   │   │   ├── lint-check.sh
│   │   │   ├── test-coverage.sh
│   │   │   ├── security-scan.sh
│   │   │   ├── diff-review.sh
│   │   │   └── verification-report.sh
│   │   ├── learning/              # NEW: 연속 학습
│   │   │   ├── config.json
│   │   │   ├── evaluate-session.sh
│   │   │   └── learned-patterns/
│   │   └── compact/               # NEW: 전략적 컴팩션
│   │       ├── suggest-compact.sh
│   │       └── compact-config.json
│   ├── rules/                     # NEW: 상시 적용 규칙
│   │   ├── security.md
│   │   ├── testing.md
│   │   ├── git-workflow.md
│   │   ├── coding-style.md
│   │   ├── performance.md
│   │   └── agent-rules.md
│   ├── contexts/                  # NEW: 컨텍스트 모드
│   │   ├── dev.md
│   │   ├── research.md
│   │   └── review.md
│   ├── templates/                 # NEW: 템플릿
│   │   └── handoff-document.md
│   ├── mcp-configs/               # NEW: MCP 설정
│   │   └── context7.json
│   ├── plans/                     # 계획 파일 저장소
│   ├── notepads/                  # 작업 노트
│   └── logs/                      # 로그 파일
└── CLAUDE.md                      # 프로젝트 가이드
```

## 설치 방법

### 방법 1: Claude 플러그인 마켓플레이스 (권장)

```bash
# 마켓플레이스에서 추가
/plugin marketplace add picpal/claude-orchestra

# 플러그인 설치
/plugin install claude-orchestra
```

### 방법 2: 수동 설치

```bash
# 저장소 클론
git clone https://github.com/picpal/claude-orchestra.git

# 설치 스크립트 실행
cd claude-orchestra
./install.sh
```

## 생성된 파일 목록 (58개)

```
# ═══════════════════════════════════════════════════════════
# Phase 1-4: 기존 파일 (20개) ✅
# ═══════════════════════════════════════════════════════════
templates/.claude/agents/maestro.md
templates/.claude/agents/planner.md
templates/.claude/agents/interviewer.md
templates/.claude/agents/plan-checker.md
templates/.claude/agents/plan-reviewer.md
templates/.claude/agents/architecture.md
templates/.claude/agents/searcher.md
templates/.claude/agents/explorer.md
templates/.claude/agents/image-analyst.md
templates/.claude/agents/high-player.md
templates/.claude/agents/low-player.md
templates/.claude/commands/start-work.md
templates/.claude/commands/tdd-cycle.md
templates/.claude/commands/status.md
templates/.claude/settings.json
templates/.orchestra/config.json
templates/.orchestra/state.json
templates/.orchestra/hooks/tdd-guard.sh
templates/.orchestra/hooks/test-logger.sh
templates/CLAUDE.md

# ═══════════════════════════════════════════════════════════
# Phase 5: Verification Loop (9개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.claude/commands/verify.md
templates/.orchestra/hooks/verification/verification-loop.sh
templates/.orchestra/hooks/verification/build-check.sh
templates/.orchestra/hooks/verification/type-check.sh
templates/.orchestra/hooks/verification/lint-check.sh
templates/.orchestra/hooks/verification/test-coverage.sh
templates/.orchestra/hooks/verification/security-scan.sh
templates/.orchestra/hooks/verification/diff-review.sh
templates/.orchestra/hooks/verification/verification-report.sh

# ═══════════════════════════════════════════════════════════
# Phase 6: Continuous Learning (4개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.claude/commands/learn.md
templates/.orchestra/hooks/learning/config.json
templates/.orchestra/hooks/learning/evaluate-session.sh
templates/.orchestra/hooks/learning/learned-patterns/.gitkeep

# ═══════════════════════════════════════════════════════════
# Phase 7: Strategic Compact (2개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.orchestra/hooks/compact/suggest-compact.sh
templates/.orchestra/hooks/compact/compact-config.json

# ═══════════════════════════════════════════════════════════
# Phase 8: Code Review Enhancement (3개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.claude/agents/code-reviewer.md
templates/.claude/commands/code-review.md
templates/.orchestra/templates/handoff-document.md

# ═══════════════════════════════════════════════════════════
# Phase 9: 추가 명령어 및 훅 (9개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.claude/commands/checkpoint.md
templates/.claude/commands/e2e.md
templates/.claude/commands/refactor-clean.md
templates/.claude/commands/update-docs.md
templates/.claude/commands/context.md
templates/.orchestra/hooks/auto-format.sh
templates/.orchestra/hooks/git-push-review.sh
templates/.orchestra/hooks/load-context.sh
templates/.orchestra/hooks/save-context.sh

# ═══════════════════════════════════════════════════════════
# Phase 10: Rules & Contexts (9개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.orchestra/rules/security.md
templates/.orchestra/rules/testing.md
templates/.orchestra/rules/git-workflow.md
templates/.orchestra/rules/coding-style.md
templates/.orchestra/rules/performance.md
templates/.orchestra/rules/agent-rules.md
templates/.orchestra/contexts/dev.md
templates/.orchestra/contexts/research.md
templates/.orchestra/contexts/review.md

# ═══════════════════════════════════════════════════════════
# Phase 11: MCP 통합 (2개) 🚧
# ═══════════════════════════════════════════════════════════
templates/.orchestra/mcp-configs/context7.json
templates/.orchestra/mcp-configs/README.md

# ═══════════════════════════════════════════════════════════
# Phase 12: Claude 플러그인 배포 (7개) 🚧
# ═══════════════════════════════════════════════════════════
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
install.sh
uninstall.sh
README.md
CHANGELOG.md
.github/workflows/release.yml
```

**총 파일 수: 65개**

---

# 사용 방법

## 1. Orchestra 초기화
```bash
bunx oh-my-opencode init-orchestra
```

## 2. 상태 확인
```bash
bunx oh-my-opencode orchestra-status
```

## 3. 슬래시 명령어 (Claude Code 내에서)
```
/start-work        # 작업 세션 시작
/status            # 현재 상태 확인
/tdd-cycle         # TDD 사이클 안내
/verify [mode]     # 6단계 검증 루프 실행 (NEW)
```

## 4. 검증 명령어 사용법 (NEW)

```bash
# 빠른 검증 (빌드 + 타입만)
/verify quick

# 표준 검증 (빌드 + 타입 + 린트 + 테스트)
/verify standard

# 전체 검증 (6단계 모두)
/verify full

# PR 제출 전 검증 (전체 + 보안 강화)
/verify pre-pr
```

## TDD 사이클

```
     ┌─────────────┐
     │   START     │
     └──────┬──────┘
            │
            ▼
     ┌─────────────┐
     │    RED      │ ← 실패하는 테스트 작성
     │   (TEST)    │
     └──────┬──────┘
            │
            ▼
     ┌─────────────┐
     │   GREEN     │ ← 테스트 통과하는 최소 구현
     │   (IMPL)    │
     └──────┬──────┘
            │
            ▼
     ┌─────────────┐
     │  REFACTOR   │ ← 코드 개선 (테스트 유지)
     │             │
     └──────┬──────┘
            │
            └──────────────► 다음 기능
```

## 상태 관리 스키마

```json
{
  "mode": "IDLE|PLAN|EXECUTE|REVIEW",
  "currentPlan": {
    "path": ".orchestra/plans/{name}.md",
    "name": "{name}",
    "startedAt": "ISO-8601"
  },
  "todos": [{
    "id": "todo-001",
    "content": "[TEST] 테스트 내용",
    "type": "TEST",
    "status": "pending|in_progress|completed",
    "executor": "high-player|low-player",
    "sessionId": "session-123",
    "commitHash": "abc1234"
  }],
  "tddMetrics": {
    "testCount": 5,
    "redGreenCycles": 3,
    "testDeletionAttempts": 0
  },
  "commitHistory": [{
    "todoId": "todo-001",
    "hash": "abc1234",
    "message": "[TEST] 테스트 내용",
    "timestamp": "ISO-8601",
    "files": ["tests/auth/login.test.ts"],
    "tddPhase": "RED"
  }],

  "verificationMetrics": {
    "lastRun": "ISO-8601",
    "mode": "quick|standard|full|pre-pr",
    "duration": 12500,
    "results": {
      "build": { "status": "pass", "duration": 3200 },
      "types": { "status": "pass", "errors": 0, "warnings": 2 },
      "lint": { "status": "warn", "errors": 0, "warnings": 5 },
      "tests": {
        "status": "pass",
        "passed": 47,
        "failed": 0,
        "skipped": 2,
        "coverage": {
          "lines": 84.5,
          "branches": 78.2,
          "functions": 91.0,
          "statements": 83.8
        }
      },
      "security": {
        "status": "pass",
        "issues": []
      },
      "diff": {
        "status": "pass",
        "filesChanged": 5,
        "unexpectedChanges": []
      }
    },
    "prReady": true,
    "blockers": []
  }
}
```

## Git Commit 자동화

TODO 완료 시 Planner가 자동 커밋:

```
[TEST] 로그인 실패 테스트 추가

- 변경 파일: tests/auth/login.test.ts
- TDD Phase: RED

TODO: todo-001
Plan: auth-feature
```

---

## 6-Stage Verification Loop 상세 (NEW)

### 개요

Everything Claude Code의 Verification Loop를 Claude Orchestra에 통합하여 코드 품질을 체계적으로 보장합니다.

### Phase별 상세 스펙

#### Phase 1: Build Verification

```bash
#!/bin/bash
# build-check.sh

# 패키지 매니저 감지
if [ -f "package-lock.json" ]; then
  PM="npm"
elif [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
elif [ -f "bun.lockb" ]; then
  PM="bun"
fi

# 빌드 실행
$PM run build 2>&1

# 실패 시 즉시 중단
if [ $? -ne 0 ]; then
  echo "❌ BUILD FAILED - Verification stopped"
  exit 1
fi

echo "✅ Build passed"
```

#### Phase 2: Type Check

```bash
#!/bin/bash
# type-check.sh

# TypeScript 프로젝트 확인
if [ -f "tsconfig.json" ]; then
  npx tsc --noEmit --strict 2>&1

  if [ $? -ne 0 ]; then
    echo "❌ TYPE CHECK FAILED"
    exit 1
  fi

  echo "✅ Type check passed"
else
  echo "⏭️ Skipped (no tsconfig.json)"
fi
```

#### Phase 3: Lint Check

```bash
#!/bin/bash
# lint-check.sh

# ESLint 실행 (경고도 에러 취급)
npx eslint . --max-warnings=0 2>&1

if [ $? -ne 0 ]; then
  echo "❌ LINT CHECK FAILED"
  exit 1
fi

echo "✅ Lint check passed"
```

#### Phase 4: Test + Coverage

```bash
#!/bin/bash
# test-coverage.sh

MIN_COVERAGE=80

# 테스트 + 커버리지 실행
$PM test -- --coverage --coverageReporters=json-summary 2>&1

if [ $? -ne 0 ]; then
  echo "❌ TESTS FAILED"
  exit 1
fi

# 커버리지 확인
COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')

if (( $(echo "$COVERAGE < $MIN_COVERAGE" | bc -l) )); then
  echo "❌ COVERAGE FAILED: ${COVERAGE}% < ${MIN_COVERAGE}%"
  exit 1
fi

echo "✅ Tests passed (Coverage: ${COVERAGE}%)"
```

#### Phase 5: Security Scan

```bash
#!/bin/bash
# security-scan.sh

ISSUES=0

# 하드코딩된 시크릿 검사
echo "Scanning for hardcoded secrets..."

# API 키 패턴
grep -rn --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" \
  -E "(API_KEY|api_key|apiKey)\s*[=:]\s*['\"][^'\"]+['\"]" src/ && ISSUES=$((ISSUES+1))

# sk- 패턴 (OpenAI 등)
grep -rn --include="*.ts" --include="*.js" \
  -E "sk-[A-Za-z0-9]{20,}" src/ && ISSUES=$((ISSUES+1))

# password 패턴
grep -rn --include="*.ts" --include="*.js" \
  -E "password\s*[=:]\s*['\"][^'\"]+['\"]" src/ && ISSUES=$((ISSUES+1))

# console.log 검사
echo "Scanning for debug statements..."
grep -rn --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" \
  "console\.log\|console\.debug\|debugger" src/ && ISSUES=$((ISSUES+1))

# .env 스테이징 확인
if git diff --cached --name-only | grep -q "\.env"; then
  echo "⚠️ WARNING: .env file is staged!"
  ISSUES=$((ISSUES+1))
fi

if [ $ISSUES -gt 0 ]; then
  echo "❌ SECURITY SCAN FAILED: $ISSUES issues found"
  exit 1
fi

echo "✅ Security scan passed"
```

#### Phase 6: Diff Review

```bash
#!/bin/bash
# diff-review.sh

# 변경된 파일 목록
CHANGED_FILES=$(git diff --name-only HEAD)
CHANGED_COUNT=$(echo "$CHANGED_FILES" | wc -l)

echo "Changed files: $CHANGED_COUNT"
echo "$CHANGED_FILES"

# TODO 범위 확인 (state.json에서 현재 TODO의 예상 파일 목록 비교)
# 범위 외 파일 수정 경고

# 의도치 않은 파일 변경 확인
UNEXPECTED=""
for file in $CHANGED_FILES; do
  # package-lock.json 등 자동 생성 파일 제외
  if [[ "$file" == *"lock"* ]] || [[ "$file" == *".log"* ]]; then
    continue
  fi

  # 예상 범위 외 파일 확인 (TODO의 EXPECTED OUTCOME과 비교)
  # ...
done

if [ -n "$UNEXPECTED" ]; then
  echo "⚠️ WARNING: Unexpected file changes detected"
  echo "$UNEXPECTED"
fi

echo "✅ Diff review completed"
```

### Verification Report 예시

```
╔═══════════════════════════════════════════════════════════════╗
║                   VERIFICATION REPORT                          ║
║                   Mode: full | 2026-01-25 10:30:00            ║
╠═══════════════════════════════════════════════════════════════╣
║  Phase 1: Build         ✅ PASS          (3.2s)               ║
║  Phase 2: Type Check    ✅ PASS          (1.8s)               ║
║  Phase 3: Lint          ⚠️ 5 warnings    (2.1s)               ║
║  Phase 4: Tests         ✅ 47/47 passed  (8.5s)               ║
║           Coverage      ✅ 84.5%                              ║
║  Phase 5: Security      ✅ No issues     (0.8s)               ║
║  Phase 6: Diff Review   ✅ 5 files       (0.3s)               ║
╠═══════════════════════════════════════════════════════════════╣
║  Total Duration: 16.7s                                         ║
║  PR Ready: ✅ YES                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

### Planner 통합

Planner가 TODO 완료 시 자동으로 Verification Loop 실행:

```markdown
## TODO 완료 검증 프로세스

1. Executor가 TODO 완료 보고
2. Planner가 6-Stage Verification Loop 실행
   - mode: standard (기본) 또는 full (PR 전)
3. 검증 결과 확인
   - PR Ready: YES → Git Commit 진행
   - PR Ready: NO → Executor에게 수정 요청
4. state.json에 verificationMetrics 업데이트
```

### 권장 실행 주기

| 시점 | 모드 | 설명 |
|------|------|------|
| TODO 완료 시 | standard | 빌드/타입/린트/테스트 |
| 커밋 전 | full | 전체 6단계 |
| PR 제출 전 | pre-pr | 전체 + 보안 강화 |
| 15분마다 (장시간 작업) | quick | 빌드/타입만 |

---

## Continuous Learning 상세 설계

### 개요

세션 종료 시 대화에서 재사용 가능한 패턴을 자동으로 추출하여 스킬 파일로 저장합니다.

### config.json

```json
{
  "min_session_length": 10,
  "extraction_threshold": "medium",
  "auto_approve": false,
  "learned_skills_path": ".orchestra/hooks/learning/learned-patterns/",

  "pattern_categories": [
    "error_resolution",
    "user_corrections",
    "workarounds",
    "debugging_techniques",
    "project_specific"
  ],

  "exclusions": [
    "simple_typos",
    "one_time_fixes",
    "external_api_issues"
  ]
}
```

### evaluate-session.sh

```bash
#!/bin/bash
# 세션 종료 시 실행 (Stop Hook)

CONFIG_DIR="$(dirname "$0")"
CONFIG_FILE="$CONFIG_DIR/config.json"
PATTERNS_DIR="$CONFIG_DIR/learned-patterns"

# 최소 세션 길이 확인
MIN_LENGTH=$(jq -r '.min_session_length' "$CONFIG_FILE")
# ... 세션 평가 로직

echo "🎓 Session evaluated. Patterns extracted: $EXTRACTED_COUNT"
```

### 저장되는 패턴 파일 예시

```markdown
# Pattern: TypeScript Null Check

## Category
error_resolution

## Problem
`Object is possibly 'undefined'` 에러 발생

## Solution
Optional chaining과 nullish coalescing 사용

## Code Example
\`\`\`typescript
// Before
const name = user.profile.name;

// After
const name = user?.profile?.name ?? 'Unknown';
\`\`\`

## Trigger Keywords
- TS2532
- Object is possibly
- undefined
```

---

## Strategic Compact 상세 설계

### 개요

논리적 경계에서 의도적으로 컨텍스트를 압축하여 토큰 효율성을 높입니다.

### compact-config.json

```json
{
  "thresholds": {
    "toolCalls": 50,
    "reminderInterval": 25
  },
  "autoSuggestOnPhaseChange": true,
  "phaseTransitions": [
    { "from": "RESEARCH", "to": "PLAN", "suggest": true },
    { "from": "PLAN", "to": "EXECUTE", "suggest": true },
    { "from": "EXECUTE", "to": "REVIEW", "suggest": false }
  ]
}
```

### suggest-compact.sh

```bash
#!/bin/bash
# PreToolUse Hook (Edit|Write 매처)

COUNTER_FILE="/tmp/claude_orchestra_tool_count"
CONFIG_FILE=".orchestra/hooks/compact/compact-config.json"

# 카운터 증가
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
  COUNT=$((COUNT + 1))
else
  COUNT=1
fi
echo $COUNT > "$COUNTER_FILE"

# 임계값 확인
THRESHOLD=$(jq -r '.thresholds.toolCalls' "$CONFIG_FILE")
REMINDER=$(jq -r '.thresholds.reminderInterval' "$CONFIG_FILE")

if [ $COUNT -eq $THRESHOLD ]; then
  echo "🗜️ 컴팩션 권장: $COUNT회 도구 호출. 논리적 경계에서 /compact 실행을 고려하세요."
elif [ $COUNT -gt $THRESHOLD ] && [ $(( (COUNT - THRESHOLD) % REMINDER )) -eq 0 ]; then
  echo "🗜️ 리마인더: $COUNT회 도구 호출. 컴팩션을 고려하세요."
fi
```

### Phase 전환 시 자동 제안

```
[Phase 1: Research] ─────────────────────────┐
  Explorer, Searcher 작업                    │
└────────────────────────────────────────────┘
                    ↓
        🗜️ "탐색 완료. 컨텍스트 압축 권장"
                    ↓
[Phase 2A: Planning] ────────────────────────┐
  Interviewer, Plan-Checker 작업             │
└────────────────────────────────────────────┘
                    ↓
        🗜️ "계획 완료. 컨텍스트 압축 권장"
                    ↓
[Phase 2B: Execution] ───────────────────────┐
  High/Low Player 작업                       │
└────────────────────────────────────────────┘
```

---

## Code Reviewer 에이전트 상세 설계

### code-reviewer.md

```markdown
# Code Reviewer Agent

## Model
Sonnet

## 역할
코드 변경사항에 대한 심층 리뷰 수행 (25+ 차원 평가)

## 리뷰 카테고리

### Security (Critical)
- 하드코딩된 자격증명
- SQL 인젝션
- XSS 취약점
- 입력 검증 누락
- 안전하지 않은 암호화

### Code Quality (High)
- 함수 크기 (50줄 초과 경고)
- 파일 크기 (800줄 초과 경고)
- 중첩 깊이 (3단계 초과 경고)
- 에러 핸들링 누락
- 매직 넘버/스트링
- 미사용 코드

### Performance (Medium)
- 알고리즘 복잡도 (O(n²) 이상 경고)
- 불필요한 리렌더링 (React)
- N+1 쿼리 패턴
- 메모리 누수 패턴

### Best Practices (Low)
- 네이밍 컨벤션
- 문서화 누락
- 접근성 (a11y)
- 테스트 커버리지

## 승인 레벨
| 상태 | 조건 |
|------|------|
| ✅ Approve | Critical/High 이슈 없음 |
| ⚠️ Warning | Medium 이슈만 존재 |
| ❌ Block | Critical/High 이슈 존재 |

## 출력 형식
\`\`\`markdown
## Code Review Report

### Summary
- Files Reviewed: 5
- Result: ⚠️ Warning
- Issues: 0 Critical, 0 High, 3 Medium, 2 Low

### Issues

#### [Medium] src/auth/login.ts:45
**Pattern**: 함수 크기 초과
**Description**: `handleLogin` 함수가 67줄입니다.
**Suggestion**: 로직을 헬퍼 함수로 분리하세요.

...
\`\`\`
```

---

## 핸드오프 문서 템플릿

### handoff-document.md

```markdown
## HANDOFF DOCUMENT

### Meta
- **From**: {source-agent}
- **To**: {target-agent}
- **Timestamp**: {ISO-8601}
- **Session**: {session-id}

---

## 1. SUMMARY
{이전 에이전트가 수행한 작업 1-2문장 요약}

## 2. FINDINGS
- 발견사항 1
- 발견사항 2
- 발견사항 3

## 3. CONTEXT FILES
| 파일 | 역할 |
|------|------|
| `src/auth/login.ts` | 인증 로직 |
| `tests/auth/login.test.ts` | 관련 테스트 |

## 4. DECISIONS MADE
- 결정 1: {이유}
- 결정 2: {이유}

## 5. OPEN QUESTIONS
- [ ] 미해결 질문 1
- [ ] 미해결 질문 2

## 6. RECOMMENDATIONS
{다음 에이전트를 위한 권장사항}

## 7. ARTIFACTS
- 노트패드: `.orchestra/notepads/{session-id}/`
- 계획: `.orchestra/plans/{plan-name}.md`
```

---

## Rules 상세 설계

### security.md

```markdown
# Security Rules

## 8가지 필수 체크
1. **하드코딩된 시크릿 방지**: API 키, 비밀번호는 환경변수 사용
2. **입력 검증**: 모든 사용자 입력은 Zod 등으로 검증
3. **SQL 인젝션 완화**: Parameterized query 사용
4. **XSS 보호**: innerHTML 대신 textContent 사용
5. **CSRF 방어**: 상태 변경 요청에 CSRF 토큰 필수
6. **인증 검증**: 모든 보호된 라우트에 인증 미들웨어
7. **레이트 리미팅**: API 엔드포인트에 rate limit 적용
8. **안전한 에러 핸들링**: 스택 트레이스 노출 금지

## 인시던트 대응
1. 작업 즉시 중단
2. Security Scan 재실행
3. 크리티컬 취약점 우선 해결
4. 자격증명 손상 시 즉시 교체
```

### testing.md

```markdown
# Testing Rules

## 커버리지 요구사항
| 코드 유형 | 최소 커버리지 |
|-----------|---------------|
| 일반 코드 | 80% |
| 금융/결제 로직 | 100% |
| 인증/보안 로직 | 100% |
| 핵심 비즈니스 로직 | 100% |

## 테스트 유형
- **Unit**: 격리된 함수/컴포넌트 (Jest/Vitest)
- **Integration**: API/DB 작업
- **E2E**: Playwright 사용자 플로우

## TDD 워크플로우
1. 테스트 작성 (RED)
2. 실패 확인
3. 최소 코드 구현 (GREEN)
4. 성공 검증
5. 리팩토링 (REFACTOR)
6. 커버리지 확인
```

---

## Contexts 상세 설계

### dev.md

```markdown
# Development Context

## 핵심 원칙
1. "Write code first, explain after"
2. "Prefer working solutions over perfect solutions"
3. 코드 변경 후 테스트 실행
4. 원자적 커밋 구조 유지

## 우선순위
1위: 기능성 (Functionality)
2위: 정확성 (Correctness)
3위: 코드 품질 (Code Quality)

## 권장 도구
- Edit/Write: 코드 수정
- Bash: 테스트/빌드
- Grep/Glob: 코드 탐색
```

### research.md

```markdown
# Research Context

## 핵심 원칙
1. "Explore before implementing"
2. "Document findings as you go"
3. 여러 접근 방식 비교
4. 트레이드오프 문서화

## 우선순위
1위: 이해도 (Understanding)
2위: 완전성 (Completeness)
3위: 정확성 (Accuracy)

## 권장 도구
- Grep/Glob: 코드 탐색
- Read: 파일 읽기
- WebSearch: 외부 문서 검색
```

### review.md

```markdown
# Review Context

## 핵심 원칙
1. "Quality over speed"
2. "Every issue matters"
3. 보안 이슈 최우선
4. 구체적인 개선안 제시

## 우선순위
1위: 보안 (Security)
2위: 정확성 (Correctness)
3위: 성능 (Performance)

## 권장 도구
- Read: 코드 읽기
- Grep: 패턴 검색
- Bash: 린트/테스트 실행
```

---

## MCP 통합 (Context7)

### context7.json

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@anthropic/context7-mcp"],
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      },
      "description": "실시간 문서 조회 및 코드 컨텍스트 제공"
    }
  },
  "usage": {
    "maxActiveServers": 10,
    "contextWindowWarning": "MCP 과다 활성화 시 컨텍스트 윈도우 200k → 70k 감소 가능"
  }
}
```

### Searcher 에이전트 연동

```markdown
## Context7 활용

Searcher 에이전트는 Context7 MCP를 통해:
1. 최신 라이브러리 문서 실시간 조회
2. API 변경사항 확인
3. 베스트 프랙티스 검색
4. 코드 예제 수집

### 사용 예시
- "React 19 새로운 훅 문서 조회"
- "Next.js 15 App Router 변경사항"
- "TypeScript 5.x 새 기능"
```

---

---

## Claude 플러그인 배포 상세 설계

### 개요

사용자가 쉽게 설치하고 사용할 수 있도록 Claude 플러그인 마켓플레이스를 통한 배포를 지원합니다.

### plugin.json

```json
{
  "name": "claude-orchestra",
  "version": "1.0.0",
  "description": "12개 전문 에이전트 기반 TDD 개발 오케스트레이션 시스템",
  "author": "picpal",
  "license": "MIT",
  "repository": "https://github.com/picpal/claude-orchestra",

  "keywords": [
    "claude-code",
    "tdd",
    "multi-agent",
    "orchestration",
    "code-review",
    "verification"
  ],

  "components": {
    "agents": 12,
    "commands": 10,
    "hooks": 15,
    "rules": 6,
    "contexts": 3
  },

  "features": [
    "TDD 강제 (80%+ 커버리지)",
    "6단계 검증 루프",
    "연속 학습 시스템",
    "전략적 컴팩션",
    "자동 Git Commit",
    "Intent 분류",
    "계획 검증 (Plan-Checker/Reviewer)"
  ],

  "requirements": {
    "claude-code": ">=1.0.0"
  }
}
```

### marketplace.json

```json
{
  "listing": {
    "title": "Claude Orchestra",
    "subtitle": "Multi-Agent TDD Development System",
    "category": "Development",
    "tags": ["tdd", "agents", "workflow", "code-quality"]
  },

  "assets": {
    "icon": "assets/icon.png",
    "banner": "assets/banner.png",
    "screenshots": [
      "assets/screenshot-flow.png",
      "assets/screenshot-verification.png",
      "assets/screenshot-learning.png"
    ]
  },

  "pricing": {
    "type": "free"
  }
}
```

### install.sh

```bash
#!/bin/bash
# Claude Orchestra 설치 스크립트

set -e

INSTALL_DIR="$HOME/.claude"
ORCHESTRA_DIR=".orchestra"

echo "🎼 Claude Orchestra 설치 중..."

# 1. 디렉토리 생성
echo "📁 디렉토리 생성..."
mkdir -p "$INSTALL_DIR/agents"
mkdir -p "$INSTALL_DIR/commands"
mkdir -p "$ORCHESTRA_DIR/hooks/verification"
mkdir -p "$ORCHESTRA_DIR/hooks/learning/learned-patterns"
mkdir -p "$ORCHESTRA_DIR/hooks/compact"
mkdir -p "$ORCHESTRA_DIR/rules"
mkdir -p "$ORCHESTRA_DIR/contexts"
mkdir -p "$ORCHESTRA_DIR/mcp-configs"
mkdir -p "$ORCHESTRA_DIR/templates"
mkdir -p "$ORCHESTRA_DIR/plans"
mkdir -p "$ORCHESTRA_DIR/notepads"
mkdir -p "$ORCHESTRA_DIR/logs"

# 2. 에이전트 복사
echo "🤖 에이전트 설치..."
cp -r templates/.claude/agents/* "$INSTALL_DIR/agents/"

# 3. 명령어 복사
echo "📝 명령어 설치..."
cp -r templates/.claude/commands/* "$INSTALL_DIR/commands/"

# 4. 훅 복사
echo "🪝 훅 설치..."
cp -r templates/.orchestra/hooks/* "$ORCHESTRA_DIR/hooks/"
chmod +x "$ORCHESTRA_DIR/hooks/"*.sh
chmod +x "$ORCHESTRA_DIR/hooks/verification/"*.sh
chmod +x "$ORCHESTRA_DIR/hooks/learning/"*.sh
chmod +x "$ORCHESTRA_DIR/hooks/compact/"*.sh

# 5. Rules & Contexts 복사
echo "📋 규칙 및 컨텍스트 설치..."
cp -r templates/.orchestra/rules/* "$ORCHESTRA_DIR/rules/"
cp -r templates/.orchestra/contexts/* "$ORCHESTRA_DIR/contexts/"

# 6. 설정 파일 복사
echo "⚙️ 설정 파일 설치..."
cp templates/.claude/settings.json "$INSTALL_DIR/settings.json"
cp templates/.orchestra/config.json "$ORCHESTRA_DIR/config.json"
cp templates/.orchestra/state.json "$ORCHESTRA_DIR/state.json"

# 7. MCP 설정 복사
echo "🔌 MCP 설정 설치..."
cp -r templates/.orchestra/mcp-configs/* "$ORCHESTRA_DIR/mcp-configs/"

# 8. CLAUDE.md 복사
echo "📖 CLAUDE.md 설치..."
cp templates/CLAUDE.md ./CLAUDE.md

echo ""
echo "✅ Claude Orchestra 설치 완료!"
echo ""
echo "사용 방법:"
echo "  /start-work    - 작업 세션 시작"
echo "  /status        - 현재 상태 확인"
echo "  /tdd-cycle     - TDD 사이클 안내"
echo "  /verify        - 검증 루프 실행"
echo "  /code-review   - 코드 리뷰"
echo "  /learn         - 패턴 학습"
echo ""
```

### uninstall.sh

```bash
#!/bin/bash
# Claude Orchestra 제거 스크립트

set -e

INSTALL_DIR="$HOME/.claude"
ORCHESTRA_DIR=".orchestra"

echo "🎼 Claude Orchestra 제거 중..."

# 에이전트 제거
AGENTS=(maestro planner interviewer plan-checker plan-reviewer
        architecture searcher explorer image-analyst
        high-player low-player code-reviewer)
for agent in "${AGENTS[@]}"; do
  rm -f "$INSTALL_DIR/agents/$agent.md"
done

# 명령어 제거
COMMANDS=(start-work tdd-cycle status verify code-review
          learn checkpoint e2e refactor-clean update-docs context)
for cmd in "${COMMANDS[@]}"; do
  rm -f "$INSTALL_DIR/commands/$cmd.md"
done

# Orchestra 디렉토리 제거 (사용자 확인)
read -p "⚠️ .orchestra 디렉토리를 삭제하시겠습니까? (plans, notepads 포함) [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$ORCHESTRA_DIR"
  echo "🗑️ .orchestra 디렉토리 삭제됨"
else
  echo "📁 .orchestra 디렉토리 유지됨"
fi

echo ""
echo "✅ Claude Orchestra 제거 완료!"
```

### .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            templates/**/*
            install.sh
            uninstall.sh
          generate_release_notes: true
```

### 버전 관리 전략

```
v1.0.0 - 초기 릴리스
├── 12개 에이전트
├── 10개 명령어
├── 6단계 Verification Loop
├── Continuous Learning
├── Strategic Compact
├── Rules & Contexts
└── MCP (Context7)

v1.1.0 - 추가 기능 (예정)
├── 추가 에이전트 (e2e-runner, doc-updater)
├── 추가 MCP 서버
└── 성능 최적화
```

---

*생성일: 2026-01-25*
*업데이트: 2026-01-25 - 6-Stage Verification Loop 추가*
*업데이트: 2026-01-25 - Continuous Learning, Strategic Compact, Code Review, Rules, Contexts, MCP 추가*
*업데이트: 2026-01-25 - Claude 플러그인 배포 시스템 추가*
