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

# 에이전트 정보 저장 (subagent-start 시 호출)
cache_agent_info() {
  local agent_id="$1" agent_type="$2" description="$3"
  if [ -n "$agent_id" ] && [ -n "$agent_type" ]; then
    printf '%s\n%s' "$agent_type" "$description" > "$AGENT_CACHE_DIR/$agent_id"
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

    # 캐시에 저장 (subagent-stop에서 조회용)
    cache_agent_info "$AGENT_ID" "$AGENT_TYPE" "$DESCRIPTION"

    PHASE=$(resolve_phase "$AGENT_TYPE" "$DESCRIPTION")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_TYPE" "[start] id=${AGENT_ID:-?} $DESCRIPTION" "$PHASE" 2>/dev/null || true
    ;;

  subagent-stop)
    # SubagentStop: agent lifecycle tracking
    AGENT_TYPE=$(hook_get_field "agent_type")
    AGENT_ID=$(hook_get_field "agent_id")

    # JSON에 agent_type이 없으면 캐시에서 조회
    if [ -z "$AGENT_TYPE" ] && [ -n "$AGENT_ID" ]; then
      lookup_agent_info "$AGENT_ID"
      AGENT_TYPE="${CACHED_AGENT_TYPE:-unknown}"
      DESCRIPTION="${CACHED_DESCRIPTION:-}"
    fi

    if [ -z "$AGENT_TYPE" ]; then
      AGENT_TYPE="unknown"
    fi

    PHASE=$(resolve_phase "$AGENT_TYPE" "${DESCRIPTION:-}")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_TYPE" "[stop] id=${AGENT_ID:-?}" "$PHASE" 2>/dev/null || true
    ;;
esac

# Log hook activity
"$SCRIPT_DIR/activity-logger.sh" HOOK agent-logger "$MODE" 2>/dev/null || true
