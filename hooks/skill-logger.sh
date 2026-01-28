#!/usr/bin/env bash
# Skill Logger for Claude Orchestra
# PreToolUse Hook (Skill 매처)
# Data is received via stdin JSON from Claude Code.
# Logs Skill tool calls to activity.log via activity-logger.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/stdin-reader.sh"

# Extract skill name from tool_input
SKILL_NAME=$(hook_get_field "tool_input.skill")
SKILL_ARGS=$(hook_get_field "tool_input.args")

if [ -z "$SKILL_NAME" ]; then
  SKILL_NAME="unknown"
fi

DETAIL="${SKILL_NAME}"
if [ -n "$SKILL_ARGS" ]; then
  DETAIL="${SKILL_NAME} args=${SKILL_ARGS:0:80}"
fi

"$SCRIPT_DIR/activity-logger.sh" SKILL "$SKILL_NAME" "$DETAIL" "-" 2>/dev/null || true
