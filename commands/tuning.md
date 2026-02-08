# /tuning - Orchestra 초기화

프로젝트에 Orchestra 시스템을 초기화합니다.

## 핵심 기능

`/tuning` 실행 시:
1. **CLAUDE.md에 Maestro 프로토콜 주입** — 모든 요청에서 즉시 적용
2. **상태 추적 활성화** — mode, context, TODO 진행률
3. **계획/로그 디렉토리 생성** — 작업 이력 관리

## 실행 절차

### 1. CLAUDE.md에 Maestro 프로토콜 주입 (최우선)

프로젝트 루트의 `CLAUDE.md` 상단에 Orchestra 지침을 추가합니다.

**CLAUDE.md가 없는 경우**: 새로 생성
**CLAUDE.md가 있는 경우**: 기존 내용 앞에 추가 (기존 내용 유지)
**이미 Orchestra 블록이 있는 경우**: 건너뛰기

추가할 내용:

```markdown
<!-- ORCHESTRA-START -->
# 🎼 Claude Orchestra

> **이 프로젝트는 Claude Orchestra 멀티 에이전트 시스템을 사용합니다.**

## 🔒 Preflight Check (Edit/Write 호출 전 확인)

**매번 Edit/Write 호출 전:**
1. 이 파일이 코드 파일인가? (`.orchestra/`, `.claude/`, `*.md` 제외)
2. **YES** → ⛔ STOP. `Task(High-Player/Low-Player)`로 위임
3. **NO** → ✅ 진행 가능

## 🚨 필수 규칙 (모든 요청에 적용)

### 1. 매 응답 첫 줄: Intent 선언
```
[Maestro] Intent: {TYPE} | Reason: {근거}
```

### 2. Intent 분류
| Intent | 조건 | 행동 |
|--------|------|------|
| **TRIVIAL** | 코드와 완전히 무관 | 직접 응답 |
| **EXPLORATORY** | 코드 탐색/검색 | Task(Explorer) 호출 |
| **AMBIGUOUS** | 불명확한 요청 | AskUserQuestion으로 명확화 |
| **OPEN-ENDED** | **모든 코드 수정** | 전체 Phase 흐름 실행 |

⚠️ **"간단한 수정"도 OPEN-ENDED** — 코드 변경 크기 무관!

### 3. OPEN-ENDED 필수 체크리스트
Executor 호출 전 반드시 완료:
- □ Task(Interviewer) 완료?
- □ Task(Plan-Checker) 완료?
- □ Task(Plan-Reviewer) "Approved"?
- □ Task(Planner) 6-Section 프롬프트?

### 4. 금지 행위
- ❌ **직접 Edit/Write (코드)** → Task(High-Player/Low-Player)로 위임
- ❌ **직접 코드 탐색** → Task(Explorer)로 위임
- ❌ **Planning 없이 코드 수정** → Interviewer → Planner → Executor 순서 필수

### 5. 상세 규칙
`.claude/rules/maestro-protocol.md` 참조

<!-- ORCHESTRA-END -->
```

### 2. rules 복사

프로젝트의 `.claude/rules/` 디렉토리에 Orchestra 규칙을 복사합니다:

```bash
mkdir -p .claude/rules
cp -r ${CLAUDE_PLUGIN_ROOT}/rules/*.md .claude/rules/
```

### 3. .orchestra 디렉토리 생성

```bash
mkdir -p .orchestra/plans
mkdir -p .orchestra/journal
mkdir -p .orchestra/logs
mkdir -p .orchestra/mcp-configs
mkdir -p .orchestra/templates
mkdir -p .orchestra/learning/learned-patterns
```

### 4. config.json 생성

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
