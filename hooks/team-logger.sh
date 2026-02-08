#!/bin/bash
# team-logger.sh - Agent Teams 활동 로깅
# Hook: TeammateStart, TeammateStop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

ensure_orchestra_dirs

ACTION="${1:-unknown}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$ORCHESTRA_LOG_DIR/team-activity.log"

# 환경 변수에서 팀원 정보 추출
TEAMMATE_ID="${TEAMMATE_ID:-unknown}"
TEAMMATE_ROLE="${TEAMMATE_ROLE:-unknown}"

case "$ACTION" in
  start)
    echo "[$TIMESTAMP] TEAM_START: Teammate=$TEAMMATE_ID Role=$TEAMMATE_ROLE" >> "$LOG_FILE"

    # state.json 업데이트 (팀원 추가)
    if [ -f "$ORCHESTRA_STATE_FILE" ]; then
      python3 -c "
import json
import sys
state_file = sys.argv[1]
teammate_id = sys.argv[2]
teammate_role = sys.argv[3]
timestamp = sys.argv[4]
with open(state_file, 'r') as f:
    d = json.load(f)
if 'agentTeamsStatus' not in d:
    d['agentTeamsStatus'] = {'active': False, 'teammates': [], 'metrics': {'totalTeammates': 0}}
d['agentTeamsStatus']['active'] = True
teammate = {'id': teammate_id, 'role': teammate_role, 'startedAt': timestamp, 'status': 'running'}
d['agentTeamsStatus']['teammates'].append(teammate)
d['agentTeamsStatus']['metrics']['totalTeammates'] = len(d['agentTeamsStatus']['teammates'])
with open(state_file, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" "$ORCHESTRA_STATE_FILE" "$TEAMMATE_ID" "$TEAMMATE_ROLE" "$TIMESTAMP" 2>/dev/null || true
    fi
    ;;

  stop)
    echo "[$TIMESTAMP] TEAM_STOP: Teammate=$TEAMMATE_ID Role=$TEAMMATE_ROLE" >> "$LOG_FILE"

    # state.json 업데이트 (팀원 상태 변경)
    if [ -f "$ORCHESTRA_STATE_FILE" ]; then
      python3 -c "
import json
import sys
state_file = sys.argv[1]
teammate_id = sys.argv[2]
timestamp = sys.argv[3]
with open(state_file, 'r') as f:
    d = json.load(f)
if 'agentTeamsStatus' in d:
    for t in d['agentTeamsStatus'].get('teammates', []):
        if t.get('id') == teammate_id:
            t['status'] = 'completed'
            t['completedAt'] = timestamp
    # 모든 팀원이 완료되었으면 active = False
    all_completed = all(t.get('status') == 'completed' for t in d['agentTeamsStatus'].get('teammates', []))
    if all_completed and d['agentTeamsStatus'].get('teammates'):
        d['agentTeamsStatus']['active'] = False
with open(state_file, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" "$ORCHESTRA_STATE_FILE" "$TEAMMATE_ID" "$TIMESTAMP" 2>/dev/null || true
    fi
    ;;

  *)
    echo "[$TIMESTAMP] TEAM_UNKNOWN: Action=$ACTION Teammate=$TEAMMATE_ID" >> "$LOG_FILE"
    ;;
esac

exit 0
