#!/usr/bin/env bash
# find-root.sh - 프로젝트 루트 감지 유틸리티
# Usage: source "$SCRIPT_DIR/find-root.sh"
#
# 이 스크립트를 source하면 다음 변수들이 설정됩니다:
#   ORCHESTRA_ROOT    - 프로젝트 루트 경로 (export됨)
#   ORCHESTRA_DIR     - .orchestra 디렉토리 경로
#   ORCHESTRA_LOG_DIR - .orchestra/logs 디렉토리 경로
#   ORCHESTRA_STATE_FILE - state.json 파일 경로
#
# 함수:
#   ensure_orchestra_dirs() - 필요한 디렉토리 생성
#
# 디버그: ORCHESTRA_DEBUG=1 설정 시 /tmp/orchestra-debug.log에 로그 기록

# 에러 로그 파일 (항상 기록)
_ORCHESTRA_ERROR_LOG="/tmp/orchestra-errors-${USER:-unknown}.log"

_orchestra_debug() {
  if [ "${ORCHESTRA_DEBUG:-}" = "1" ]; then
    echo "[$(date '+%H:%M:%S')] $*" >> /tmp/orchestra-debug.log
  fi
}

# 에러 로깅 함수 (항상 기록됨)
_orchestra_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$_ORCHESTRA_ERROR_LOG"
}

# 환경 검증 함수
verify_orchestra_env() {
  local errors=0

  # Python3 확인
  if ! command -v python3 &>/dev/null; then
    _orchestra_error "Python3 not found"
    errors=$((errors + 1))
  fi

  # 디렉토리 쓰기 권한 확인
  if [ -d "${ORCHESTRA_DIR:-}" ] && [ ! -w "${ORCHESTRA_DIR:-}" ]; then
    _orchestra_error "No write permission: $ORCHESTRA_DIR"
    errors=$((errors + 1))
  fi

  return $errors
}

find_project_root() {
  local dir="$PWD"

  _orchestra_debug "find_project_root called: PWD=$PWD"

  # 1. 우선순위: .orchestra 디렉토리 상향 탐색 (monorepo 지원)
  #    config.json 또는 state.json 중 하나라도 있으면 인식
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.orchestra" ] && \
       { [ -f "$dir/.orchestra/config.json" ] || [ -f "$dir/.orchestra/state.json" ]; }; then
      _orchestra_debug "Found .orchestra at: $dir"
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  # 2. Fallback: Git 루트
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$git_root" ]; then
    _orchestra_debug "Using git root: $git_root"
    echo "$git_root"
    return 0
  fi

  # 3. 최종 Fallback: 현재 디렉토리
  _orchestra_debug "Using PWD as fallback: $PWD"
  echo "$PWD"
}

# 환경 변수 설정 (ORCHESTRA_ROOT만 export)
# 주의: ${ORCHESTRA_ROOT:-} 패턴으로 nounset 환경에서도 안전
if [ -z "${ORCHESTRA_ROOT:-}" ]; then
  export ORCHESTRA_ROOT=$(find_project_root)
  _orchestra_debug "ORCHESTRA_ROOT set to: $ORCHESTRA_ROOT"
fi

# 파생 변수 (export 불필요 - 현재 셸에서만 사용)
ORCHESTRA_DIR="$ORCHESTRA_ROOT/.orchestra"
ORCHESTRA_LOG_DIR="$ORCHESTRA_DIR/logs"
ORCHESTRA_STATE_FILE="$ORCHESTRA_DIR/state.json"

_orchestra_debug "ORCHESTRA_LOG_DIR: $ORCHESTRA_LOG_DIR"

# 디렉토리 생성 함수
ensure_orchestra_dirs() {
  _orchestra_debug "ensure_orchestra_dirs: creating $ORCHESTRA_LOG_DIR"
  if ! mkdir -p "$ORCHESTRA_LOG_DIR" 2>/dev/null; then
    _orchestra_error "Failed to create $ORCHESTRA_LOG_DIR"
    return 1
  fi
}
