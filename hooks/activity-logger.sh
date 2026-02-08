#!/usr/bin/env bash
# Unified Activity Logger for Claude Orchestra
# Usage: activity-logger.sh <TYPE> <NAME> [DETAIL] [PHASE]
# TYPE: COMMAND | SKILL | HOOK | AGENT
# PHASE: CLASSIFY | INTERVIEW | RESEARCH | PLAN | EXECUTE | VERIFY | REVIEW | COMMIT | -

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

TYPE="${1:-UNKNOWN}"
NAME="${2:-}"
DETAIL="${3:-}"
PHASE="${4:--}"

LOG_FILE="$ORCHESTRA_LOG_DIR/activity.jsonl"

ensure_orchestra_dirs

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')

# JSONL 형식으로 출력 (python3 사용하여 올바른 JSON 이스케이핑)
python3 -c "
import json
import sys

data = {
    'ts': sys.argv[1],
    'type': sys.argv[2],
    'phase': sys.argv[3],
    'name': sys.argv[4],
    'detail': sys.argv[5] if len(sys.argv) > 5 else ''
}
print(json.dumps(data, ensure_ascii=False))
" "$TIMESTAMP" "$TYPE" "$PHASE" "$NAME" "$DETAIL" >> "$LOG_FILE" 2>/dev/null || true
