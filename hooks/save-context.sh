#!/bin/bash
# Save Context Hook
# 세션 종료 시 컨텍스트를 저장합니다.
# Stop Hook (세션 종료 시 실행)

set -e

STATE_FILE=".orchestra/state.json"
LOG_FILE=".orchestra/logs/context.log"
SESSION_LOG_DIR=".orchestra/logs/sessions"

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$SESSION_LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 세션 ID 생성
generate_session_id() {
  echo "session-$(date +%Y%m%d-%H%M%S)"
}

# 현재 상태 가져오기
get_current_state() {
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    cat "$STATE_FILE"
  else
    echo "{}"
  fi
}

# 세션 요약 생성
generate_session_summary() {
  local session_id="$1"

  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local mode=$(jq -r '.mode // "IDLE"' "$STATE_FILE")
    local plan_name=$(jq -r '.currentPlan.name // "None"' "$STATE_FILE")
    local todo_count=$(jq '.todos | length' "$STATE_FILE")
    local completed=$(jq '[.todos[] | select(.status == "completed")] | length' "$STATE_FILE")
    local test_count=$(jq '.tddMetrics.testCount // 0' "$STATE_FILE")
    local cycles=$(jq '.tddMetrics.redGreenCycles // 0' "$STATE_FILE")
    local commits=$(jq '.commitHistory | length' "$STATE_FILE")

    cat << EOF
# Session Summary

## Session ID
$session_id

## Timestamp
$(date -u +%Y-%m-%dT%H:%M:%SZ)

## State
- Mode: $mode
- Active Plan: $plan_name
- Progress: $completed/$todo_count TODOs completed

## TDD Metrics
- Tests Written: $test_count
- RED→GREEN Cycles: $cycles

## Commits
- Total Commits: $commits

## Notes
(Add session notes here)
EOF
  fi
}

# 세션 로그 저장
save_session_log() {
  local session_id="$1"
  local session_file="$SESSION_LOG_DIR/${session_id}.md"

  generate_session_summary "$session_id" > "$session_file"
  log "Session log saved: $session_file"

  echo "$session_file"
}

# 상태 업데이트 (세션 종료 기록)
update_state_on_exit() {
  local session_id="$1"

  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    jq --arg lastSession "$session_id" \
       --arg endTime "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.lastSession = $lastSession | .lastSessionEnd = $endTime' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  fi
}

# 미완료 작업 경고
warn_incomplete_work() {
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local in_progress=$(jq '[.todos[] | select(.status == "in_progress")] | length' "$STATE_FILE")

    if [ "$in_progress" -gt 0 ]; then
      echo ""
      echo "⚠️ Warning: $in_progress TODO(s) still in progress"
      echo "   Consider completing or pausing before ending session."
      echo ""
    fi

    # 미커밋 변경사항 확인
    if ! git diff --quiet 2>/dev/null; then
      echo ""
      echo "⚠️ Warning: Uncommitted changes detected"
      echo "   Consider committing or stashing before ending session."
      echo ""
    fi
  fi
}

# 학습 평가 트리거
trigger_learning_evaluation() {
  local learning_script=".orchestra/hooks/learning/evaluate-session.sh"

  if [ -x "$learning_script" ]; then
    log "Triggering learning evaluation..."
    "$learning_script" evaluate 2>/dev/null || true
  fi
}

# 세션 종료 요약 표시
show_exit_summary() {
  local session_id="$1"
  local session_file="$2"

  echo ""
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║                   SESSION SAVED                                ║"
  echo "╠═══════════════════════════════════════════════════════════════╣"
  printf "║  Session ID:    %-44s ║\n" "$session_id"
  printf "║  Log File:      %-44s ║\n" "$(basename "$session_file")"
  printf "║  Ended At:      %-44s ║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo ""
}

# 메인 로직
main() {
  log "Saving session context..."

  # 미완료 작업 경고
  warn_incomplete_work

  # 세션 ID 생성
  SESSION_ID=$(generate_session_id)

  # 세션 로그 저장
  SESSION_FILE=$(save_session_log "$SESSION_ID")

  # 상태 업데이트
  update_state_on_exit "$SESSION_ID"

  # 학습 평가 트리거
  trigger_learning_evaluation

  # 종료 요약 표시
  show_exit_summary "$SESSION_ID" "$SESSION_FILE"

  log "Session context saved: $SESSION_ID"
}

main
