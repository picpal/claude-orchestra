#!/usr/bin/env bash
# MCP Tool Logger for Claude Orchestra
# Usage: mcp-logger.sh <pre|post>
# Data is received via stdin JSON from Claude Code.
# Logs MCP tool calls to activity.log via activity-logger.sh

MODE="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/stdin-reader.sh"

# HOOK_TOOL_NAME contains the full tool name, e.g. "mcp__context7__resolve-library-id"
TOOL_NAME="$HOOK_TOOL_NAME"

# mcp__<server>__<tool> 형식에서 서버명과 도구명 추출
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
