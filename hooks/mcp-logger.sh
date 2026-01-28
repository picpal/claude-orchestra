#!/usr/bin/env bash
# MCP Tool Logger for Claude Orchestra
# Usage: mcp-logger.sh <pre|post> "$TOOL_INPUT" ["$TOOL_OUTPUT"]
# Logs MCP tool calls to activity.log via activity-logger.sh

MODE="$1"
INPUT="${TOOL_INPUT:-${2:-}}"
TOOL_NAME="${TOOL_USE_NAME:-unknown}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# mcp__<server>__<tool> 형식에서 서버명과 도구명 추출
# 예: mcp__context7__resolve-library-id → server=context7, tool=resolve-library-id
SERVER=$(echo "$TOOL_NAME" | sed -n 's/^mcp__\([^_]*\)__.*$/\1/p')
TOOL=$(echo "$TOOL_NAME" | sed -n 's/^mcp__[^_]*__\(.*\)$/\1/p')

if [ -z "$SERVER" ]; then
  SERVER="unknown"
  TOOL="$TOOL_NAME"
fi

DETAIL="server=$SERVER tool=$TOOL"

if [ "$MODE" = "pre" ]; then
  "$SCRIPT_DIR/activity-logger.sh" MCP "$SERVER/$TOOL" "$DETAIL" "RESEARCH" 2>/dev/null || true
elif [ "$MODE" = "post" ]; then
  "$SCRIPT_DIR/activity-logger.sh" MCP "$SERVER/$TOOL" "${DETAIL} [done]" "RESEARCH" 2>/dev/null || true
fi
