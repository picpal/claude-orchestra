#!/usr/bin/env bash
# Agent execution logger for Claude Orchestra
# Called by hooks for: PreToolUse/Task, PostToolUse/Task, SubagentStart, SubagentStop
# Usage: agent-logger.sh <pre|post|subagent-start|subagent-stop>
# Data is received via stdin JSON from Claude Code.

MODE="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/stdin-reader.sh"

# Debug log
DEBUG_LOG=".orchestra/logs/agent-debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') MODE=$MODE ==="
  echo "HOOK_EVENT: $HOOK_EVENT"
  echo "HOOK_TOOL_NAME: $HOOK_TOOL_NAME"
  echo "HOOK_TOOL_INPUT (first 500): ${HOOK_TOOL_INPUT:0:500}"
  echo "---"
} >> "$DEBUG_LOG" 2>/dev/null || true

# === Agent cache (start↔stop 간 상태 공유) ===
AGENT_CACHE_DIR=".orchestra/logs/.agent-cache"
mkdir -p "$AGENT_CACHE_DIR" 2>/dev/null || true

# 에이전트 스택 파일 (현재 활성 에이전트 추적)
AGENT_STACK_FILE=".orchestra/logs/.agent-stack"

# 에이전트 정보 저장 (subagent-start 시 호출)
cache_agent_info() {
  local agent_id="$1" agent_type="$2" description="$3"
  if [ -n "$agent_id" ] && [ -n "$agent_type" ]; then
    printf '%s\n%s' "$agent_type" "$description" > "$AGENT_CACHE_DIR/$agent_id"
  fi
}

# 에이전트 스택에 push (subagent-start 시 호출)
push_agent_stack() {
  local agent_id="$1" agent_type="$2" description="$3"
  # 스택에 추가 (형식: agent_id|agent_type|description)
  echo "${agent_id}|${agent_type}|${description}" >> "$AGENT_STACK_FILE"
}

# 에이전트 스택에서 pop (subagent-stop 시 호출)
pop_agent_stack() {
  local agent_id="$1"
  if [ -f "$AGENT_STACK_FILE" ]; then
    # 해당 agent_id 라인 제거
    grep -v "^${agent_id}|" "$AGENT_STACK_FILE" > "${AGENT_STACK_FILE}.tmp" 2>/dev/null || true
    mv "${AGENT_STACK_FILE}.tmp" "$AGENT_STACK_FILE" 2>/dev/null || true
  fi
}

# 현재 활성 에이전트 타입 조회 (스택 top)
get_current_agent_type() {
  if [ -f "$AGENT_STACK_FILE" ]; then
    tail -1 "$AGENT_STACK_FILE" 2>/dev/null | cut -d'|' -f2
  fi
}

# 에이전트 정보 조회 + 삭제 (subagent-stop 시 호출)
lookup_agent_info() {
  local agent_id="$1"
  local cache_file="$AGENT_CACHE_DIR/$agent_id"
  if [ -f "$cache_file" ]; then
    CACHED_AGENT_TYPE=$(sed -n '1p' "$cache_file")
    CACHED_DESCRIPTION=$(sed -n '2p' "$cache_file")
    rm -f "$cache_file" 2>/dev/null || true
  else
    CACHED_AGENT_TYPE=""
    CACHED_DESCRIPTION=""
  fi
}

# === Planning Phase 자동 업데이트 ===

