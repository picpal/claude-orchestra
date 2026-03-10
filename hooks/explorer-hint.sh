#!/bin/bash
# Explorer Hint Hook - Main Agent가 직접 코드 탐색 시 힌트 제공
# PreToolUse/Read, PreToolUse/Grep 이벤트에서 실행됨
# 차단하지 않고 힌트만 제공 (soft guidance)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

LOG_FILE="$ORCHESTRA_LOG_DIR/explorer-hint.log"

# 로깅 함수
log() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# state.json에서 현재 모드 확인
get_current_mode() {
  local state_file="$ORCHESTRA_STATE_FILE"
  if [ -f "$state_file" ]; then
    python3 -c "
import json
import sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    print(d.get('mode', 'IDLE'))
except:
    print('IDLE')
" "$state_file" 2>/dev/null
  else
    echo "IDLE"
  fi
}

# 코드 파일인지 확인
is_code_file() {
  local file_path="$1"

  # 제외할 경로 (설정/상태 파일들)
  if echo "$file_path" | grep -qE '\.orchestra/|\.claude/|\.git/|node_modules/|\.md$|\.json$|\.yaml$|\.yml$|\.txt$|\.log$'; then
    return 1
  fi

  # 코드 파일 확장자
  if echo "$file_path" | grep -qE '\.(js|ts|tsx|jsx|py|go|rs|java|c|cpp|h|hpp|rb|php|swift|kt|scala|sh|bash|zsh)$'; then
    return 0
  fi

  return 1
}

# 메인 로직
# Note: role-boundary-guard.sh가 먼저 실행되어 Interviewer 등의 역할 경계를 차단합니다.
#       이 Hook은 Main Agent에 대한 소프트 힌트만 제공합니다.
main() {
  local tool_name
  tool_name=$(hook_get_field "tool_name")

  local file_path=""

  # Read 도구: file_path 필드
  if [ "$tool_name" = "Read" ]; then
    file_path=$(hook_get_field "tool_input.file_path")
  # Grep 도구: path 필드
  elif [ "$tool_name" = "Grep" ]; then
    file_path=$(hook_get_field "tool_input.path")
  # Glob 도구: path 필드
  elif [ "$tool_name" = "Glob" ]; then
    file_path=$(hook_get_field "tool_input.path")
  fi

  # 파일 경로가 없으면 통과
  if [ -z "$file_path" ]; then
    exit 0
  fi

  # 코드 파일이 아니면 통과
  if ! is_code_file "$file_path"; then
    log "PASS: Not a code file ($file_path)"
    exit 0
  fi

  # EXECUTE 모드면 힌트 생략 (Executor가 작업 중)
  local current_mode
  current_mode=$(get_current_mode)
  if [ "$current_mode" = "EXECUTE" ]; then
    log "SKIP: EXECUTE mode active"
    exit 0
  fi

  # Subagent 활성 상태 체크 (agent stack이 비어있지 않으면 Main Agent가 아님)
  local agent_stack=""
  if [ -f "$ORCHESTRA_STATE_FILE" ]; then
    agent_stack=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    stack = d.get('agentStack', [])
    print(','.join(stack) if stack else '')
except:
    print('')
" "$ORCHESTRA_STATE_FILE" 2>/dev/null)
  fi
  if [ -n "$agent_stack" ]; then
    log "SKIP: Subagent active ($agent_stack)"
    exit 0
  fi

  # 강한 리다이렉트 메시지 출력 (차단 아님)
  log "REDIRECT: Main Agent direct code access ($tool_name: $file_path)"
  cat <<'REDIRECT'

⚠️ [Maestro Protocol] 소스 코드 직접 Read 감지

Maestro는 소스 코드를 직접 읽지 않습니다. 아래 에이전트를 사용하세요:

  EXPLORATORY → Task(subagent_type="Explore", description="코드 탐색: {대상}", prompt="...")
  OPEN-ENDED  → Task(Research-Team) 또는 Task(Explorer) + Task(Interviewer)

직접 Read 대신 에이전트를 호출하세요. 이것은 프로토콜 규칙입니다.

REDIRECT

  # 통과 (차단하지 않음)
  exit 0
}

main
