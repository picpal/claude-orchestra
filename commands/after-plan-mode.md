# /after-plan-mode — Plan Mode 종료 후 자동 실행 가이드

> ⚡ **이 흐름은 자동으로 실행됩니다.** 사용자의 추가 지시를 기다리지 마세요.

## 트리거 조건 (하나라도 해당 시 즉시 실행)

- ExitPlanMode 완료 후 (사용자가 계획 승인)
- 사용자가 "실행해줘", "진행해줘" 등 실행 요청
- `user-prompt-submit.sh`가 `PLAN_MODE_READY` 신호 출력

---

## Step A: state.json 업데이트

Write로 `.orchestra/state.json`을 업데이트합니다:

```json
{
  "mode": "PLAN",
  "currentPlan": ".orchestra/plans/{plan-name}.md",
  "planningPhase": {
    "interviewerCompleted": true,
    "plannerCompleted": false
  }
}
```

⚠️ `interviewerCompleted: true` 미설정 시 phase-gate가 Planner 호출을 차단합니다.

## Step B: 계획 파일 저장

Plan Mode에서 작성된 계획을 `.orchestra/plans/{plan-name}.md`에 저장합니다.

- 파일명: 계획 내용에서 핵심 키워드 추출 (예: `auto-execute-plan-mode.md`)
- 내용: Plan Mode에서 승인된 전체 계획

## Step C: Task(Planner) 호출

계획 파일을 기반으로 Planner를 호출합니다:
- TODO 추출
- 6-Section 프롬프트 생성
- Level별 실행 순서 결정

⚠️ Plan Mode 계획이 있어도 Planner는 **생략 불가** (TODO 구조화 + 6-Section 프롬프트 필수)

## Step D: /execute-plan 흐름 시작

Planner 완료 즉시 Phase 4-7을 실행합니다:

```
Phase 4: Level별 Execution (병렬/순차)
Phase 5: Conflict Check (조건부)
Phase 6: Verification (6-Stage)
Phase 6a-CR: Code-Review Group (5명 병렬)
Phase 7: Commit + Journal
```

상세 절차: `/execute-plan` 참조

---

## 요약: 전체 자동 흐름

```
ExitPlanMode (사용자 승인)
  → state.json 업데이트 (interviewerCompleted=true)
  → 계획 파일 저장
  → Task(Planner) → TODO 추출
  → Phase 4-7 실행 (/execute-plan)
  → 완료
```

**중간에 멈추지 마세요.** Step A부터 Phase 7 완료까지 연속으로 진행합니다.
