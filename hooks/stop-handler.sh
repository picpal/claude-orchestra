#!/bin/bash
# Stop 훅 - journal 완전 자동 생성
# 코드 변경이 있으면 journal.md를 직접 생성하고 state.json을 업데이트 (사용자 개입 없음)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

ensure_orchestra_dirs

# 디버그 로깅
DEBUG_LOG="$ORCHESTRA_LOG_DIR/stop-handler-debug.log"
log_debug() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DEBUG_LOG" 2>/dev/null
}

log_debug "=== Stop hook triggered ==="
log_debug "SCRIPT_DIR: $SCRIPT_DIR"
log_debug "PWD: $PWD"

# === Learning 평가 실행 (백그라운드, 가장 먼저 실행) ===
run_learning_evaluation() {
  local learning_script="$SCRIPT_DIR/learning/evaluate-session.sh"
  local activity_log=".orchestra/logs/activity.log"

  log_debug "Learning script: $learning_script"
  log_debug "Activity log exists: $([ -f "$activity_log" ] && echo 'yes' || echo 'no')"

  if [ ! -x "$learning_script" ]; then
    log_debug "Learning script not executable or not found"
    return 0
  fi
  if [ ! -f "$activity_log" ]; then
    log_debug "Activity log not found"
    return 0
  fi

  log_debug "Starting learning evaluation in background..."
  nohup "$learning_script" evaluate "$activity_log" \
    >> ".orchestra/logs/learning.log" 2>&1 &
  log_debug "Learning evaluation started (PID: $!)"
}

# activity 로그가 있으면 learning 실행
run_learning_evaluation

source "$SCRIPT_DIR/stdin-reader.sh"

CHANGES_LOG="$ORCHESTRA_LOG_DIR/changes.jsonl"
STATE_FILE="$ORCHESTRA_STATE_FILE"
SESSION_FILE="$ORCHESTRA_LOG_DIR/session-start.txt"
ACTIVITY_LOG="$ORCHESTRA_LOG_DIR/activity.jsonl"
JOURNAL_DIR="$ORCHESTRA_DIR/journal"

# stdin에서 stop_hook_active 확인 (무한 루프 방지)
STOP_ACTIVE=$(hook_get_field "stop_hook_active")
log_debug "stop_hook_active: $STOP_ACTIVE"
if [ "$STOP_ACTIVE" = "true" ]; then
  log_debug "EXIT: Already blocked once"
  exit 0
fi

# 변경 로그가 없거나 비어있으면 통과
log_debug "CHANGES_LOG: $CHANGES_LOG"
if [ ! -f "$CHANGES_LOG" ] || [ ! -s "$CHANGES_LOG" ]; then
  log_debug "EXIT: No changes or empty"
  exit 0
fi

# 세션 시작 시간 확인
SESSION_START=0
if [ -f "$SESSION_FILE" ]; then
  SESSION_START=$(cat "$SESSION_FILE")
fi

# 최근 변경이 있는지 확인 (5분 이내)
if [[ "$OSTYPE" == "darwin"* ]]; then
  CHANGES_MTIME=$(stat -f %m "$CHANGES_LOG" 2>/dev/null)
else
  CHANGES_MTIME=$(stat -c %Y "$CHANGES_LOG" 2>/dev/null)
fi

NOW=$(date +%s)
DIFF=$((NOW - CHANGES_MTIME))

if [ "$DIFF" -gt 300 ]; then
  log_debug "EXIT: Changes older than 5 minutes"
  exit 0
fi

# 세션 시작 이전 변경은 무시
if [ "$SESSION_START" -gt 0 ] && [ "$CHANGES_MTIME" -lt "$SESSION_START" ]; then
  log_debug "EXIT: Changes before session start"
  exit 0
fi

# state.json에서 journalWritten 확인
if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
  JOURNAL_WRITTEN=$(jq -r '.workflowStatus.journalWritten // false' "$STATE_FILE" 2>/dev/null)
  if [ "$JOURNAL_WRITTEN" = "true" ]; then
    log_debug "EXIT: Journal already written"
    exit 0
  fi
