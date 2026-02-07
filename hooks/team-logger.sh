#!/bin/bash
# team-logger.sh - Agent Teams 활동 로깅
# Hook: TeammateStart, TeammateStop

set -euo pipefail

ACTION="${1:-unknown}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_DIR="${ORCHESTRA_STATE_DIR:-.orchestra}/logs"
LOG_FILE="$LOG_DIR/team-activity.log"

# 로그 디렉토리 생성
mkdir -p "$LOG_DIR"

# 환경 변수에서 팀원 정보 추출
TEAMMATE_ID="${TEAMMATE_ID:-unknown}"
TEAMMATE_ROLE="${TEAMMATE_ROLE:-unknown}"

case "$ACTION" in
  start)
    echo "[$TIMESTAMP] TEAM_START: Teammate=$TEAMMATE_ID Role=$TEAMMATE_ROLE" >> "$LOG_FILE"

    # state.json 업데이트 (팀원 추가)
    if [ -f ".orchestra/state.json" ]; then
      python3 -c "
import json
import os
with open('.orchestra/state.json', 'r') as f:
    d = json.load(f)
if 'agentTeamsStatus' not in d:
    d['agentTeamsStatus'] = {'active': False, 'teammates': [], 'metrics': {'totalTeammates': 0}}
d['agentTeamsStatus']['active'] = True
teammate = {'id': '$TEAMMATE_ID', 'role': '$TEAMMATE_ROLE', 'startedAt': '$TIMESTAMP', 'status': 'running'}
d['agentTeamsStatus']['teammates'].append(teammate)
d['agentTeamsStatus']['metrics']['totalTeammates'] = len(d['agentTeamsStatus']['teammates'])
with open('.orchestra/state.json', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true
    fi
    ;;

  stop)
    echo "[$TIMESTAMP] TEAM_STOP: Teammate=$TEAMMATE_ID Role=$TEAMMATE_ROLE" >> "$LOG_FILE"

    # state.json 업데이트 (팀원 상태 변경)
    if [ -f ".orchestra/state.json" ]; then
      python3 -c "
import json
with open('.orchestra/state.json', 'r') as f:
    d = json.load(f)
if 'agentTeamsStatus' in d:
    for t in d['agentTeamsStatus'].get('teammates', []):
        if t.get('id') == '$TEAMMATE_ID':
            t['status'] = 'completed'
            t['completedAt'] = '$TIMESTAMP'
    # 모든 팀원이 완료되었으면 active = False
    all_completed = all(t.get('status') == 'completed' for t in d['agentTeamsStatus'].get('teammates', []))
    if all_completed and d['agentTeamsStatus'].get('teammates'):
        d['agentTeamsStatus']['active'] = False
with open('.orchestra/state.json', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true
    fi
    ;;

  *)
    echo "[$TIMESTAMP] TEAM_UNKNOWN: Action=$ACTION Teammate=$TEAMMATE_ID" >> "$LOG_FILE"
    ;;
esac

exit 0
