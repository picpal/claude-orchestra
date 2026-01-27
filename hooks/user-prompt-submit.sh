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
    "$SCRIPT_DIR/activity-logger.sh" COMMAND "$CMD_NAME" 2>/dev/null || true
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

# 출력
cat <<EOF
<user-prompt-submit-hook>
[Orchestra] mode=$MODE context=$CONTEXT
- 이 프로젝트는 Orchestra 멀티에이전트 TDD 시스템을 사용합니다.
- Intent 분류: TRIVIAL(직접응답) / EXPLORATORY(탐색) / AMBIGUOUS(명확화) / OPEN-ENDED(전체플로우)
- TDD 필수: TEST→IMPL→REFACTOR
- 사용 가능: /start-work, /status, /tdd-cycle, /verify, /context
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
