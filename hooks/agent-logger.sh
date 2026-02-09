#!/usr/bin/env bash
# Agent execution logger for Claude Orchestra (Simplified)
# Called by hooks for: PreToolUse/Task, PostToolUse/Task, SubagentStart, SubagentStop
# Usage: agent-logger.sh <pre|post|subagent-start|subagent-stop>
#
# Core functions:
#   - Planning Phase detection (state.json update)
#   - Agent stack tracking (for tool restrictions)

MODE="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

# === Agent Stack (for tool restriction tracking) ===
AGENT_STACK_FILE="$ORCHESTRA_LOG_DIR/.agent-stack"
AGENT_CACHE_DIR="$ORCHESTRA_LOG_DIR/.agent-cache"
mkdir -p "$AGENT_CACHE_DIR" 2>/dev/null || true

cache_agent_info() {
  local agent_id="$1" agent_type="$2" description="$3"
  if [ -n "$agent_id" ] && [ -n "$agent_type" ]; then
    printf '%s\n%s' "$agent_type" "$description" > "$AGENT_CACHE_DIR/$agent_id"
  fi
}

push_agent_stack() {
  local agent_id="$1" agent_type="$2" description="$3"
  echo "${agent_id}|${agent_type}|${description}" >> "$AGENT_STACK_FILE"
}

pop_agent_stack() {
  local agent_id="$1"
  if [ -f "$AGENT_STACK_FILE" ]; then
    grep -v "^${agent_id}|" "$AGENT_STACK_FILE" > "${AGENT_STACK_FILE}.tmp" 2>/dev/null || true
    mv "${AGENT_STACK_FILE}.tmp" "$AGENT_STACK_FILE" 2>/dev/null || true
  fi
}

get_current_agent_type() {
  if [ -f "$AGENT_STACK_FILE" ]; then
    tail -1 "$AGENT_STACK_FILE" 2>/dev/null | cut -d'|' -f2
  fi
}

lookup_agent_info() {
  local agent_id="$1"
  local cache_file="$AGENT_CACHE_DIR/$agent_id"
  if [ -f "$cache_file" ]; then
    CACHED_AGENT_TYPE=$(head -1 "$cache_file")
    CACHED_DESCRIPTION=$(tail -1 "$cache_file")
    rm -f "$cache_file" 2>/dev/null || true
  else
    CACHED_AGENT_TYPE=""
    CACHED_DESCRIPTION=""
  fi
}

# === Planning Phase Detection ===

update_planning_flag() {
  local flag="$1"
  local state_file="$ORCHESTRA_STATE_FILE"

  [ -f "$state_file" ] || return 0

  python3 -c "
import json, sys
flag, state_file = sys.argv[1], sys.argv[2]
try:
    with open(state_file, 'r') as f:
        d = json.load(f)
    d.setdefault('planningPhase', {})[flag] = True
    with open(state_file, 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
except Exception:
    pass
" "$flag" "$state_file" 2>/dev/null || true
}

reset_planning_phase() {
  local state_file="$ORCHESTRA_STATE_FILE"

  [ -f "$state_file" ] || return 0

  python3 -c "
import json, sys
from datetime import datetime
state_file = sys.argv[1]
try:
    with open(state_file, 'r') as f:
        d = json.load(f)
    d['planningPhase'] = {
        'interviewerCompleted': False,
        'planCheckerCompleted': False,
        'planReviewerCompleted': False,
        'plannerCompleted': False,
        'resetAt': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    }
    with open(state_file, 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
except Exception:
    pass
" "$state_file" 2>/dev/null || true
}

detect_planning_agent() {
  local desc="${1:-}"
  local desc_lower
  desc_lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')

  case "$desc_lower" in
    interviewer:*) update_planning_flag "interviewerCompleted" ;;
    plan-checker:*|*plan.checker*) update_planning_flag "planCheckerCompleted" ;;
    plan-reviewer:*|*plan.reviewer*) update_planning_flag "planReviewerCompleted" ;;
    planner:*|*planner\ 에이전트*|*planner:\ todo*)
      # Exclude plan-checker, plan-reviewer
      case "$desc_lower" in
        *plan-checker*|*plan-reviewer*) ;;
        *) update_planning_flag "plannerCompleted" ;;
      esac
      ;;
  esac
}

extract_agent_name() {
  local desc="${1:-}"
  local desc_lower
  desc_lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')

  case "$desc_lower" in
    planner:*|*planner\ 에이전트*) echo "planner" ;;
    high-player:*|*high\ player*) echo "high-player" ;;
    low-player:*|*low\ player*) echo "low-player" ;;
    interviewer:*) echo "interviewer" ;;
    plan-checker:*) echo "plan-checker" ;;
    plan-reviewer:*) echo "plan-reviewer" ;;
    conflict-checker:*|*conflict.checker*) echo "conflict-checker" ;;
    code-reviewer:*|*code.reviewer*) echo "code-reviewer" ;;
    *) echo "${2:-unknown}" ;;
  esac
}

# === Mode Handlers ===

case "$MODE" in
  pre|post)
    # PreToolUse/PostToolUse Task - minimal logging
    ;;

  subagent-start)
    AGENT_TYPE=$(hook_get_field "agent_type")
    AGENT_ID=$(hook_get_field "agent_id")
    DESCRIPTION=$(hook_get_field "description")
    DESCRIPTION="${DESCRIPTION:0:80}"

    ACTUAL_AGENT=$(extract_agent_name "$DESCRIPTION" "$AGENT_TYPE")

    cache_agent_info "$AGENT_ID" "$ACTUAL_AGENT" "$DESCRIPTION"
    push_agent_stack "$AGENT_ID" "$ACTUAL_AGENT" "$DESCRIPTION"

    # Reset planning phase when new interview starts
    if [ "$ACTUAL_AGENT" = "interviewer" ]; then
      reset_planning_phase
    fi
    ;;

  subagent-stop)
    AGENT_TYPE=$(hook_get_field "agent_type")
    AGENT_ID=$(hook_get_field "agent_id")
    DESCRIPTION=$(hook_get_field "description")

    if [ -n "$AGENT_ID" ]; then
      lookup_agent_info "$AGENT_ID"
      [ -z "$AGENT_TYPE" ] && AGENT_TYPE="${CACHED_AGENT_TYPE:-unknown}"
      [ -z "$DESCRIPTION" ] && DESCRIPTION="${CACHED_DESCRIPTION:-}"
    fi

    pop_agent_stack "$AGENT_ID"
    detect_planning_agent "${DESCRIPTION:-}"
    ;;
esac
