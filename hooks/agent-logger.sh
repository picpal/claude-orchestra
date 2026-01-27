#!/usr/bin/env bash
# Agent execution logger for Claude Orchestra
# Usage: agent-logger.sh <pre|post> "$TOOL_INPUT" ["$TOOL_OUTPUT"]

MODE="$1"
TOOL_INPUT="$2"
TOOL_OUTPUT="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Extract agent info from TOOL_INPUT JSON
AGENT_NAME=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('subagent_type', d.get('description', 'unknown')))
except: print('unknown')
" 2>/dev/null || echo "unknown")

DESCRIPTION=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('description', '')[:80])
except: print('')
" 2>/dev/null || echo "")

if [ "$MODE" = "pre" ]; then
    "$SCRIPT_DIR/activity-logger.sh" AGENT "$AGENT_NAME" "$DESCRIPTION" 2>/dev/null || true
fi

# Hook 자체 활동도 기록
"$SCRIPT_DIR/activity-logger.sh" HOOK agent-logger "$MODE" 2>/dev/null || true
