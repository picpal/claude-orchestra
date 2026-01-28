#!/usr/bin/env bash
# Unified Activity Logger for Claude Orchestra
# Usage: activity-logger.sh <TYPE> <NAME> [DETAIL] [PHASE]
# TYPE: COMMAND | SKILL | HOOK | AGENT
# PHASE: CLASSIFY | INTERVIEW | RESEARCH | PLAN | EXECUTE | VERIFY | REVIEW | COMMIT | -

set -euo pipefail

TYPE="${1:-UNKNOWN}"
NAME="${2:-}"
DETAIL="${3:-}"
PHASE="${4:--}"

LOG_DIR=".orchestra/logs"
LOG_FILE="$LOG_DIR/activity.log"

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 타입을 7자로 패딩 (포맷 정렬)
PADDED_TYPE=$(printf '%-7s' "$TYPE")
# PHASE를 9자로 패딩 (포맷 정렬)
PADDED_PHASE=$(printf '%-9s' "$PHASE")

if [ -n "$DETAIL" ]; then
  echo "[$TIMESTAMP] $PADDED_TYPE | $PADDED_PHASE | $NAME | $DETAIL" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] $PADDED_TYPE | $PADDED_PHASE | $NAME" >> "$LOG_FILE"
fi
