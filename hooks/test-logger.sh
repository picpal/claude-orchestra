#!/bin/bash
# Test Logger Hook
# 테스트 실행 결과를 기록하고 TDD 메트릭을 업데이트합니다.
# PostToolUse Hook (Bash 매처)
# Data is received via stdin JSON from Claude Code.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

# Extract command and output from stdin JSON
TOOL_CMD=$(hook_get_field "tool_input.command")
# tool_response can be a string or object with stdout/stderr
TOOL_OUT="$HOOK_TOOL_RESPONSE"
# Try to get stdout if it's an object
TOOL_STDOUT=$(hook_get_field "tool_response.stdout")
if [ -n "$TOOL_STDOUT" ]; then
  TOOL_OUT="$TOOL_STDOUT"
fi

STATE_FILE="$ORCHESTRA_STATE_FILE"
LOG_FILE="$ORCHESTRA_LOG_DIR/test-runs.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 테스트 명령어인지 확인
is_test_command() {
  local input="$1"
  if echo "$input" | grep -qE "(npm|yarn|pnpm|bun)\s+(run\s+)?test|jest|vitest|mocha|pytest"; then
    return 0
  fi
  return 1
}

# 테스트 결과 파싱
parse_test_results() {
  local output="$1"
  local passed=0
  local failed=0
  local skipped=0

  # Jest/Vitest 형식
  if echo "$output" | grep -qE "Tests:"; then
    passed=$(echo "$output" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1 || echo "0")
    failed=$(echo "$output" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1 || echo "0")
    skipped=$(echo "$output" | grep -oE "[0-9]+ skipped" | grep -oE "[0-9]+" | head -1 || echo "0")
  fi

  echo "$passed $failed $skipped"
}

# 커버리지 파싱
parse_coverage() {
  local output="$1"
  local coverage=0

  # Jest 커버리지 형식: "All files | XX.XX |"
  if echo "$output" | grep -qE "All files"; then
    coverage=$(echo "$output" | grep "All files" | grep -oE "[0-9]+(\.[0-9]+)?" | head -1 || echo "0")
  fi

  echo "$coverage"
}

# TDD 사이클 감지 (RED -> GREEN)
detect_tdd_cycle() {
  local output="$1"
  local previous_state=""
  local current_state=""

  # 이전 테스트 상태 로드
  if [ -f "$ORCHESTRA_LOG_DIR/last-test-state" ]; then
    previous_state=$(cat "$ORCHESTRA_LOG_DIR/last-test-state")
  fi

  # 현재 상태 결정
  if echo "$output" | grep -qE "FAIL|failed"; then
    current_state="RED"
  elif echo "$output" | grep -qE "PASS|passed"; then
    current_state="GREEN"
  fi

  # 상태 저장
  echo "$current_state" > "$ORCHESTRA_LOG_DIR/last-test-state"

  # RED -> GREEN 사이클 감지
  if [ "$previous_state" = "RED" ] && [ "$current_state" = "GREEN" ]; then
    echo "CYCLE_DETECTED"
    return 0
  fi

  echo "NO_CYCLE"
  return 1
}

# state.json 업데이트
update_state() {
  local passed="$1"
  local failed="$2"
  local coverage="$3"
  local cycle_detected="$4"

  if [ ! -f "$STATE_FILE" ]; then
    return
  fi

  # jq가 있으면 사용
  if command -v jq &> /dev/null; then
    local total_tests=$((passed + failed))

    # 테스트 수 업데이트
    jq ".tddMetrics.testCount = $total_tests" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    # RED -> GREEN 사이클 카운트 증가
    if [ "$cycle_detected" = "CYCLE_DETECTED" ]; then
      local current=$(jq '.tddMetrics.redGreenCycles // 0' "$STATE_FILE")
      local new=$((current + 1))
      jq ".tddMetrics.redGreenCycles = $new" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
      log "RED -> GREEN cycle detected! Total cycles: $new"
    fi

    # 커버리지 업데이트 (0보다 크면)
    if [ -n "$coverage" ] && [ "$coverage" != "0" ]; then
      jq ".verificationMetrics.results.tests.coverage.lines = $coverage" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
  fi
}

# 메인 로직
main() {
  # 테스트 명령어가 아니면 종료
  if ! is_test_command "$TOOL_CMD"; then
    exit 0
  fi

  log "Test command detected: $TOOL_CMD"

  # 결과 파싱
  read passed failed skipped <<< $(parse_test_results "$TOOL_OUT")
  coverage=$(parse_coverage "$TOOL_OUT")

  log "Results: passed=$passed, failed=$failed, skipped=$skipped, coverage=$coverage%"

  # TDD 사이클 감지
  cycle_result=$(detect_tdd_cycle "$TOOL_OUT")

  # 상태 업데이트
  update_state "$passed" "$failed" "$coverage" "$cycle_result"

  # 요약 출력
  if [ "$cycle_result" = "CYCLE_DETECTED" ]; then
    echo ""
    echo "TDD Cycle Complete: RED -> GREEN"
    echo "   Tests: $passed passed, $failed failed"
    if [ -n "$coverage" ] && [ "$coverage" != "0" ]; then
      echo "   Coverage: ${coverage}%"
    fi
  fi

  # 커버리지 경고
  if [ -n "$coverage" ] && [ "$coverage" != "0" ]; then
    coverage_int=${coverage%.*}
    if [ "$coverage_int" -lt 80 ]; then
      echo ""
      echo "Coverage Warning: ${coverage}% (minimum: 80%)"
    fi
  fi
}

main
