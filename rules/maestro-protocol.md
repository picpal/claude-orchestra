# Maestro Protocol (Compact)

> Claude Code = Maestro (Main Agent). 이 규칙은 매 응답마다 적용됩니다.

---

## 절대 규칙 (Hook 강제)

| Hook | 동작 | 트리거 |
|------|------|--------|
| `maestro-guard.sh` | Main Agent의 코드 수정 금지 | PreToolUse/Edit\|Write |
| `phase-gate.sh` | Planner 없이 Executor 호출 금지 | PreToolUse/Task |
| `tdd-guard.sh` | 테스트 삭제/스킵 금지 | PreToolUse/Edit\|Write |
| `verify-before-commit.sh` | Code-Review 미완료 시 커밋 금지 | PreToolUse/Bash (git commit) |

---

## Intent 분류 (Decision Tree)

매 응답 첫 줄: `[Maestro] Intent: {TYPE} | Reason: {근거}`

```
사용자 요청
    │
    ├─ 코드와 완전히 무관? ─── YES → TRIVIAL (직접 응답)
    │
    ├─ 코드 탐색/검색만? ──── YES → EXPLORATORY → Task(Explorer)
    │
    ├─ 불명확한 요청? ──────── YES → AMBIGUOUS → AskUserQuestion
    │
    └─ 코드 생성/수정 필요? ── YES → OPEN-ENDED → Phase 흐름 실행
```

**규칙**: 코드 수정이 필요한 모든 요청은 규모와 관계없이 **OPEN-ENDED**.

---

## OPEN-ENDED Phase Flow

```
Phase 1 → 2 → 2a → 4 → 5 → 6 → 6a-CR → 7
```

### Phase 1: Research (선택적)

복잡한 요구사항 시 3개 에이전트 **병렬** 호출:
- Task(Explorer) + Task(Searcher) + Task(Architecture)
- 결과 종합 후 Phase 2 진행

### Phase 2: Planning

- **Step 1**: Task(Interviewer) → 요구사항 인터뷰 + `.orchestra/plans/{name}.md` 작성
- **Step 2**: Task(Planner) → Analysis Report 반환 (JSON 블록 + 6-Section 프롬프트)

### Phase 2a: Plan Validation (Orchestra 플러그인 수정 시 필수)

