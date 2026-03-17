#!/bin/bash
# [DEPRECATED] Load Context Hook
# user-prompt-submit.sh가 매 요청마다 상태 모니터링을 수행하므로
# 별도의 세션 시작 컨텍스트 로드가 불필요합니다.
# 향후 버전에서 제거될 수 있습니다.
#
# 원래 용도: 세션 시작 시 이전 컨텍스트를 로드
# Notification Hook (세션 시작 시 실행)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

ensure_orchestra_dirs

STATE_FILE="$ORCHESTRA_STATE_FILE"
CONTEXT_DIR="$ORCHESTRA_DIR/contexts"
PATTERNS_DIR="$SCRIPT_DIR/learning/learned-patterns"
LOG_FILE="$ORCHESTRA_LOG_DIR/context.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 현재 상태 로드
load_state() {
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    MODE=$(jq -r '.mode // "IDLE"' "$STATE_FILE")
    CONTEXT=$(jq -r '.currentContext // "dev"' "$STATE_FILE")
    PLAN_NAME=$(jq -r '.currentPlan.name // null' "$STATE_FILE")
    PLAN_PATH=$(jq -r '.currentPlan.path // null' "$STATE_FILE")
    TODO_COUNT=$(jq '.todos | length' "$STATE_FILE")
    COMPLETED_COUNT=$(jq '[.todos[] | select(.status == "completed")] | length' "$STATE_FILE")
  else
    MODE="IDLE"
    CONTEXT="dev"
    PLAN_NAME="null"
    TODO_COUNT=0
    COMPLETED_COUNT=0
  fi
}

# 컨텍스트 파일 로드
load_context_file() {
  local context="$1"
  local context_file="$CONTEXT_DIR/${context}.md"

  if [ -f "$context_file" ]; then
    log "Loading context file: $context_file"
    return 0
  fi

  return 1
}

# 학습된 패턴 로드
load_learned_patterns() {
  local count=0

  if [ -d "$PATTERNS_DIR" ]; then
    count=$(find "$PATTERNS_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "$count"
}

# 이전 세션 정보 표시
show_session_info() {
  echo ""
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║                   SESSION CONTEXT LOADED                       ║"
  echo "╠═══════════════════════════════════════════════════════════════╣"
  printf "║  Mode:          %-44s ║\n" "$MODE"
  printf "║  Context:       %-44s ║\n" "$CONTEXT"

  if [ "$PLAN_NAME" != "null" ] && [ -n "$PLAN_NAME" ]; then
    printf "║  Active Plan:   %-44s ║\n" "$PLAN_NAME"
    printf "║  Progress:      %-44s ║\n" "$COMPLETED_COUNT/$TODO_COUNT TODOs"
  fi

  local patterns=$(load_learned_patterns)
  if [ "$patterns" -gt 0 ]; then
    printf "║  Patterns:      %-44s ║\n" "$patterns learned"
  fi

  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo ""
}

# 미완료 작업 알림
show_pending_work() {
  if [ "$MODE" = "EXECUTE" ] && [ "$PLAN_NAME" != "null" ]; then
    local pending=$((TODO_COUNT - COMPLETED_COUNT))

    if [ "$pending" -gt 0 ]; then
      echo "📋 Pending Work"
      echo "────────────────"
      echo "  Plan: $PLAN_NAME"
      echo "  Remaining: $pending TODOs"
      echo ""

      # 현재 진행 중인 TODO 표시
      if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
        local current_todo=$(jq -r '.todos[] | select(.status == "in_progress") | .content' "$STATE_FILE" | head -1)
        if [ -n "$current_todo" ] && [ "$current_todo" != "null" ]; then
          echo "  Current: $current_todo"
          echo ""
        fi
      fi
    fi
  fi
}

# 경고 표시
show_warnings() {
  local warnings=0

  # 검증 실패 확인
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local pr_ready=$(jq -r '.verificationMetrics.prReady // true' "$STATE_FILE")
    if [ "$pr_ready" = "false" ]; then
      echo "⚠️ Last verification failed. Run /verify before committing."
      warnings=$((warnings + 1))
    fi

    # TDD 위반 시도 확인
    local deletion_attempts=$(jq '.tddMetrics.testDeletionAttempts // 0' "$STATE_FILE")
    if [ "$deletion_attempts" -gt 0 ]; then
      echo "⚠️ Test deletion was attempted $deletion_attempts times."
      warnings=$((warnings + 1))
    fi
  fi

  if [ "$warnings" -gt 0 ]; then
    echo ""
  fi
}

# 유용한 명령어 안내
show_quick_commands() {
  echo "Quick Commands"
  echo "──────────────"
  echo "  /status        - View current status"
  echo "  /start-work    - Start new work session"

  if [ "$MODE" = "EXECUTE" ]; then
    echo "  /verify        - Run verification loop"
    echo "  /tdd-cycle     - TDD cycle guide"
  fi

  echo ""
}

# 메인 로직
main() {
  log "Loading session context..."

  # 상태 로드
  load_state

  # 컨텍스트 파일 로드
  load_context_file "$CONTEXT"

  # 세션 정보 표시
  show_session_info

  # 경고 표시
  show_warnings

  # 미완료 작업 표시
  show_pending_work

  # 빠른 명령어 안내
  show_quick_commands

  log "Session context loaded successfully"
}

main
