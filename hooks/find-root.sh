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

find_project_root() {
  local dir="$PWD"

  # 1. 우선순위: .orchestra/config.json 상향 탐색 (monorepo 지원)
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.orchestra/config.json" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  # 2. Fallback: Git 루트
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$git_root" ]; then
    echo "$git_root"
    return 0
  fi

  # 3. 최종 Fallback: 현재 디렉토리
  echo "$PWD"
}

# 환경 변수 설정 (ORCHESTRA_ROOT만 export)
if [ -z "$ORCHESTRA_ROOT" ]; then
  export ORCHESTRA_ROOT=$(find_project_root)
fi

# 파생 변수 (export 불필요 - 현재 셸에서만 사용)
ORCHESTRA_DIR="$ORCHESTRA_ROOT/.orchestra"
ORCHESTRA_LOG_DIR="$ORCHESTRA_DIR/logs"
ORCHESTRA_STATE_FILE="$ORCHESTRA_DIR/state.json"

# 디렉토리 생성 함수
ensure_orchestra_dirs() {
  mkdir -p "$ORCHESTRA_LOG_DIR" 2>/dev/null || true
}