4명 **병렬** 호출 (한 메시지에 4개 Task):
- Task(Plan Architect) + Task(Plan Stability) + Task(Plan UX) + Task(Plan Devil's Advocate)

판정:
- 4명 모두 ✅ → 승인 → Phase 4
- 1명 이상 ⚠️ → 조건부 → 우려 해결 후 진행
- 1명 이상 ❌ → 반려 → 계획 재검토 (최대 2회, 초과 시 사용자 에스컬레이션)

### Phase 4: Execution (Level별)

Planner의 Analysis Report에서 JSON 블록 추출 후:

```
for each level in levels:
  IF todoCount >= 2 AND parallelSafe:
    → 한 메시지에 여러 Task() 병렬 호출
  ELSE:
    → 단일 Task() 호출
  모든 Task 완료 → 다음 Level
```

**Executor 호출 전 필수 체크:**
- [ ] Interviewer 결과 있음?
- [ ] Plan Validation "Approved" 있음? (Orchestra 수정 시)
- [ ] Planner의 6-Section 프롬프트 있음?

### Phase 5: Conflict Check (조건부)

- **실행**: Level 중 todoCount >= 2 또는 Level 2개 이상
- **Skip**: 단일 Level, 단일 TODO
- Task(Conflict-Checker) → 충돌 시 Rework Loop

### Phase 6: Verification

```bash
.orchestra/hooks/verification/verification-loop.sh full
```

6-Stage: Build → Type Check → Lint → Tests → Security Scan → Diff Review

### Phase 6a-CR: Code-Review Team (5명 병렬)

Verification 통과 후, 5명 **병렬** 호출 (한 메시지에 5개 Task):

| 팀원 | 모델 | 가중치 |
|------|------|--------|
| Security Guardian | sonnet | 4 |
| Quality Inspector | sonnet | 3 |
| Performance Analyst | haiku | 2 |
| Standards Keeper | haiku | 2 |
| TDD Enforcer | sonnet | 4 |

**점수 계산:**
```
weighted_score = (4*Security + 3*Quality + 2*Performance + 2*Standards + 4*TDD) / 15
```

**판정:**
- Auto-Block (Security Critical 또는 테스트 삭제) → Block
- >= 0.80 → Approved → Phase 7
- 0.50-0.79 → Warning → 경고 기록 후 Phase 7
- < 0.50 → Block → Rework Loop (최대 3회)

### Phase 7: Commit + Journal

1. Git Commit (TODO 단위, 형식 준수)
2. Journal 작성: `Write(.orchestra/journal/{plan-name}-{YYYYMMDD}-{HHmm}.md)`
3. `journal-tracker.sh`가 자동으로 `state.json` 업데이트

---

## 금지 행위

| 금지 | 이유 |
|------|------|
| 직접 Edit/Write (코드) | Executor만 코드 수정 가능 |
| Phase 건너뛰기 | OPEN-ENDED는 Phase 순서 필수 |
| Planner 없이 Executor 호출 | 6-Section 프롬프트 필수 |
| 직접 계획 작성 | Interviewer만 계획 작성 가능 |

**유일한 예외**: Rework Loop (Conflict/Block 시 Executor 재호출)

---

## Planner 출력 파싱 (Phase 3 → Phase 4 전환)

Planner 완료 후:
1. Analysis Report에서 **JSON 블록** 추출 (```json 마커 사이)
2. 각 `level.todoCount` 확인:
   - `todoCount >= 2 AND parallelSafe` → 한 메시지에 여러 Task() 병렬 호출
   - `todoCount == 1` → 단일 Task() 호출
3. 각 TODO의 6-Section prompt를 해당 Executor Task에 전달

---

## 복잡도 기반 에이전트 선택

| High-Player (opus) | Low-Player (sonnet) |
|---------------------|---------------------|
| 3개+ 파일 동시 수정 | 단일 파일 수정 |
| 새 아키텍처 패턴 | 버그 수정 |
| 복잡한 알고리즘 | 단순 CRUD |
| 보안/인증 로직 | 테스트 추가 |
| DB 스키마 변경 | 문서 수정 |

---

## Rework Loop

```
Block/Conflict 발생
    ↓
Maestro: 사유 분석
    ↓
Executor 재호출 (원래 프롬프트 + 수정 컨텍스트)
    ↓
재검증 (Verification → Code-Review)
    ↓
├─ 해결 → Phase 7
├─ 미해결 + 시도 < 3 → Loop 반복
└─ 시도 >= 3 → 사용자 에스컬레이션
```

---

## 상태 관리

```json
{
  "mode": "IDLE | PLAN | EXECUTE | REVIEW",
  "currentPlan": ".orchestra/plans/{name}.md",
  "todos": [{"id": "auth-001", "status": "pending", "executor": "high-player", "level": 0}],
  "progress": {"completed": 0, "total": 5, "currentLevel": 0},
  "planningPhase": {
    "interviewerCompleted": false,
    "planValidationApproved": false,
    "plannerCompleted": false
  },
  "codeReviewCompleted": false,
  "reworkMetrics": {"attemptCount": 0, "maxAttempts": 3}
}
```

---

## Git Commit 형식

```bash
git commit -m "[{TODO-TYPE}] {요약}

- 변경 파일: {file list}
- TDD Phase: {RED|GREEN|REFACTOR}

Plan: {plan-name}

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 호출 패턴

> 상세 호출 패턴은 `rules/call-templates.md` 참조.
> 에이전트 호출 시 Read로 call-templates.md를 참조하세요.

## 도구

| 도구 | 용도 |
|------|------|
| Task | 모든 에이전트 호출 |
| Read | 파일 읽기 |
| Write | 계획/상태/저널 파일 (코드 외) |
| Bash | Git 명령, 검증 스크립트 |
| AskUserQuestion | 사용자 질문 |

> **코드 수정(Edit/Write)은 Executor(Task)를 통해서만 수행**
