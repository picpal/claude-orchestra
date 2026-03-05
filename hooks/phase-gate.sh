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
  elif echo "$desc_lower" | grep -qE '^planner:|planner\s'; then
    echo "planner"
  else
    echo ""
  fi
}

# Executor인지 확인
is_executor() {
  local agent="$1"
  [ "$agent" = "high-player" ] || [ "$agent" = "low-player" ]
}

# Gate 검증 대상 에이전트인지 확인
is_gated_agent() {
  local agent="$1"
  case "$agent" in
    high-player|low-player|planner) return 0 ;;
    *) return 1 ;;
  esac
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

# 에이전트별 필요한 선행 단계 정의
# - planner: Interviewer 완료 필요
# - executor: Interviewer + Planner 완료 필요

# 에이전트별 필수 선행 단계 검증
# $1: 대상 에이전트
# 반환값: 0=통과, 1=미완료
# MISSING_PHASES 변수에 누락된 단계들 저장
check_required_phases() {
  local target_agent="$1"
  MISSING_PHASES=""

  if [ -f "$STATE_FILE" ]; then
    local result
    result=$(python3 -c "
import json
import sys

target = sys.argv[1]

# 에이전트별 필수 선행 단계 매트릭스
REQUIRED_PHASES = {
    'planner': ['interviewerCompleted'],
    'high-player': ['interviewerCompleted', 'plannerCompleted'],
    'low-player': ['interviewerCompleted', 'plannerCompleted']
}

PHASE_NAMES = {
    'interviewerCompleted': 'Interviewer',
    'plannerCompleted': 'Planner'
}

try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    pp = d.get('planningPhase', {})

    required = REQUIRED_PHASES.get(target, [])
    missing = []
    for phase_key in required:
        if not pp.get(phase_key, False):
            missing.append(PHASE_NAMES[phase_key])

    if missing:
        print(','.join(missing))
        sys.exit(1)
    else:
        print('ALL_COMPLETE')
        sys.exit(0)
except Exception as e:
    print('ERROR:' + str(e), file=sys.stderr)
    sys.exit(1)
" "$target_agent" 2>>"$LOG_FILE")
    local exit_code=$?
    MISSING_PHASES="$result"
    return $exit_code
  else
    return 0  # state.json 없으면 통과 (graceful)
  fi
}

# 하위 호환성: 기존 함수명 유지 (Executor용)
check_planning_phase_completed() {
  check_required_phases "high-player"
}

# 차단 메시지 출력
print_block_message() {
  local target_agent="$1"
  local missing="$2"

  echo "⛔ Phase Gate Violation!"
  echo ""
  echo "$target_agent 호출이 차단되었습니다."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "❌ 누락된 선행 단계: $missing"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "OPEN-ENDED 작업은 반드시 다음 순서를 따라야 합니다:"
  echo ""
  echo "  1. Task(Interviewer)     → 요구사항 인터뷰"
  echo "  2. Task(Planner)         → 6-Section 프롬프트 (1 필요)"
  echo "  3. Task(Executor)        → 구현 실행 (1-2 필요)"
  echo ""

  # Interviewer 누락 시 Plan Mode 복구 힌트
  if echo "$missing" | grep -q "Interviewer"; then
    echo "💡 Plan Mode로 계획을 수립했다면:"
    echo "   → state.json의 planningPhase.interviewerCompleted = true 설정 후 재시도"
    echo ""
  fi

  # 에이전트별 다음 단계 힌트
  case "$target_agent" in
    planner)
      echo "💡 먼저 Interviewer를 호출하세요."
      ;;
    *)
      echo "💡 호출 예시:"
      echo "   Task(subagent_type=\"general-purpose\","
      echo "        description=\"Interviewer: {작업명}\","
      echo "        model=\"opus\","
      echo "        prompt=\"...\")"
      ;;
  esac
  echo ""

  # 사용자에게 전달할 메시지 템플릿
  echo "📢 사용자에게 전달:"
  echo "   '[Orchestra] ⏸️ $target_agent 실행 대기 중 — $missing 완료가 필요합니다.'"
  echo ""
}

# 메인 로직
main() {
  local target_agent
  target_agent=$(get_target_agent)

  log "Checking: target_agent=$target_agent"

  # Gate 대상 에이전트가 아니면 통과
  if ! is_gated_agent "$target_agent"; then
    log "PASS: Not a gated agent (agent=$target_agent)"
    exit 0
  fi

  # Rework 모드면 통과
  if is_rework_mode; then
    log "PASS: Rework mode active"
    exit 0
  fi

  # 에이전트별 필수 선행 단계 검증
  if ! check_required_phases "$target_agent"; then
    log "BLOCKED: Required phases incomplete for $target_agent (missing: $MISSING_PHASES)"
    print_block_message "$target_agent" "$MISSING_PHASES"
    exit 1
  fi

  log "PASS: All required phases completed, allowing $target_agent"
  exit 0
}

main
