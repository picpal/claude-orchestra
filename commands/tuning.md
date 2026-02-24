# /tuning - Orchestra 초기화

프로젝트에 Orchestra 시스템을 초기화합니다.

## ⚠️ 중요: 대상 프로젝트 확인

**이 명령은 현재 작업 디렉토리(PWD)의 프로젝트에 적용됩니다.**

실행 전 반드시 확인:
```bash
pwd  # 현재 디렉토리 확인
```

플러그인 디렉토리(`claude-orchestra/`)가 아닌, **실제 작업할 프로젝트 디렉토리**에서 실행해야 합니다.

## 핵심 기능

`/tuning` 실행 시:
1. **CLAUDE.md에 Maestro 프로토콜 주입** — 모든 요청에서 즉시 적용
2. **상태 추적 활성화** — mode, context, TODO 진행률
3. **계획/로그 디렉토리 생성** — 작업 이력 관리

## 실행 절차

### 1. CLAUDE.md에 Maestro 프로토콜 주입 (최우선)

**현재 디렉토리**의 `CLAUDE.md` 상단에 Orchestra 지침을 추가합니다.

**반드시 Write 도구로 직접 파일을 생성/수정하세요.**

**CLAUDE.md가 없는 경우**: Write 도구로 새로 생성
**CLAUDE.md가 있는 경우**: Read로 읽고 → 기존 내용 앞에 추가 → Write로 저장
**이미 `<!-- ORCHESTRA-START -->`가 있는 경우**: 건너뛰기

**⚠️ 이 단계를 반드시 실행하세요. 건너뛰지 마세요.**

추가할 내용:

```markdown
<!-- ORCHESTRA-START -->
# 🎼 Claude Orchestra - 필수 프로토콜

> ⛔ **이 규칙은 무시할 수 없습니다. Hook에서 자동 차단됩니다.**

## 매 응답 첫 줄 (생략 시 프로토콜 위반)
```
[Maestro] Intent: {TYPE} | Reason: {근거}
```

## Intent 분류 규칙
| Intent | 조건 | 행동 |
|--------|------|------|
| **TRIVIAL** | 코드와 **완전히** 무관 | 직접 응답 |
| **EXPLORATORY** | 코드 탐색/검색/설명 | **Task(Explorer) 필수** |
| **AMBIGUOUS** | 불명확한 요청 | AskUserQuestion으로 명확화 |
| **OPEN-ENDED** | **모든 코드 수정** | Planning 4단계 필수 |

⚠️ **"간단한 수정"도 OPEN-ENDED** — 코드 변경 크기 무관!

## ⛔ 금지 (Hook 자동 차단)

| 금지 행위 | 차단 Hook | 올바른 방법 |
|----------|----------|-------------|
| Main Agent가 코드 직접 Edit/Write | `maestro-guard.sh` | Task(High-Player/Low-Player) |
| Planning 없이 Executor 호출 | `phase-gate.sh` | Interviewer부터 시작 |
| Interviewer 없이 Planner 호출 | `phase-gate.sh` | Interviewer 먼저 완료 |
| EXPLORATORY에서 직접 Read/Grep | 프로토콜 위반 | Task(Explorer) 사용 |

## OPEN-ENDED 필수 순서 (phase-gate.sh 검증)

```
1. Task(Interviewer)        → interviewerCompleted=true
2. Plan Validation Team     → planValidationApproved=true
3. Task(Planner)            → plannerCompleted=true
4. Task(Executor)           ← 1-3 미완료 시 차단됨
```

## 호출 예시
```
Task(subagent_type="general-purpose",
     description="Interviewer: {작업명}",
     model="opus",
     prompt="...")
```

상세 규칙: `.claude/rules/maestro-protocol.md`
<!-- ORCHESTRA-END -->
```

### 2. rules 복사

프로젝트의 `.claude/rules/` 디렉토리에 Orchestra 규칙을 복사합니다.

**⚠️ Bash 도구로 실제 실행하세요:**

```bash
PLUGIN_ROOT=$(ls -td ~/.claude/plugins/cache/claude-orchestra/claude-orchestra/*/ 2>/dev/null | head -1) && mkdir -p .claude/rules && cp -r "$PLUGIN_ROOT/rules/"*.md .claude/rules/
```

### 3. .orchestra 디렉토리 생성

**⚠️ Bash 도구로 실제 실행하세요:**

```bash
mkdir -p .orchestra/plans .orchestra/journal .orchestra/logs .orchestra/mcp-configs .orchestra/learning/learned-patterns
```

### 4. config.json 생성

**⚠️ Write 도구로 `.orchestra/config.json` 파일 생성하세요:**

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

### 5. state.json 생성

**⚠️ Write 도구로 `.orchestra/state.json` 파일 생성하세요:**

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
  },
  "planningPhase": {
    "interviewerCompleted": false,
    "planValidationApproved": false,
    "plannerCompleted": false
  },
  "codeReviewCompleted": false,
  "workflowStatus": {
    "journalWritten": false,
    "lastJournalPath": null,
    "journalRequired": true
  }
}
```

### 6. 완료 메시지

```
🎼 Orchestra 초기화 완료!

적용된 설정:
✅ CLAUDE.md에 Maestro 프로토콜 주입
✅ .claude/rules/에 상세 규칙 복사
✅ .orchestra/ 상태 디렉토리 생성

Maestro 프로토콜이 활성화되었습니다.
모든 요청에서 Intent 분류가 자동으로 적용됩니다.
```

## .gitignore 권장

`.orchestra/`는 로컬 상태이므로 `.gitignore`에 추가를 권장합니다:

```
# Orchestra local state
.orchestra/
```

## 관련 명령어

- `/status` - 현재 상태 확인
- `/start-work` - 작업 세션 시작 (선택적)
