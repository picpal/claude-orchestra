#!/bin/bash
# TDD Guard Hook
# 테스트 파일/케이스 삭제를 방지합니다.
# PreToolUse Hook (Edit|Write 매처)
# Data is received via stdin JSON from Claude Code.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/stdin-reader.sh"

"$SCRIPT_DIR/activity-logger.sh" HOOK tdd-guard 2>/dev/null || true

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
    if command -v jq &> /dev/null; then
      local current=$(jq '.tddMetrics.testDeletionAttempts // 0' "$STATE_FILE")
      local new=$((current + 1))
      jq ".tddMetrics.testDeletionAttempts = $new" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
  fi
}

# 에이전트 스택에서 현재 에이전트 타입 조회
AGENT_STACK_FILE=".orchestra/logs/.agent-stack"

get_current_agent_type() {
  if [ -f "$AGENT_STACK_FILE" ]; then
    tail -1 "$AGENT_STACK_FILE" 2>/dev/null | cut -d'|' -f2
  fi
}


# 코드 작성 완전 금지 에이전트 (plan-checker, plan-reviewer, planner, architecture, conflict-checker)
# Note: Maestro는 .orchestra/ 경로에 한해 Write 허용 (journal, state 등)
is_readonly_agent() {
  local agent="$1"
  local agent_lower
  agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')

  case "$agent_lower" in
    plan-checker|plan-reviewer|planner|architecture|conflict-checker)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Maestro 에이전트인지 확인
is_maestro_agent() {
  local agent="$1"
  local agent_lower
  agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')

  [ "$agent_lower" = "maestro" ]
}

# Maestro용 허용 경로 (.orchestra/ 디렉토리)
is_allowed_path_for_maestro() {
  local file_path="$1"

  if echo "$file_path" | grep -qE '^\.orchestra/'; then
    return 0
  fi
  return 1
}

# Interviewer 에이전트인지 확인 (계획 문서만 작성 가능)
is_interviewer_agent() {
  local agent="$1"
  local agent_lower
  agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')

  [ "$agent_lower" = "interviewer" ]
}

# 허용된 경로인지 확인 (Interviewer용)
is_allowed_path_for_interviewer() {
  local file_path="$1"

  # .orchestra/plans/ 또는 .orchestra/journal/ 경로 허용
  if echo "$file_path" | grep -qE '^\.orchestra/(plans|journal)/.*\.md$'; then
    return 0
  fi
  return 1
}

# 메인 로직
main() {
  # 현재 활성 에이전트 확인
  local current_agent
  current_agent=$(get_current_agent_type)

  log "Current agent: $current_agent"

  # Extract file_path first (Interviewer 예외 처리에 필요)
  local file_path
  file_path=$(hook_get_field "tool_input.file_path")
  local old_string
  old_string=$(hook_get_field "tool_input.old_string")
  local content
  content=$(hook_get_field "tool_input.content")

  log "Checking: file=$file_path, agent=$current_agent"

  # Interviewer 에이전트: .orchestra/plans/, .orchestra/journal/ 경로만 허용
  if [ -n "$current_agent" ] && is_interviewer_agent "$current_agent"; then
    if [ -n "$file_path" ] && is_allowed_path_for_interviewer "$file_path"; then
      log "ALLOWED: Interviewer writing to plan/journal: $file_path"
    else
      log "BLOCKED: Interviewer attempted to write to: $file_path"

      echo "⛔ Protocol Violation Detected!"
      echo ""
      echo "[Interviewer] 에이전트는 계획 문서만 작성할 수 있습니다."
      echo ""
      echo "허용된 경로:"
      echo "  - .orchestra/plans/*.md"
      echo "  - .orchestra/journal/*.md"
      echo ""
      echo "차단된 경로: $file_path"
      echo ""
      exit 1
    fi
  fi

  # Maestro 에이전트: .orchestra/ 경로만 허용 (journal, state, plans 수정)
  if [ -n "$current_agent" ] && is_maestro_agent "$current_agent"; then
    if [ -n "$file_path" ] && is_allowed_path_for_maestro "$file_path"; then
      log "ALLOWED: Maestro writing to .orchestra: $file_path"
    else
      log "BLOCKED: Maestro attempted to write to: $file_path"

      echo "⛔ Protocol Violation Detected!"
      echo ""
      echo "[Maestro] 에이전트는 코드를 직접 작성할 수 없습니다."
      echo ""
      echo "허용된 경로:"
      echo "  - .orchestra/**/* (상태, 저널, 계획 파일)"
      echo ""
      echo "차단된 경로: $file_path"
      echo ""
      echo "올바른 처리:"
      echo "  - Task로 High-Player/Low-Player에게 위임"
      echo ""
      exit 1
    fi
  fi

  # 읽기 전용 에이전트 (plan-checker, plan-reviewer, planner, architecture): 모든 Write 차단
  if [ -n "$current_agent" ] && is_readonly_agent "$current_agent"; then
    log "BLOCKED: $current_agent attempted to use Edit/Write"

    echo "⛔ Protocol Violation Detected!"
    echo ""
    echo "[$current_agent] 에이전트는 파일을 수정할 수 없습니다."
    echo ""
    echo "이 에이전트는 읽기 전용입니다."
    echo ""
    exit 1
  fi

  # 테스트 파일 삭제 시도 확인
  if [ -n "$file_path" ] && is_test_file "$file_path"; then
    # 파일 전체 삭제 (Write with empty content) 확인
    if [ -z "$content" ] && [ "$HOOK_TOOL_NAME" = "Write" ]; then
      log "BLOCKED: Attempted to delete test file: $file_path"
      record_deletion_attempt

      echo "TDD Violation Detected!"
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

      echo "TDD Violation Detected!"
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
  # Check in new_string (Edit) or content (Write)
  local new_string
  new_string=$(hook_get_field "tool_input.new_string")
  local check_text="${new_string}${content}"

  if echo "$check_text" | grep -qE '(it|test|describe)\.skip\s*\('; then
    log "BLOCKED: Attempted to skip test"
    record_deletion_attempt

    echo "TDD Violation Detected!"
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
