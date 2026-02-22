#!/bin/bash
# Planning 에이전트 완료 감지 테스트

# set -e를 사용하지 않음 (테스트 실패 시에도 계속 진행)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE=".orchestra/state.json"
PASSED=0
FAILED=0

# 초기 state.json 생성
init_state() {
  mkdir -p .orchestra/logs
  cat > "$STATE_FILE" <<EOF
{
  "planningPhase": {
    "interviewerCompleted": false,
    "planCheckerCompleted": false,
    "planReviewerApproved": false,
    "plannerCompleted": false
  }
}
EOF
}

# stdin JSON 시뮬레이션 (SubagentStop)
simulate_subagent_stop() {
  local description="$1"
  cat <<EOF
{
  "hook_event_name": "SubagentStop",
  "agent_type": "general-purpose",
  "agent_id": "test-agent-123",
  "description": "$description"
}
EOF
}

# 플래그 확인
check_flag() {
  local flag="$1"
  python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
exit(0 if d.get('planningPhase', {}).get('$flag', False) else 1)
" 2>/dev/null
}

# 테스트 실행
run_detection_test() {
  local name="$1"
  local expected_flag="$2"
  local description="$3"

  echo -n "Test: $name... "

  init_state
  simulate_subagent_stop "$description" | "$HOOK_DIR/agent-logger.sh" subagent-stop > /dev/null 2>&1

  if check_flag "$expected_flag"; then
    echo "✅ PASS"
    ((PASSED++))
  else
    echo "❌ FAIL ($expected_flag not set)"
    ((FAILED++))
  fi
}

# 부정 테스트 (플래그가 설정되지 않아야 함)
run_negative_test() {
  local name="$1"
  local unexpected_flag="$2"
  local description="$3"

  echo -n "Test: $name... "

  init_state
  simulate_subagent_stop "$description" | "$HOOK_DIR/agent-logger.sh" subagent-stop > /dev/null 2>&1

  if ! check_flag "$unexpected_flag"; then
    echo "✅ PASS"
    ((PASSED++))
  else
    echo "❌ FAIL ($unexpected_flag should NOT be set)"
    ((FAILED++))
  fi
}

echo "=== Planning 감지 테스트 ==="
echo ""

# 테스트 1: Interviewer 완료 감지
run_detection_test "Interviewer 감지" "interviewerCompleted" "Interviewer: 요구사항 인터뷰"

# 테스트 2: Planner 완료 감지
run_detection_test "Planner 감지" "plannerCompleted" "Planner: TODO 분석"

# 테스트 5: 다른 에이전트는 Planning 플래그 설정 안함
run_negative_test "Explorer는 plannerCompleted 설정 안함" "plannerCompleted" "Explorer: 코드베이스 탐색"

# 테스트 6: Planner 에이전트 변형 감지
run_detection_test "Planner 에이전트 변형 감지" "plannerCompleted" "Planner 에이전트: 계획 분석"

echo ""
echo "=== 결과: $PASSED passed, $FAILED failed ==="

# 정리
rm -rf .orchestra

[ "$FAILED" -eq 0 ]
