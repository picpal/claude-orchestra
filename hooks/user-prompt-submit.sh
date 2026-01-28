#!/usr/bin/env bash
# Orchestra UserPromptSubmit Hook
# 매 사용자 요청마다 프로토콜과 상태를 Claude에게 주입

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCHESTRA_DIR=".orchestra"

# 슬래시 커맨드 감지 및 활동 로그 기록
if [ -n "${PROMPT:-}" ]; then
  CMD_NAME=$(echo "$PROMPT" | grep -oE '^/[a-zA-Z0-9_-]+' || true)
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
    "$SCRIPT_DIR/activity-logger.sh" COMMAND "$CMD_NAME" "" "$CMD_PHASE" 2>/dev/null || true
  fi
fi
STATE_FILE="$ORCHESTRA_DIR/state.json"

# 기본값
MODE="IDLE"
CONTEXT="dev"
PLAN_INFO=""
TODO_INFO=""

# .orchestra/state.json 읽기 (있을 때만)
if [ -f "$STATE_FILE" ]; then
  MODE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('mode','IDLE'))" 2>/dev/null || echo "IDLE")
  CONTEXT=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('currentContext','dev'))" 2>/dev/null || echo "dev")

  # 활성 계획 확인
  CURRENT_PLAN=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('currentPlan','') or '')" 2>/dev/null || echo "")
  if [ -n "$CURRENT_PLAN" ]; then
    PLAN_INFO="- active-plan: $CURRENT_PLAN"
  fi

  # TODO 진행률
  TOTAL=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(len(d.get('todos',[])))" 2>/dev/null || echo "0")
  if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
    DONE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(sum(1 for t in d.get('todos',[]) if t.get('status')=='done'))" 2>/dev/null || echo "0")
    TODO_INFO="- progress: $DONE/$TOTAL TODOs"
  fi
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
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
else
  # IDLE/PLAN/REVIEW 모드: 전체 에이전트 위임 프로토콜
  cat <<EOF
<user-prompt-submit-hook>
[Orchestra] mode=$MODE context=$CONTEXT

## 에이전트 위임 프로토콜 (필수)

당신은 Maestro(지휘자)입니다. 직접 코드를 수정하지 마세요.
사용자 요청을 Intent로 분류하고, Task 도구로 에이전트에 위임하세요.

### Intent → 에이전트 매핑

| Intent | 조건 | 에이전트 | Task subagent_type |
|--------|------|----------|-------------------|
| TRIVIAL | 단순 질문/설명 | 직접 응답 | - |
| EXPLORATORY | 코드 탐색/검색 | Explorer | Explore |
| AMBIGUOUS | 불명확한 요청 | 명확화 질문 후 재분류 | - |
| OPEN-ENDED | 기능 개발/수정 | Interviewer → Planner | Plan → general-purpose |

### Task 호출 예시

탐색 요청:
Task(subagent_type="Explore", description="Find auth files", prompt="...")

기능 개발:
Task(subagent_type="Plan", description="Design OAuth flow", prompt="...")
→ 계획 확정 후:
Task(subagent_type="general-purpose", description="Implement OAuth login", prompt="...")

### 위임 원칙
- TRIVIAL/AMBIGUOUS 외에는 반드시 Task로 위임
- 복잡한 작업은 여러 Task를 병렬 호출
- 직접 Edit/Write 금지 → Task 에이전트가 수행
- TDD 필수: TEST→IMPL→REFACTOR
- 사용 가능: /start-work, /status, /tdd-cycle, /verify, /context
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
fi
