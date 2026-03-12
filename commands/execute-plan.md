# /execute-plan — 계획 실행 (Phase 4-7)

> ⚡ **자동 실행 선언**: Planner 완료 직후 이 흐름을 즉시 시작합니다. 사용자 지시를 기다리지 마세요.

## 사전 조건 체크리스트

실행 전 반드시 확인:
- [ ] `planningPhase.interviewerCompleted = true` (state.json)
- [ ] `planningPhase.plannerCompleted = true` (state.json)
- [ ] Plan file: `.orchestra/plans/{name}.md` 존재
- [ ] Planner Analysis Report 완료 (JSON 블록 포함)

⚠️ 하나라도 미충족 시 `phase-gate.sh`가 Executor 호출을 차단합니다.

---

## Step 1: JSON 블록 추출 — Planner 완료 직후

Planner Analysis Report에서 JSON 블록을 파싱합니다:

```json
{
  "levels": [
    {"level": 0, "todoCount": 3, "parallelSafe": true, "todos": [...]},
    {"level": 1, "todoCount": 1, "parallelSafe": false, "todos": [...]}
  ]
}
```

## Step 2: Level별 실행 (Phase 4) — Step 1 직후

```
for each level in levels:
  IF todoCount >= 2 AND parallelSafe:
    → 한 메시지에 여러 Task() 병렬 호출
    예: Task(High-Player: auth-002) + Task(Low-Player: auth-001)
  ELSE:
    → 단일 Task() 호출
  모든 Task 완료 → 다음 Level
```

각 TODO의 6-Section prompt를 해당 Executor Task에 전달합니다.

## Step 3: Conflict Check (Phase 5 — 조건부) — Level 완료 후

- **실행 조건**: Level 중 todoCount >= 2 또는 Level 2개 이상
- **Skip 조건**: 단일 Level, 단일 TODO (순차 실행)
- 실행 시: Task(Conflict-Checker) → 충돌 발견 시 Rework Loop

## Step 4: Verification (Phase 6) — 모든 Level 완료 후

```bash
.orchestra/hooks/verification/verification-loop.sh full
```

6-Stage: Build → Type Check → Lint → Tests → Security Scan → Diff Review

## Step 5: Code-Review Group (Phase 6a-CR) — Verification 통과 후

5명 **동시** 병렬 호출 (한 메시지에 5개 Task):

| 팀원 | 모델 | 가중치 |
|------|------|--------|
| Security Guardian | sonnet | 4 |
| Quality Inspector | sonnet | 3 |
| Performance Analyst | haiku | 2 |
| Standards Keeper | haiku | 2 |
| TDD Enforcer | sonnet | 4 |

호출 패턴: `rules/call-templates.md` 참조

**가중치 점수 계산:**
```
weighted_score = (4*Security + 3*Quality + 2*Performance + 2*Standards + 4*TDD) / 15
```

## Step 6: 판정 → 다음 행동 — Code-Review 완료 후

| 결과 | 행동 |
|------|------|
| Approved (>= 0.80) | → Step 7로 즉시 진행 |
| Warning (0.50-0.79) | → 경고 기록 후 Step 7로 진행 |
| Block (< 0.50 또는 Auto-Block) | → Rework Loop (최대 3회) |

**Auto-Block 조건**: Security Critical 이슈 또는 테스트 삭제 감지

## Step 7: Commit + Journal (Phase 7) — Approved/Warning 시

1. `git commit` (TODO 단위, 형식 준수 — maestro-protocol.md Git Commit 형식 참조)
2. `Task(Journal-Reporter)` 호출 — 아래 컨텍스트 전달:
   - `journalType`: `open-ended` 또는 `session`
   - `planName`, `todos`, `verificationResult`, `codeReviewResult`
   - `changedFiles`, `summary`, `decisions`, `issues`, `nextSteps`
3. `journal-tracker.sh`가 Journal-Reporter의 Write를 감지하여 `state.json` 자동 업데이트

---

## 관련 명령어

- `/verify` — 검증 루프만 실행
- `/code-review` — 코드 리뷰만 실행
- `/status` — 현재 상태 확인
- `/after-plan-mode` — Plan Mode 종료 후 자동화 (이 명령어의 선행 단계)
