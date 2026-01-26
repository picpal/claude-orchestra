#!/bin/bash
# Strategic Compact Suggestion Script
# 도구 호출 횟수를 추적하고 컴팩션을 제안합니다.
# PreToolUse Hook (Edit|Write 매처)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/compact-config.json"
STATE_FILE=".orchestra/state.json"
COUNTER_FILE="/tmp/claude_orchestra_tool_count_$$"
LOG_FILE=".orchestra/logs/compact.log"

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 설정 로드
load_config() {
  if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
    ENABLED=$(jq -r '.enabled // false' "$CONFIG_FILE")
    THRESHOLD=$(jq -r '.thresholds.toolCalls // 50' "$CONFIG_FILE")
    REMINDER=$(jq -r '.thresholds.reminderInterval // 25' "$CONFIG_FILE")
    AUTO_SUGGEST=$(jq -r '.autoSuggestOnPhaseChange // true' "$CONFIG_FILE")
  else
    ENABLED="false"
    THRESHOLD=50
    REMINDER=25
    AUTO_SUGGEST="true"
  fi
}

# 카운터 파일 경로 (세션별로 유지)
get_counter_file() {
  # 세션 ID가 있으면 사용, 없으면 임시
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local session_id=$(jq -r '.currentPlan.sessionId // "default"' "$STATE_FILE" 2>/dev/null || echo "default")
    echo "/tmp/claude_orchestra_tool_count_${session_id}"
  else
    echo "/tmp/claude_orchestra_tool_count_default"
  fi
}

# 카운터 증가
increment_counter() {
  local counter_file=$(get_counter_file)

  if [ -f "$counter_file" ]; then
    COUNT=$(cat "$counter_file")
    COUNT=$((COUNT + 1))
  else
    COUNT=1
  fi

  echo "$COUNT" > "$counter_file"
  echo "$COUNT"
}

# 현재 모드 가져오기
get_current_mode() {
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    jq -r '.mode // "IDLE"' "$STATE_FILE"
  else
    echo "IDLE"
  fi
}

# Phase 전환 감지
check_phase_transition() {
  local current_mode=$(get_current_mode)
  local last_mode_file="/tmp/claude_orchestra_last_mode"

  if [ -f "$last_mode_file" ]; then
    local last_mode=$(cat "$last_mode_file")

    if [ "$current_mode" != "$last_mode" ]; then
      echo "$current_mode" > "$last_mode_file"

      # 전환 메시지 확인
      if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
        local message=$(jq -r ".phaseTransitions[] | select(.from == \"$last_mode\" and .to == \"$current_mode\") | .message // \"\"" "$CONFIG_FILE")
        local should_suggest=$(jq -r ".phaseTransitions[] | select(.from == \"$last_mode\" and .to == \"$current_mode\") | .suggest // false" "$CONFIG_FILE")

        if [ "$should_suggest" = "true" ] && [ -n "$message" ]; then
          echo ""
          echo "🔄 Phase Transition: $last_mode → $current_mode"
          echo "   $message"
          echo ""
          return 0
        fi
      fi
    fi
  else
    echo "$current_mode" > "$last_mode_file"
  fi

  return 1
}

# 컴팩션 제안
suggest_compaction() {
  local count="$1"

  if [ "$count" -ge 100 ]; then
    echo ""
    echo "⚠️ 컴팩션 강력 권장: ${count}회 도구 호출 초과"
    echo "   즉시 /compact를 실행하여 컨텍스트를 정리하세요."
    echo ""
  elif [ "$count" -ge 75 ]; then
    echo ""
    echo "🗜️ 컴팩션 필요: ${count}회 도구 호출"
    echo "   컨텍스트 효율성을 위해 /compact 실행을 권장합니다."
    echo ""
  elif [ "$count" -eq "$THRESHOLD" ]; then
    echo ""
    echo "🗜️ 컴팩션 권장: ${count}회 도구 호출 도달"
    echo "   논리적 경계에서 /compact 실행을 고려하세요."
    echo ""
  elif [ "$count" -gt "$THRESHOLD" ]; then
    # 리마인더 간격마다 알림
    local since_threshold=$((count - THRESHOLD))
    if [ $((since_threshold % REMINDER)) -eq 0 ]; then
      echo ""
      echo "🗜️ 리마인더: ${count}회 도구 호출. 컴팩션을 고려하세요."
      echo ""
    fi
  fi
}

# 상태 업데이트
update_state() {
  local count="$1"

  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    jq --argjson count "$count" \
       '.compactMetrics.currentToolCount = $count' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  fi
}

# 컴팩션 실행 기록
record_compaction() {
  local phase="$1"
  local context_before="$2"
  local context_after="$3"

  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local total=$(jq '.compactMetrics.totalCompactions // 0' "$STATE_FILE")
    local new_total=$((total + 1))

    local history_entry=$(cat << EOF
{
  "phase": "$phase",
  "compactedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contextSizeBefore": $context_before,
  "contextSizeAfter": $context_after
}
EOF
)

    jq --argjson total "$new_total" \
       --arg lastCompaction "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson entry "$history_entry" \
       '.compactMetrics.totalCompactions = $total |
        .compactMetrics.lastCompaction = $lastCompaction |
        .compactMetrics.phaseHistory += [$entry]' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    # 카운터 리셋
    local counter_file=$(get_counter_file)
    echo "0" > "$counter_file"
  fi

  log "Compaction recorded: phase=$phase, before=$context_before, after=$context_after"
}

# 상태 보기
show_status() {
  local counter_file=$(get_counter_file)
  local count=0

  if [ -f "$counter_file" ]; then
    count=$(cat "$counter_file")
  fi

  echo ""
  echo "📊 Compact Status"
  echo "================="
  echo "  Tool calls this session: $count"
  echo "  Threshold: $THRESHOLD"
  echo "  Reminder interval: $REMINDER"

  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local total=$(jq '.compactMetrics.totalCompactions // 0' "$STATE_FILE")
    local last=$(jq -r '.compactMetrics.lastCompaction // "Never"' "$STATE_FILE")
    echo "  Total compactions: $total"
    echo "  Last compaction: $last"
  fi

  echo ""
}

# 메인 로직
main() {
  local command="${1:-check}"

  load_config

  if [ "$ENABLED" != "true" ] && [ "$command" != "status" ]; then
    exit 0
  fi

  case "$command" in
    check)
      # 카운터 증가 및 제안 확인
      COUNT=$(increment_counter)
      update_state "$COUNT"

      # Phase 전환 확인
      if [ "$AUTO_SUGGEST" = "true" ]; then
        check_phase_transition
      fi

      # 컴팩션 제안
      suggest_compaction "$COUNT"
      ;;

    status)
      show_status
      ;;

    record)
      # 컴팩션 기록 (Maestro가 호출)
      local phase="${2:-unknown}"
      local before="${3:-0}"
      local after="${4:-0}"
      record_compaction "$phase" "$before" "$after"
      echo "✅ Compaction recorded"
      ;;

    reset)
      # 카운터 리셋
      local counter_file=$(get_counter_file)
      echo "0" > "$counter_file"
      echo "✅ Counter reset"
      ;;

    *)
      echo "Usage: $0 {check|status|record|reset}"
      exit 1
      ;;
  esac
}

main "$@"
