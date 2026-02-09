#!/usr/bin/env bash
# Maestro Guard Hook
# Main Agent(Claude Code)가 직접 코드 파일을 수정하는 것을 차단합니다.
# PreToolUse Hook (Edit|Write 매처)
#
# 핵심 로직:
# - Subagent 스택이 비어있으면 = Main Agent가 직접 호출
# - Main Agent는 코드 파일을 직접 수정할 수 없음
# - Subagent(High-Player/Low-Player)에게 위임해야 함

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

LOG_FILE="$ORCHESTRA_LOG_DIR/maestro-guard.log"
AGENT_STACK_FILE="$ORCHESTRA_LOG_DIR/.agent-stack"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 허용된 경로 패턴 (Main Agent도 수정 가능)
is_allowed_path() {
  local file_path="$1"

  # .orchestra/ 디렉토리 허용 (상태, 저널, 계획 파일)
  if [[ "$file_path" == .orchestra/* ]]; then
    return 0
  fi

  # .claude/ 디렉토리 허용 (설정 파일)
  if [[ "$file_path" == .claude/* ]]; then
    return 0
  fi

  # Markdown 파일 허용 (문서)
  if [[ "$file_path" == *.md ]]; then
    return 0
  fi

  # JSON 설정 파일 허용
  if [[ "$file_path" == *.json ]] && [[ "$file_path" != *src/* ]] && [[ "$file_path" != *lib/* ]]; then
    # src/, lib/ 내의 JSON은 코드로 취급하여 차단
    return 0
  fi

  return 1
}

# Subagent 실행 중인지 확인
is_subagent_active() {
  if [ -f "$AGENT_STACK_FILE" ] && [ -s "$AGENT_STACK_FILE" ]; then
    return 0
  fi
  return 1
}

# 메인 로직
main() {
  local file_path
  file_path=$(hook_get_field "tool_input.file_path")

  log "Checking: file=$file_path"

  # 파일 경로가 없으면 통과
  if [ -z "$file_path" ]; then
    log "PASSED: No file path"
    exit 0
  fi

  # Subagent 실행 중이면 통과 (Executor가 실행 중)
  if is_subagent_active; then
    local active_agent
    active_agent=$(tail -1 "$AGENT_STACK_FILE" 2>/dev/null | cut -d'|' -f2 || echo "unknown")
    log "PASSED: Subagent active ($active_agent)"
    exit 0
  fi

  # 허용된 경로이면 통과
  if is_allowed_path "$file_path"; then
    log "PASSED: Allowed path ($file_path)"
    exit 0
  fi

  # Main Agent가 코드 파일을 직접 수정하려고 함 → 차단
  log "BLOCKED: Main Agent attempted to modify code file: $file_path"

  cat <<EOF
⛔ [Maestro Guard] 프로토콜 위반 감지!

Main Agent는 코드 파일을 직접 수정할 수 없습니다.

차단된 파일: $file_path

허용된 경로:
  - .orchestra/**/* (상태, 저널, 계획)
  - .claude/**/* (설정)
  - *.md (문서)
  - 루트 *.json (설정 파일)

올바른 방법:
  Task(subagent_type="general-purpose",
       description="High-Player: {작업명}",
       model="opus",
       prompt="...")

또는

  Task(subagent_type="general-purpose",
       description="Low-Player: {작업명}",
       model="sonnet",
       prompt="...")

코드 수정은 반드시 Executor(High-Player/Low-Player)에게 위임하세요.
EOF

  exit 1
}

main
