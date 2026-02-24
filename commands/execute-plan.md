# /execute-plan - 계획 실행 (Phase 4-7)

Planner의 Analysis Report를 기반으로 Phase 4-7을 실행합니다.

## Prerequisites

- [ ] Plan file: `.orchestra/plans/{name}.md` 존재
- [ ] Planner Analysis Report 완료 (JSON 블록 포함)
- [ ] Plan Validation 승인 (Orchestra 수정 시)

## Flow

### Step 1: Planner Analysis Report에서 JSON 블록 추출

```json
{
  "levels": [
    {"level": 0, "todoCount": 3, "parallelSafe": true, "todos": [...]},
    {"level": 1, "todoCount": 1, "parallelSafe": false, "todos": [...]}
  ]
}
```

### Step 2: Level별 실행 (Phase 4)

```
for each level in levels:
  IF todoCount >= 2 AND parallelSafe:
    → 한 메시지에 여러 Task() 병렬 호출
    예: Task(High-Player: auth-002) + Task(Low-Player: auth-001)
  ELSE:
    → 단일 Task() 호출
  모든 Task 완료 → 다음 Level
```

### Step 3: Conflict Check (Phase 5 - 조건부)

- 병렬 실행 시에만: Task(Conflict-Checker)
- 단일 순차 실행 시: Skip

### Step 4: Verification (Phase 6)

```bash
.orchestra/hooks/verification/verification-loop.sh full
```

### Step 5: Code-Review Team (Phase 6a-CR)

5명 병렬 호출 → 가중치 점수 계산 → 판정

호출 패턴: `rules/call-templates.md` 참조

### Step 6: 판정 → 다음 행동

| 결과 | 행동 |
|------|------|
| Approved (>= 0.80) | Commit + Journal (Phase 7) |
| Warning (0.50-0.79) | 경고 기록 후 Commit + Journal |
| Block (< 0.50 또는 Auto-Block) | Rework Loop (최대 3회) |

### Step 7: Commit + Journal (Phase 7)

1. `git commit` (TODO 단위, 형식 준수)
2. `Write(.orchestra/journal/{plan-name}-{YYYYMMDD}-{HHmm}.md)`

## 관련 명령어

- `/verify` - 검증 루프만 실행
- `/code-review` - 코드 리뷰만 실행
- `/status` - 현재 상태 확인
