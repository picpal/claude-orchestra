#!/usr/bin/env bash
# execution-parallel-check.sh
# PreToolUse/Task hook: Warns when sequential single Executor calls are made
# for a Level that has multiple TODOs (should be parallel).
#
# This hook does NOT block (exit 0 always). It outputs a warning message
# to guide Maestro toward parallel Task calls.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

# Only check Executor calls (high-player, low-player)
DESCRIPTION=$(hook_get_field "tool_input.description")
DESC_LOWER=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')

case "$DESC_LOWER" in
  high-player:*|low-player:*|*high-player*|*low-player*) ;;
  *) exit 0 ;;
esac

# Check state.json for current level info
STATE_FILE="$ORCHESTRA_STATE_FILE"
[ -f "$STATE_FILE" ] || exit 0

# Extract current level's todoCount from state
TODO_COUNT=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        d = json.load(f)
    level = d.get('progress', {}).get('currentLevel', 0)
    todos = d.get('todos', [])
    level_todos = [t for t in todos if t.get('level') == level]
    pending = [t for t in level_todos if t.get('status') in ('pending', 'in_progress')]
    print(len(level_todos))
except Exception:
    print('0')
" "$STATE_FILE" 2>/dev/null)

# If this level has 2+ TODOs, warn about parallel execution
if [ "${TODO_COUNT:-0}" -ge 2 ]; then
  echo "⚠️ [execution-parallel-check] 현재 Level에 TODO가 ${TODO_COUNT}개 있습니다."
  echo "   한 메시지에 여러 Task()를 병렬로 호출하세요."
  echo "   (예: Task(High-Player: todo-1) + Task(Low-Player: todo-2) 동시 호출)"
fi

# Always pass (warning only, not blocking)
exit 0
