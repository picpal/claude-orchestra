#!/bin/bash
# Phase Gate Hook - Executor 호출 전 Planner 완료 검증
# PreToolUse/Task 이벤트에서 실행됨
# python3 사용 (jq 대신, macOS 기본 설치)

# set -e를 사용하지 않음 (stdin-reader.sh 소싱 시 오류 방지)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

STATE_FILE="$ORCHESTRA_STATE_FILE"
LOG_FILE="$ORCHESTRA_LOG_DIR/phase-gate.log"

# 로깅 함수
log() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# description에서 에이전트 타입 추출
get_target_agent() {
  local description
  description=$(hook_get_field "tool_input.description")
  local desc_lower
  desc_lower=$(echo "$description" | tr '[:upper:]' '[:lower:]')

  if echo "$desc_lower" | grep -qE '^high-player:|high.player'; then
    echo "high-player"
  elif echo "$desc_lower" | grep -qE '^low-player:|low.player'; then
    echo "low-player"
  else
    echo ""
  fi
}

# Executor인지 확인
is_executor() {
  local agent="$1"
  [ "$agent" = "high-player" ] || [ "$agent" = "low-player" ]
}

# Rework 모드인지 확인 (python3 사용)
is_rework_mode() {
  if [ -f "$STATE_FILE" ]; then
    local result
    result=$(python3 -c "
import json
import sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    active = d.get('reworkStatus', {}).get('active', False)
    print('rework_active=' + str(active), file=sys.stderr)
    sys.exit(0 if active else 1)
except Exception as e:
    print('rework_error=' + str(e), file=sys.stderr)
    sys.exit(1)
" 2>>"$LOG_FILE")
    return $?
  else
    return 1
  fi
}

# Planning Phase 완료 확인 (4단계 모두 검증)
# 반환값: 0=통과, 1=미완료 (어떤 단계가 누락)
# MISSING_PHASES 변수에 누락된 단계들 저장
check_planning_phase_completed() {
  MISSING_PHASES=""

  if [ -f "$STATE_FILE" ]; then
    local result
    result=$(python3 -c "
import json
import sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    pp = d.get('planningPhase', {})

    missing = []
    if not pp.get('interviewerCompleted', False):
        missing.append('Interviewer')
    if not pp.get('planCheckerCompleted', False):
        missing.append('Plan-Checker')
    if not pp.get('planReviewerCompleted', False):
        missing.append('Plan-Reviewer')
    if not pp.get('plannerCompleted', False):
        missing.append('Planner')

    if missing:
        print(','.join(missing))
        sys.exit(1)
    else:
        print('ALL_COMPLETE')
        sys.exit(0)
except Exception as e:
    print('ERROR:' + str(e), file=sys.stderr)
    sys.exit(1)
" "$STATE_FILE" 2>>"$LOG_FILE")
    local exit_code=$?
    MISSING_PHASES="$result"
    return $exit_code
  else
    return 0  # state.json 없으면 통과 (graceful)
  fi
}

# 메인 로직
main() {
  local target_agent
  target_agent=$(get_target_agent)

  log "Checking: target_agent=$target_agent"

  # Executor가 아니면 통과
  if ! is_executor "$target_agent"; then
    log "PASS: Not an Executor (agent=$target_agent)"
    exit 0
  fi

  # Rework 모드면 통과
  if is_rework_mode; then
    log "PASS: Rework mode active"
    exit 0
  fi

  # Planning Phase 완료 확인 (4단계 모두 필수)
  if ! check_planning_phase_completed; then
    log "BLOCKED: Planning phase incomplete for $target_agent (missing: $MISSING_PHASES)"

    echo "⛔ Phase Gate Violation!"
    echo ""
    echo "Executor($target_agent) 호출이 차단되었습니다."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ 누락된 Planning 단계: $MISSING_PHASES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "OPEN-ENDED 작업은 반드시 다음 순서를 따라야 합니다:"
    echo ""
    echo "  1. Task(Interviewer)    → 요구사항 인터뷰"
    echo "  2. Task(Plan-Checker)   → 놓친 질문 확인"
    echo "  3. Task(Plan-Reviewer)  → 계획 승인 (Approved)"
    echo "  4. Task(Planner)        → 6-Section 프롬프트 생성"
    echo "  5. Task(Executor)       ← 지금 여기서 차단됨"
    echo ""
    echo "호출 예시:"
    echo "  Task(subagent_type=\"general-purpose\","
    echo "       description=\"Interviewer: {작업명}\","
    echo "       model=\"opus\","
    echo "       prompt=\"...\")"
    echo ""
    exit 1
  fi

  log "PASS: All planning phases completed, allowing $target_agent"
  exit 0
}

main
