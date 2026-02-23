#!/bin/bash
# team-idle-handler.sh - 유휴 팀원 처리
# Hook: TeammateIdle
#
# Plan Validation Team의 경우:
# - 모든 팀원 완료 대기
# - 결과 통합 트리거

set -euo pipefail

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_DIR="${ORCHESTRA_STATE_DIR:-.orchestra}/logs"
LOG_FILE="$LOG_DIR/team-activity.log"

mkdir -p "$LOG_DIR"

TEAMMATE_ID="${TEAMMATE_ID:-unknown}"

echo "[$TIMESTAMP] TEAM_IDLE: Teammate=$TEAMMATE_ID" >> "$LOG_FILE"

# state.json에서 팀 상태 확인
if [ -f ".orchestra/state.json" ]; then
  python3 -c "
import json
import sys

with open('.orchestra/state.json', 'r') as f:
    d = json.load(f)

teams = d.get('agentTeamsStatus', {})
teammates = teams.get('teammates', [])

# 현재 팀원 상태 업데이트
for t in teammates:
    if t.get('id') == '$TEAMMATE_ID':
        t['status'] = 'idle'

# 모든 팀원이 idle 또는 completed인지 확인
all_done = all(t.get('status') in ['idle', 'completed'] for t in teammates)

if all_done and len(teammates) >= 2:
    # 모든 팀원이 완료됨 (Plan Validation, Code-Review, Execution 등)
    teams['allCompleted'] = True
    teams['completedAt'] = '$TIMESTAMP'
    print('TEAM_ALL_COMPLETED')

with open('.orchestra/state.json', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true
fi

exit 0
