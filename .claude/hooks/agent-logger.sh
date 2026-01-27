#!/usr/bin/env bash
# Agent execution logger for Claude Orchestra
# Usage: agent-logger.sh <pre|post> "$TOOL_INPUT" ["$TOOL_OUTPUT"]

MODE="$1"
TOOL_INPUT="$2"
TOOL_OUTPUT="$3"
LOG_FILE=".orchestra/logs/agents.log"

mkdir -p "$(dirname "$LOG_FILE")"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

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
    echo "[$TIMESTAMP] START: $AGENT_NAME | $DESCRIPTION" >> "$LOG_FILE"
elif [ "$MODE" = "post" ]; then
    # Extract summary from TOOL_OUTPUT (first 2 non-empty lines, max 120 chars)
    SUMMARY=$(echo "$TOOL_OUTPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    text = d.get('output', d.get('result', str(d)))
    lines = [l.strip() for l in text.strip().split('\n') if l.strip()][:2]
    print(' / '.join(lines)[:120])
except:
    text = sys.stdin.read() if not sys.stdin.closed else ''
    lines = [l.strip() for l in text.strip().split('\n') if l.strip()][:2]
    print(' / '.join(lines)[:120])
" 2>/dev/null || echo "completed")
    echo "[$TIMESTAMP] END: $AGENT_NAME | $SUMMARY" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"
fi
