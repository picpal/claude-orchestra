#!/usr/bin/env bash
# Orchestra UserPromptSubmit Hook
# 매 사용자 요청마다 프로토콜과 상태를 Claude에게 주입

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

# Read stdin JSON from Claude Code
source "$SCRIPT_DIR/stdin-reader.sh"

# Extract user prompt from stdin JSON
# UserPromptSubmit provides: { "session_id", "hook_event_name", "user_prompt" }
USER_PROMPT=$(hook_get_field "user_prompt")

# 슬래시 커맨드 감지 및 활동 로그 기록
if [ -n "$USER_PROMPT" ]; then
  CMD_NAME=$(echo "$USER_PROMPT" | grep -oE '^/[a-zA-Z0-9_-]+' || true)
  if [ -n "$CMD_NAME" ]; then
    # 슬래시 명령어별 PHASE 매핑
    case "$CMD_NAME" in
      /verify)       CMD_PHASE="VERIFY" ;;
      /code-review)  CMD_PHASE="REVIEW" ;;
      /start-work)   CMD_PHASE="PLAN" ;;
      /tdd-cycle)    CMD_PHASE="EXECUTE" ;;
      /learn)        CMD_PHASE="RESEARCH" ;;
      *)             CMD_PHASE="-" ;;
    esac
  fi
fi
STATE_FILE="$ORCHESTRA_STATE_FILE"

# 기본값
MODE="IDLE"
CONTEXT="dev"
PLAN_INFO=""
TODO_INFO=""
JOURNAL_REQUIRED="false"
JOURNAL_WRITTEN="false"
CURRENT_PLAN=""
TOTAL="0"
DONE="0"

# .orchestra/state.json 읽기 (있을 때만)
# Python3 1회 호출로 모든 필드 추출 (성능 최적화)
if [ -f "$STATE_FILE" ]; then
  output=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    mode = d.get('mode', 'IDLE')
    ctx = d.get('currentContext', 'dev')
    ws = d.get('workflowStatus', {})
    jr = str(ws.get('journalRequired', False)).lower()
    jw = str(ws.get('journalWritten', False)).lower()
    plan = d.get('currentPlan', '') or '-'
    todos = d.get('todos', [])
    total = len(todos)
    done = sum(1 for t in todos if t.get('status') == 'done')
    print(f'{mode} {ctx} {jr} {jw} {plan} {total} {done}')
except:
    print('IDLE dev false false - 0 0')
" "$STATE_FILE" 2>/dev/null)

  # 출력 검증 (7개 필드 확인)
  if [ $? -eq 0 ] && [ $(echo "$output" | wc -w) -eq 7 ]; then
    read -r MODE CONTEXT JOURNAL_REQUIRED JOURNAL_WRITTEN CURRENT_PLAN TOTAL DONE <<< "$output"
  fi

  # 빈 plan 처리
  [ "$CURRENT_PLAN" = "-" ] && CURRENT_PLAN=""

  # PLAN_INFO 및 TODO_INFO 설정
  if [ -n "$CURRENT_PLAN" ]; then
    PLAN_INFO="- active-plan: $CURRENT_PLAN"
  fi

  if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
    TODO_INFO="- progress: $DONE/$TOTAL TODOs"
  fi
fi

# Journal 차단 리마인더 (journalRequired=true && journalWritten=false)
if [ "$JOURNAL_REQUIRED" = "true" ] && [ "$JOURNAL_WRITTEN" = "false" ]; then
  cat <<'JOURNAL_BLOCK'

## [차단] Journal 리포트 작성 필수

Verification이 완료되었습니다. **Journal 리포트를 먼저 작성하세요.**

### 즉시 수행:
1. `.orchestra/journal/{plan-name}-{YYYYMMDD}-{HHmm}.md` 작성
2. Journal Template 양식 준수 (Meta, Summary, TODOs, Files, Verification)

**Journal 작성 전 다른 작업을 수행하지 마세요.**

JOURNAL_BLOCK
fi

# 출력: 모드에 따라 분기
if [ "$MODE" = "EXECUTE" ]; then
  # EXECUTE 모드: 간소화된 실행 지시 (Planner가 Executor를 호출하는 상황)
  cat <<EOF
