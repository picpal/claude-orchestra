#!/bin/bash
# Phase Gate 검증 스크립트
# Hook은 stdin으로 JSON을 받으므로 시뮬레이션 필요

# set -e를 사용하지 않음 (테스트 실패 시에도 계속 진행)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE=".orchestra/state.json"
PASSED=0
FAILED=0

# 테스트 헬퍼: stdin JSON 시뮬레이션
simulate_hook_input() {
  local description="$1"
  cat <<EOF
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "general-purpose",
    "description": "$description"
  }
}
EOF
}

# 테스트 헬퍼: state.json 설정
set_state() {
  local planner_completed="$1"
  local rework_active="$2"

  mkdir -p .orchestra
  cat > "$STATE_FILE" <<EOF
{
  "planningPhase": {
    "plannerCompleted": $planner_completed
  },
  "reworkStatus": {
    "active": $rework_active
  }
}
EOF
}

# 테스트 실행
run_test() {
  local name="$1"
  local expected_exit="$2"
  local description="$3"

  echo -n "Test: $name... "

  local actual_exit=0
  simulate_hook_input "$description" | "$HOOK_DIR/phase-gate.sh" > /dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "✅ PASS"
    ((PASSED++))
  else
    echo "❌ FAIL (expected $expected_exit, got $actual_exit)"
    ((FAILED++))
  fi
}

echo "=== Phase Gate 검증 ==="
echo ""

# 테스트 1: Planner 미완료 + Executor → 차단 (exit 1)
set_state "false" "false"
run_test "Planner 미완료 시 Executor 차단" 1 "High-Player: 작업 실행"

# 테스트 2: Planner 완료 + Executor → 통과 (exit 0)
set_state "true" "false"
run_test "Planner 완료 시 Executor 통과" 0 "High-Player: 작업 실행"

# 테스트 3: Rework 모드 + Executor → 통과 (exit 0)
set_state "false" "true"
run_test "Rework 모드 예외" 0 "Low-Player: 재작업"

# 테스트 4: 비-Executor → 통과 (exit 0)
set_state "false" "false"
run_test "비-Executor 통과" 0 "Interviewer: 요구사항 인터뷰"

# 테스트 5: state.json 없음 → 통과 (exit 0, graceful)
rm -f "$STATE_FILE"
run_test "state.json 없음 시 통과" 0 "High-Player: 작업 실행"

# 테스트 6: Low-Player도 차단되어야 함
set_state "false" "false"
run_test "Low-Player도 Planner 미완료 시 차단" 1 "Low-Player: 간단 작업"

echo ""
echo "=== 결과: $PASSED passed, $FAILED failed ==="

# 정리
rm -rf .orchestra

[ "$FAILED" -eq 0 ]