# Planning 플래그 업데이트 함수 (python3 사용)
update_planning_flag() {
  local flag="$1"
  local state_file=".orchestra/state.json"

  if [ -f "$state_file" ]; then
    python3 -c "
import json
import sys

flag = sys.argv[1]
state_file = sys.argv[2]

try:
    with open(state_file, 'r') as f:
        d = json.load(f)

    if 'planningPhase' not in d:
        d['planningPhase'] = {}

    d['planningPhase'][flag] = True

    with open(state_file, 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
except Exception as e:
    print(f'Warning: Failed to update {flag}: {e}', file=sys.stderr)
" "$flag" "$state_file" 2>/dev/null || true
  fi
}

# Planning 에이전트 완료 감지 및 state.json 업데이트
# 정확한 매칭을 위해 "^에이전트명:" 또는 "에이전트명 에이전트" 패턴 사용
detect_and_update_planning_phase() {
  local desc="${1:-}"
  local desc_lower
  desc_lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')

  local planning_log=".orchestra/logs/planning-detection.log"
  mkdir -p "$(dirname "$planning_log")" 2>/dev/null || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking: $desc_lower" >> "$planning_log" 2>/dev/null || true

  # Interviewer 완료 감지 (예: "Interviewer: 요구사항 인터뷰")
  if echo "$desc_lower" | grep -qE '^interviewer:'; then
    update_planning_flag "interviewerCompleted"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Planning phase: Interviewer completed" >> "$planning_log" 2>/dev/null || true
  fi

  # Plan-Checker 완료 감지
  if echo "$desc_lower" | grep -qE '^plan-checker:|plan.checker'; then
    update_planning_flag "planCheckerCompleted"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Planning phase: Plan-Checker completed" >> "$planning_log" 2>/dev/null || true
  fi

  # Planner 완료 감지 (주의: Plan-Checker, Plan-Reviewer와 구분)
  # "Planner:" 로 시작하거나 "Planner 에이전트"만 매칭
  # Plan-Checker, Plan-Reviewer 제외를 위해 부정 조건 추가
  if echo "$desc_lower" | grep -qE '^planner:|planner 에이전트|planner: todo'; then
    # Plan-Checker, Plan-Reviewer가 아닌 경우에만
    if ! echo "$desc_lower" | grep -qE '^plan-checker:|^plan-reviewer:|plan.checker|plan.reviewer'; then
      update_planning_flag "plannerCompleted"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Planning phase: Planner completed" >> "$planning_log" 2>/dev/null || true
    fi
  fi
}

# === PHASE resolution functions ===

resolve_phase() {
    local agent="$1"
    local desc="$2"
    local agent_lower
    agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')

    case "$agent_lower" in
        maestro)
            echo "CLASSIFY" ;;
        interviewer)
            echo "INTERVIEW" ;;
        explorer|searcher|architecture|image-analyst)
            echo "RESEARCH" ;;
        plan-checker|plan-reviewer)
            echo "PLAN" ;;
        high-player|low-player)
            echo "EXECUTE" ;;
        conflict-checker)
            echo "VERIFY" ;;
        code-reviewer)
            echo "REVIEW" ;;
        planner)
            resolve_planner_phase "$desc" ;;
        # Claude Code built-in subagent types
        explore)
            echo "RESEARCH" ;;
        plan)
            echo "PLAN" ;;
        bash)
            echo "EXECUTE" ;;
        general-purpose)
            resolve_from_description "$desc" ;;
        *)
            resolve_from_description "$desc" ;;
    esac
}

resolve_planner_phase() {
    local desc="$1"
    local desc_lower
    desc_lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')

    if echo "$desc_lower" | grep -qE 'commit|git'; then
        echo "COMMIT"
    elif echo "$desc_lower" | grep -qE 'verif|check|test|validate'; then
        echo "VERIFY"
    elif echo "$desc_lower" | grep -qE 'execut|implement|run|build'; then
        echo "EXECUTE"
    else
        echo "PLAN"
    fi
}

resolve_from_description() {
    local desc="$1"
    local desc_lower
    desc_lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')

    if echo "$desc_lower" | grep -qE 'classif|intent|분류'; then
        echo "CLASSIFY"
    elif echo "$desc_lower" | grep -qE 'interview|requirement|요구사항'; then
        echo "INTERVIEW"
    elif echo "$desc_lower" | grep -qE 'search|explore|find|분석|탐색'; then
        echo "RESEARCH"
    elif echo "$desc_lower" | grep -qE 'plan|설계|계획'; then
        echo "PLAN"
    elif echo "$desc_lower" | grep -qE 'implement|code|구현|작성'; then
        echo "EXECUTE"
    elif echo "$desc_lower" | grep -qE 'verif|check|test|검증'; then
        echo "VERIFY"
    elif echo "$desc_lower" | grep -qE 'review|리뷰|검토'; then
        echo "REVIEW"
    elif echo "$desc_lower" | grep -qE 'commit|git|커밋'; then
        echo "COMMIT"
    else
        echo "-"
    fi
}

# === Mode handlers ===

