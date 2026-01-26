# /start-work - 작업 세션 시작

작업 세션을 시작합니다.

## 실행 절차

### 1. 상태 확인
현재 Orchestra 상태를 확인합니다.

```bash
cat .orchestra/state.json
```

### 2. 모드 확인

**IDLE 상태인 경우:**
- 새 작업 시작 준비 완료
- 사용자 요청 대기

**PLAN 상태인 경우:**
- 진행 중인 계획 확인: `.orchestra/plans/`
- 계획 이어서 진행 또는 새 계획 시작

**EXECUTE 상태인 경우:**
- 진행 중인 TODO 확인
- 작업 이어서 진행

### 3. 세션 초기화

```json
{
  "mode": "IDLE",
  "currentPlan": null,
  "sessionStartedAt": "{ISO-8601}",
  "tddMetrics": {
    "testCount": 0,
    "redGreenCycles": 0,
    "testDeletionAttempts": 0
  }
}
```

### 4. 사용자 안내

```
🎼 Claude Orchestra 세션 시작

현재 상태: {mode}
활성 계획: {currentPlan?.name || "없음"}

사용 가능한 명령어:
- /status: 현재 상태 확인
- /tdd-cycle: TDD 사이클 안내

무엇을 도와드릴까요?
```

## Intent 분류 가이드

사용자 요청을 다음 카테고리로 분류:

| Intent | 예시 | 처리 |
|--------|------|------|
| TRIVIAL | "이 함수 설명해줘" | 직접 응답 |
| EXPLORATORY | "인증 로직 어디있어?" | Explorer 호출 |
| AMBIGUOUS | "로그인 고쳐줘" | 명확화 질문 |
| OPEN-ENDED | "OAuth 추가해줘" | 전체 플로우 시작 |

## 다음 단계

Intent에 따라:
1. **TRIVIAL** → 직접 응답 후 대기
2. **EXPLORATORY** → Research Layer 호출
3. **AMBIGUOUS** → 명확화 질문
4. **OPEN-ENDED** → Interviewer로 계획 수립 시작