<user-prompt-submit-hook>
[Orchestra] mode=$MODE context=$CONTEXT

## 실행 모드 활성

현재 계획을 실행 중입니다. Task 도구로 에이전트에 작업을 위임하세요.
- 복잡한 구현: Task(subagent_type="general-purpose", description="...", prompt="...")
- 코드 탐색: Task(subagent_type="Explore", description="...", prompt="...")
- 직접 Edit/Write 하지 말고 Task 에이전트가 수행하게 하세요.
- TDD 필수: TEST→IMPL→REFACTOR

### 작업 완료 리포트 (필수)
- 모든 TODO가 완료되고 Verification + Git Commit까지 끝났다면:
  1. \`.orchestra/journal/{plan-name}-{YYYYMMDD}.md\` 파일을 작성하세요
  2. 리포트에 포함할 항목: Summary, Completed TODOs, Files Changed, Verification Results, Decisions, Issues, Next Steps
  3. 리포트 작성 후 state.json의 mode를 "IDLE"로 전환하세요
  4. \`[Orchestra] ✅ Journal 리포트 작성 완료: .orchestra/journal/{파일명}\` 출력

### Context 모니터링 (필수)
- context 사용률을 인식하고, 70% 이상일 때 **5% 단위로** 경고를 출력하세요:
  \`[Orchestra] ⚠️ Context: {N}% 사용 중\`
  출력 시점: 70%, 75%, 80%, 85%, 90%, 95%, 100%
- **95% 이상**일 때는 작업 수행 전에 반드시 사용자에게 알리고 진행 여부를 확인하세요:
  - AskUserQuestion 도구를 사용하여 "context가 {N}% 사용 중입니다. 계속 진행할까요?" 질문
  - 선택지: "계속 진행" / "/compact 실행하여 정리"
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
else
  # IDLE/PLAN/REVIEW 모드: Main Agent(Maestro) 프로토콜 리마인더
  cat <<EOF
<user-prompt-submit-hook>
[Orchestra] mode=$MODE context=$CONTEXT

## ⛔ 무시 불가 규칙 (위반 시 Hook에서 자동 차단)

### 차단 메커니즘
| 위반 행위 | 차단 Hook | 결과 |
|----------|----------|------|
| 직접 Edit/Write (코드) | \`maestro-guard.sh\` | ⛔ 즉시 차단 |
| Planning 없이 Executor | \`phase-gate.sh\` | ⛔ 즉시 차단 |
| 순서 없이 Planner 호출 | \`phase-gate.sh\` | ⛔ 즉시 차단 |

### 1. 매 응답 첫 줄 (생략 = 프로토콜 위반)
\`\`\`
[Maestro] Intent: {TYPE} | Reason: {근거}
\`\`\`

### 2. Intent 분류 → 자동 라우팅
| Intent | 조건 | 필수 행동 |
|--------|------|----------|
| **TRIVIAL** | 코드와 **완전히** 무관 | 직접 응답 |
| **EXPLORATORY** | 코드 탐색/검색/설명 | **Task(Explorer) 필수** |
| **AMBIGUOUS** | 불명확한 요청 | AskUserQuestion |
| **OPEN-ENDED** | **모든 코드 수정** | Planning 3단계 필수 |

⚠️ **"간단한 수정"도 OPEN-ENDED** — 코드 변경 크기 무관!

### 3. OPEN-ENDED 필수 순서 (phase-gate.sh 검증)
\`\`\`
1. Task(Interviewer)     → 완료 후 다음 단계
2. Task(Plan-Validator)  → Interviewer 완료 필수
3. Task(Planner)         → 1-2 완료 필수
4. Task(Executor)        → 1-3 완료 필수 (미완료 시 차단)
\`\`\`

### 4. 에이전트 호출 (올바른 방법)
\`\`\`
Task(subagent_type="general-purpose",
     description="Interviewer: {작업명}",
     model="opus",
     prompt="...")
\`\`\`

### Context 모니터링
- 70% 이상: \`[Orchestra] ⚠️ Context: {N}% 사용 중\`
- 95% 이상: AskUserQuestion으로 사용자 확인

상세 규칙: \`.claude/rules/maestro-protocol.md\`
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
fi
