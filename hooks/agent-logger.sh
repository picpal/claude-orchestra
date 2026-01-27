#!/usr/bin/env bash
# Agent execution logger for Claude Orchestra
# Usage: agent-logger.sh <pre|post> "$TOOL_INPUT" ["$TOOL_OUTPUT"]

MODE="$1"
TOOL_INPUT="$2"
TOOL_OUTPUT="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Extract agent info from TOOL_INPUT JSON
# python3 JSON 파싱 실패 시 grep fallback으로 추출
AGENT_NAME=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('subagent_type', d.get('description', '')))
except: print('')
" 2>/dev/null || echo "")

# JSON 파싱 실패 시 grep fallback
if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME=$(echo "$TOOL_INPUT" | grep -oE '"subagent_type"\s*:\s*"[^"]+"' | sed 's/.*"subagent_type"\s*:\s*"//' | sed 's/"$//' || echo "")
fi
if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME=$(echo "$TOOL_INPUT" | grep -oE '"description"\s*:\s*"[^"]+"' | sed 's/.*"description"\s*:\s*"//' | sed 's/"$//' || echo "unknown")
fi

DESCRIPTION=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('description', '')[:80])
except: print('')
" 2>/dev/null || echo "")

# description도 grep fallback
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$TOOL_INPUT" | grep -oE '"description"\s*:\s*"[^"]+"' | sed 's/.*"description"\s*:\s*"//' | sed 's/"$//' | cut -c1-80 || echo "")
fi

if [ "$MODE" = "pre" ]; then
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_NAME" "$DESCRIPTION" 2>/dev/null || true
fi

# Hook 자체 활동도 기록
"$SCRIPT_DIR/activity-logger.sh" HOOK agent-logger "$MODE" 2>/dev/null || true
