#!/bin/bash
# team-idle-handler.sh - 유휴 팀원 처리
# Hook: SubagentStop (idle detection)
#
# Agent Groups (Code-Review 등)의 경우:
# - 모든 팀원 완료 대기
# - 결과 통합 트리거
#
# ⚠️ hooks.json 미등록 — agent-logger.sh가 SubagentStop을 처리하므로
#    이 스크립트는 수동 호출 또는 향후 통합 시 사용

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

ensure_orchestra_dirs

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$ORCHESTRA_LOG_DIR/team-activity.log"

TEAMMATE_ID="${TEAMMATE_ID:-unknown}"

echo "[$TIMESTAMP] TEAM_IDLE: Teammate=$TEAMMATE_ID" >> "$LOG_FILE"

# state.json에서 팀 상태 확인
if [ -f "$ORCHESTRA_STATE_FILE" ]; then
  python3 -c "
import json
import sys
import os

state_file = sys.argv[1]
teammate_id = os.environ.get('TEAMMATE_ID', 'unknown')
timestamp = sys.argv[2]

try:
    with open(state_file, 'r') as f:
        d = json.load(f)

    teams = d.get('agentGroupsStatus', {})
    teammates = teams.get('teammates', [])

    # 현재 팀원 상태 업데이트
    for t in teammates:
        if t.get('id') == teammate_id:
            t['status'] = 'idle'

    # 모든 팀원이 idle 또는 completed인지 확인
    all_done = all(t.get('status') in ['idle', 'completed'] for t in teammates)

    if all_done and len(teammates) >= 2:
        teams['allCompleted'] = True
        teams['completedAt'] = timestamp
        print('TEAM_ALL_COMPLETED')

    with open(state_file, 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
except Exception:
    pass
" "$ORCHESTRA_STATE_FILE" "$TIMESTAMP" 2>/dev/null || true
fi

exit 0
