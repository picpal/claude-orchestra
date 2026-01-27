#!/bin/bash
# TDD Guard Hook
# 테스트 파일/케이스 삭제를 방지합니다.
# PreToolUse Hook (Edit|Write 매처)

set -e

TOOL_INPUT="$1"
STATE_FILE=".orchestra/state.json"
LOG_FILE=".orchestra/logs/tdd-guard.log"

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 테스트 파일 패턴
TEST_PATTERNS=(
  "\.test\.(ts|tsx|js|jsx)$"
  "\.spec\.(ts|tsx|js|jsx)$"
  "__tests__/"
  "tests?/"
)

# 테스트 케이스 삭제 패턴
TEST_CASE_PATTERNS=(
  "describe\s*\("
  "it\s*\("
  "test\s*\("
  "expect\s*\("
)

# 입력에서 파일 경로 추출 (JSON 형식 가정)
get_file_path() {
  echo "$TOOL_INPUT" | grep -oE '"file_path"\s*:\s*"[^"]+"' | sed 's/"file_path"\s*:\s*"//' | sed 's/"$//' || echo ""
}

# 입력에서 old_string 추출 (Edit 도구)
get_old_string() {
  echo "$TOOL_INPUT" | grep -oE '"old_string"\s*:\s*"[^"]+"' | sed 's/"old_string"\s*:\s*"//' | sed 's/"$//' || echo ""
}

# 테스트 파일인지 확인
is_test_file() {
  local file="$1"
  for pattern in "${TEST_PATTERNS[@]}"; do
    if echo "$file" | grep -qE "$pattern"; then
      return 0
    fi
  done
  return 1
}

# 테스트 케이스 삭제인지 확인
is_test_case_deletion() {
  local old_string="$1"
  for pattern in "${TEST_CASE_PATTERNS[@]}"; do
    if echo "$old_string" | grep -qE "$pattern"; then
      return 0
    fi
  done
  return 1
}

# 상태 파일에 삭제 시도 기록
record_deletion_attempt() {
  if [ -f "$STATE_FILE" ]; then
    # jq가 있으면 사용, 없으면 sed 사용
    if command -v jq &> /dev/null; then
      local current=$(jq '.tddMetrics.testDeletionAttempts // 0' "$STATE_FILE")
      local new=$((current + 1))
      jq ".tddMetrics.testDeletionAttempts = $new" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
  fi
}

# 메인 로직
main() {
  local file_path=$(get_file_path)
  local old_string=$(get_old_string)

  log "Checking: file=$file_path"

  # 테스트 파일 삭제 시도 확인
  if [ -n "$file_path" ] && is_test_file "$file_path"; then
    # 파일 전체 삭제 (Write with empty content) 확인
    if echo "$TOOL_INPUT" | grep -qE '"content"\s*:\s*""'; then
      log "BLOCKED: Attempted to delete test file: $file_path"
      record_deletion_attempt

      echo "❌ TDD Violation Detected!"
      echo ""
      echo "테스트 파일 삭제가 감지되었습니다:"
      echo "  - $file_path"
      echo ""
      echo "테스트 파일을 삭제하는 대신:"
      echo "  1. 테스트를 수정하세요"
      echo "  2. 정말 불필요하다면 Planner에게 요청하세요"
      echo ""
      exit 1
    fi

    # 테스트 케이스 삭제 확인
    if [ -n "$old_string" ] && is_test_case_deletion "$old_string"; then
      log "BLOCKED: Attempted to delete test case in: $file_path"
      record_deletion_attempt

      echo "❌ TDD Violation Detected!"
      echo ""
      echo "테스트 케이스 삭제가 감지되었습니다:"
      echo "  - File: $file_path"
      echo ""
      echo "테스트를 삭제하는 대신:"
      echo "  1. 테스트를 수정하세요"
      echo "  2. 구현을 수정하세요"
      echo "  3. 정말 불필요하다면 Planner에게 요청하세요"
      echo ""
      exit 1
    fi
  fi

  # it.skip, test.skip, describe.skip 패턴 확인
  if echo "$TOOL_INPUT" | grep -qE '(it|test|describe)\.skip\s*\('; then
    log "BLOCKED: Attempted to skip test"
    record_deletion_attempt

    echo "❌ TDD Violation Detected!"
    echo ""
    echo "테스트 스킵이 감지되었습니다."
    echo ""
    echo "테스트를 스킵하는 대신:"
    echo "  1. 테스트를 수정하세요"
    echo "  2. 구현을 수정하세요"
    echo ""
    exit 1
  fi

  log "PASSED: No TDD violations"
  exit 0
}

main