fi

# === Journal 초안 데이터 생성 ===
CURRENT_DATE=$(date +%Y%m%d)
CURRENT_TIME=$(date +%H%M)
DRAFT_FILE="$JOURNAL_DIR/.draft-${CURRENT_DATE}-${CURRENT_TIME}.json"

mkdir -p "$JOURNAL_DIR"

# 변경된 파일 목록 추출 (JSON 배열)
CHANGED_FILES_JSON=$(jq -s '[.[].file] | unique' "$CHANGES_LOG" 2>/dev/null || echo '[]')

# 변경 내용 요약 추출 (최근 10개)
CHANGES_SUMMARY=$(jq -s '[-10:] | map({
  file: .file,
  tool: .tool,
  timestamp: .timestamp,
  preview: (if .tool == "Edit" then
    "변경: " + (.old_string[:50] // "") + " → " + (.new_string[:50] // "")
  else
    "생성: " + (.content_sample[:100] // "")
  end)
})' "$CHANGES_LOG" 2>/dev/null || echo '[]')

# Activity 로그에서 에이전트 활동 추출 (있으면)
AGENT_ACTIVITIES="[]"
if [ -f "$ACTIVITY_LOG" ]; then
  AGENT_ACTIVITIES=$(grep -E "^\[Agent\]" "$ACTIVITY_LOG" 2>/dev/null | tail -20 | \
    python3 -c "
import sys, json, re
activities = []
for line in sys.stdin:
    match = re.match(r'\[Agent\] (\w+) (started|completed|failed)', line.strip())
    if match:
        activities.append({'agent': match.group(1), 'status': match.group(2)})
print(json.dumps(activities))
" 2>/dev/null || echo '[]')
fi

# 초안 JSON 생성
python3 -c "
import json
import sys

draft = {
    'generated_at': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
    'session_date': '$CURRENT_DATE',
    'session_time': '$CURRENT_TIME',
    'changed_files': $CHANGED_FILES_JSON,
    'changes_summary': $CHANGES_SUMMARY,
    'agent_activities': $AGENT_ACTIVITIES,
    'suggested_path': '.orchestra/journal/session-${CURRENT_DATE}-${CURRENT_TIME}.md'
}

print(json.dumps(draft, indent=2, ensure_ascii=False))
" > "$DRAFT_FILE"

log_debug "Draft created: $DRAFT_FILE"

# 변경된 파일이 없으면 통과
FILE_COUNT=$(echo "$CHANGED_FILES_JSON" | jq 'length' 2>/dev/null || echo 0)
if [ "$FILE_COUNT" -eq 0 ]; then
  log_debug "EXIT: No changed files"
  rm -f "$DRAFT_FILE"
  exit 0
fi

# === Journal 자동 생성 (block 없이 직접 생성) ===
log_debug "Auto-generating journal..."

# 작업 제목 생성 (변경된 파일 기반)
WORK_TITLE=$(python3 -c "
import json
import sys

files = $CHANGED_FILES_JSON
if not files:
    print('session')
    sys.exit(0)

# 공통 경로 패턴 추출
paths = [f.split('/') for f in files]
if len(paths) == 1:
    # 단일 파일
    print(paths[0][-1].split('.')[0])
else:
    # 여러 파일 - 공통 디렉토리 또는 패턴 찾기
    common_dirs = set(paths[0])
    for p in paths[1:]:
        common_dirs &= set(p)

    if common_dirs - {'', '.'}:
        # 의미있는 공통 디렉토리 사용
        meaningful = [d for d in common_dirs if d not in ['', '.', 'src', 'lib', 'hooks']]
        if meaningful:
            print(meaningful[0])
        else:
            print('multi-file-changes')
    else:
        print('multi-file-changes')
" 2>/dev/null || echo "session")

# 파일 경로 생성 (작업제목-날짜-시간.md)
JOURNAL_FILE="$JOURNAL_DIR/${WORK_TITLE}-${CURRENT_DATE}-${CURRENT_TIME}.md"
log_debug "Journal file: $JOURNAL_FILE"

# Journal 마크다운 생성
DRAFT_FILE_PATH="$DRAFT_FILE" python3 << 'PYEOF' > "$JOURNAL_FILE"
import json
import os
from datetime import datetime

# 환경 변수에서 draft 파일 경로 읽기
draft_file = os.environ.get('DRAFT_FILE_PATH', '')

try:
    with open(draft_file, 'r') as f:
        draft = json.load(f)
except:
    draft = {}

# 기본값 설정
changed_files = draft.get('changed_files', [])
changes_summary = draft.get('changes_summary', [])
agent_activities = draft.get('agent_activities', [])
session_date = draft.get('session_date', datetime.now().strftime('%Y%m%d'))
session_time = draft.get('session_time', datetime.now().strftime('%H%M'))

# 도구 사용 통계
tools_used = {}
for change in changes_summary:
    tool = change.get('tool', 'Unknown')
    tools_used[tool] = tools_used.get(tool, 0) + 1

# 에이전트 활동 요약
agent_summary = {}
for act in agent_activities:
    agent = act.get('agent', 'Unknown')
    status = act.get('status', 'unknown')
    agent_summary[agent] = status

# 마크다운 생성
print(f"# Session Journal - {session_date[:4]}-{session_date[4:6]}-{session_date[6:]} {session_time[:2]}:{session_time[2:]}")
print()

# 작업 요약
print("## 작업 요약")
print(f"- 변경된 파일: {len(changed_files)}개")
if tools_used:
    tools_str = ", ".join([f"{k}({v})" for k, v in tools_used.items()])
    print(f"- 사용된 도구: {tools_str}")
print()

# 변경 파일 목록
print("## 변경 파일 목록")
for f in changed_files:
    print(f"- `{f}`")
print()

# 변경 내역 테이블
if changes_summary:
    print("## 변경 내역")
    print("| 시간 | 파일 | 도구 | 변경 내용 |")
    print("|------|------|------|----------|")
    for change in changes_summary:
        ts = change.get('timestamp', '')
        if ts:
            try:
                dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
                time_str = dt.strftime('%H:%M')
            except:
                time_str = ts[:5] if len(ts) >= 5 else ts
        else:
            time_str = '-'

        file_name = change.get('file', '-').split('/')[-1]
        tool = change.get('tool', '-')
        preview = change.get('preview', '-')[:50].replace('|', '\\|').replace('\n', ' ')

        print(f"| {time_str} | {file_name} | {tool} | {preview} |")
    print()

# 에이전트 활동
if agent_summary:
    print("## 에이전트 활동")
    for agent, status in agent_summary.items():
        status_emoji = "✅" if status == "completed" else "🔄" if status == "started" else "❌"
        print(f"- {agent}: {status_emoji} {status}")
    print()

# 자동 생성 표시
print("---")
print("*이 journal은 stop-handler.sh에 의해 자동 생성되었습니다.*")
PYEOF

log_debug "Journal generated: $JOURNAL_FILE"

# === state.json 업데이트 ===
if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
  # journalWritten: true, mode: IDLE 설정
  UPDATED_STATE=$(jq '.workflowStatus.journalWritten = true | .workflowStatus.mode = "IDLE"' "$STATE_FILE" 2>/dev/null)
  if [ -n "$UPDATED_STATE" ]; then
    echo "$UPDATED_STATE" > "$STATE_FILE"
    log_debug "state.json updated: journalWritten=true, mode=IDLE"
  fi
fi

# 초안 파일 정리
rm -f "$DRAFT_FILE"
log_debug "Draft file cleaned up"

log_debug "EXIT: Journal auto-generated successfully"
exit 0
