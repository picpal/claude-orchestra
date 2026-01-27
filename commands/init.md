# /init - Orchestra 상태 추적 활성화

`.orchestra/` 상태 디렉토리를 생성하여 상태 추적을 활성화합니다.

## 왜 필요한가?

Orchestra는 **init 없이도 기본 동작**합니다. `UserPromptSubmit` hook이 매 요청마다 프로토콜을 자동 주입하므로, 플러그인 설치만으로 TDD 워크플로우와 Intent 분류가 작동합니다.

`/init`을 실행하면 추가로:
- **상태 추적**: mode, context, TODO 진행률 표시
- **계획 관리**: `.orchestra/plans/`에 계획 문서 저장
- **로그 기록**: 작업 이력 보관

## init 없이 vs init 후

| 기능 | init 없이 | init 후 |
|------|-----------|---------|
| 프로토콜 주입 | O | O |
| Intent 분류 | O | O |
| TDD 가이드 | O | O |
| 슬래시 명령어 | O | O |
| 상태 표시 (mode/context) | 기본값 | 실시간 |
| 계획 문서 저장 | X | O |
| TODO 진행률 | X | O |
| 작업 로그 | X | O |

## 실행 절차

### 1. .orchestra 디렉토리 생성

```bash
mkdir -p .orchestra/plans
mkdir -p .orchestra/journal
mkdir -p .orchestra/logs
mkdir -p .orchestra/mcp-configs
mkdir -p .orchestra/templates
```

### 2. config.json 생성

```json
{
  "projectName": "",
  "language": "auto-detect",
  "testFramework": "auto-detect",
  "coverageThreshold": 80,
  "autoCommit": false,
  "verificationMode": "standard"
}
```

### 3. state.json 생성

```json
{
  "mode": "IDLE",
  "currentContext": "dev",
  "currentPlan": null,
  "todos": [],
  "tddMetrics": {
    "testCount": 0,
    "redGreenCycles": 0,
    "testDeletionAttempts": 0
  },
  "commitHistory": [],
  "verificationMetrics": {
    "lastRun": null,
    "mode": null,
    "results": {},
    "prReady": false,
    "blockers": []
  },
  "learningMetrics": {
    "totalSessions": 0,
    "patternsExtracted": 0,
    "lastLearningRun": null
  }
}
```

### 4. 완료 메시지

```
Orchestra 상태 추적 활성화 완료!

생성된 디렉토리:
- .orchestra/plans/      계획 문서
- .orchestra/journal/    작업 일지
- .orchestra/logs/       로그 파일

다음 단계: /start-work 실행
```

## .gitignore 권장

`.orchestra/`는 로컬 상태이므로 `.gitignore`에 추가를 권장합니다:

```
# Orchestra local state
.orchestra/
```

## 관련 명령어

- `/start-work` - 작업 세션 시작
- `/status` - 현재 상태 확인