case "$MODE" in
  pre)
    # PreToolUse/Task: extract subagent_type and description from tool_input
    AGENT_NAME=$(hook_get_field "tool_input.subagent_type")
    DESCRIPTION=$(hook_get_field "tool_input.description")

    # Truncate description to 80 chars
    DESCRIPTION="${DESCRIPTION:0:80}"

    if [ -z "$AGENT_NAME" ]; then
      AGENT_NAME="unknown"
    fi

    PHASE=$(resolve_phase "$AGENT_NAME" "$DESCRIPTION")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_NAME" "$DESCRIPTION" "$PHASE" 2>/dev/null || true
    ;;

  post)
    # PostToolUse/Task: log completion
    AGENT_NAME=$(hook_get_field "tool_input.subagent_type")
    DESCRIPTION=$(hook_get_field "tool_input.description")
    DESCRIPTION="${DESCRIPTION:0:80}"

    if [ -z "$AGENT_NAME" ]; then
      AGENT_NAME="unknown"
    fi

    PHASE=$(resolve_phase "$AGENT_NAME" "$DESCRIPTION")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_NAME" "[done] $DESCRIPTION" "$PHASE" 2>/dev/null || true
    ;;

  subagent-start)
    # SubagentStart: agent lifecycle tracking
    AGENT_TYPE=$(hook_get_field "agent_type")
    AGENT_ID=$(hook_get_field "agent_id")
    DESCRIPTION=$(hook_get_field "description")
    DESCRIPTION="${DESCRIPTION:0:80}"

    if [ -z "$AGENT_TYPE" ]; then
      AGENT_TYPE="unknown"
    fi

    # description에서 실제 에이전트 이름 추출 (예: "Planner: 계획 실행" → "planner")
    ACTUAL_AGENT=""
    DESC_LOWER=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')
    if echo "$DESC_LOWER" | grep -qE '^planner:|planner 에이전트|계획 실행'; then
      ACTUAL_AGENT="planner"
    elif echo "$DESC_LOWER" | grep -qE '^high-player:|high player'; then
      ACTUAL_AGENT="high-player"
    elif echo "$DESC_LOWER" | grep -qE '^low-player:|low player'; then
      ACTUAL_AGENT="low-player"
    elif echo "$DESC_LOWER" | grep -qE '^interviewer:'; then
      ACTUAL_AGENT="interviewer"
    elif echo "$DESC_LOWER" | grep -qE '^plan-checker:'; then
      ACTUAL_AGENT="plan-checker"
    elif echo "$DESC_LOWER" | grep -qE '^plan-reviewer:'; then
      ACTUAL_AGENT="plan-reviewer"
    elif echo "$DESC_LOWER" | grep -qE '^conflict-checker:|conflict.checker|충돌.검사'; then
      ACTUAL_AGENT="conflict-checker"
    elif echo "$DESC_LOWER" | grep -qE '^code-reviewer:|code.reviewer|코드.리뷰'; then
      ACTUAL_AGENT="code-reviewer"
    else
      ACTUAL_AGENT="$AGENT_TYPE"
    fi

    # 캐시에 저장 (subagent-stop에서 조회용)
    cache_agent_info "$AGENT_ID" "$ACTUAL_AGENT" "$DESCRIPTION"

    # 에이전트 스택에 push (도구 제한 추적용)
    push_agent_stack "$AGENT_ID" "$ACTUAL_AGENT" "$DESCRIPTION"

    PHASE=$(resolve_phase "$ACTUAL_AGENT" "$DESCRIPTION")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$ACTUAL_AGENT" "[start] id=${AGENT_ID:-?} $DESCRIPTION" "$PHASE" 2>/dev/null || true
    ;;

  subagent-stop)
    # SubagentStop: agent lifecycle tracking
    AGENT_TYPE=$(hook_get_field "agent_type")
    AGENT_ID=$(hook_get_field "agent_id")
    DESCRIPTION=$(hook_get_field "description")

    # JSON에 정보가 없으면 캐시에서 조회
    if [ -n "$AGENT_ID" ]; then
      lookup_agent_info "$AGENT_ID"
      if [ -z "$AGENT_TYPE" ]; then
        AGENT_TYPE="${CACHED_AGENT_TYPE:-unknown}"
      fi
      if [ -z "$DESCRIPTION" ]; then
        DESCRIPTION="${CACHED_DESCRIPTION:-}"
      fi
    fi

    if [ -z "$AGENT_TYPE" ]; then
      AGENT_TYPE="unknown"
    fi

    # 에이전트 스택에서 pop (도구 제한 추적용)
    pop_agent_stack "$AGENT_ID"

    # Planning 에이전트 완료 감지 및 state.json 업데이트
    detect_and_update_planning_phase "${DESCRIPTION:-}"

    PHASE=$(resolve_phase "$AGENT_TYPE" "${DESCRIPTION:-}")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_TYPE" "[stop] id=${AGENT_ID:-?}" "$PHASE" 2>/dev/null || true
    ;;
esac

# Log hook activity
"$SCRIPT_DIR/activity-logger.sh" HOOK agent-logger "$MODE" 2>/dev/null || true
