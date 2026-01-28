#!/usr/bin/env bash
# Agent execution logger for Claude Orchestra
# Usage: agent-logger.sh <pre|post> "$TOOL_INPUT" ["$TOOL_OUTPUT"]

MODE="$1"
# TOOL_INPUT/TOOL_OUTPUT: 환경변수 우선, 없으면 인자 fallback
# Claude Code는 환경변수로 설정하지만, JSON 특수문자 때문에
# 쉘 인자로 전달하면 깨질 수 있음
INPUT="${TOOL_INPUT:-$2}"
TOOL_OUTPUT="${TOOL_OUTPUT:-${3:-}}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 디버그: 실제 입력값 확인
DEBUG_LOG=".orchestra/logs/agent-debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') MODE=$MODE ==="
  echo "ARG2 (first 500): ${2:0:500}"
  echo "ENV TOOL_INPUT (first 500): ${TOOL_INPUT:0:500}"
  echo "INPUT (first 500): ${INPUT:0:500}"
  echo "---"
} >> "$DEBUG_LOG" 2>/dev/null || true

# Extract agent info from INPUT JSON
# python3 JSON 파싱 실패 시 grep fallback으로 추출
AGENT_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('subagent_type', d.get('description', '')))
except: print('')
" 2>/dev/null || echo "")

# JSON 파싱 실패 시 grep fallback
if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"subagent_type"\s*:\s*"[^"]+"' | sed 's/.*"subagent_type"\s*:\s*"//' | sed 's/"$//' || echo "")
fi
if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"description"\s*:\s*"[^"]+"' | sed 's/.*"description"\s*:\s*"//' | sed 's/"$//' || echo "unknown")
fi

DESCRIPTION=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('description', '')[:80])
except: print('')
" 2>/dev/null || echo "")

# description도 grep fallback
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$INPUT" | grep -oE '"description"\s*:\s*"[^"]+"' | sed 's/.*"description"\s*:\s*"//' | sed 's/"$//' | cut -c1-80 || echo "")
fi

# === PHASE 결정 함수 ===

# agent 이름 → PHASE 매핑
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
        *)
            resolve_from_description "$desc" ;;
    esac
}

# planner는 description 키워드로 세부 PHASE 구분
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

# 미지 agent에 대한 fallback: description 키워드 기반
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

if [ "$MODE" = "pre" ]; then
    PHASE=$(resolve_phase "$AGENT_NAME" "$DESCRIPTION")
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_NAME" "$DESCRIPTION" "$PHASE" 2>/dev/null || true
fi

# Hook 자체 활동도 기록
"$SCRIPT_DIR/activity-logger.sh" HOOK agent-logger "$MODE" 2>/dev/null || true
