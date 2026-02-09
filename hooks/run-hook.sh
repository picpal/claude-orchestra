#!/usr/bin/env bash
# Orchestra Hook Wrapper
# 플러그인 경로를 동적으로 찾아서 훅 스크립트 실행
# Usage: run-hook.sh <hook-script> [args...]

set -euo pipefail

# 플러그인 루트 찾기 (최신 버전)
find_plugin_root() {
  local plugin_dir
  plugin_dir=$(ls -td ~/.claude/plugins/cache/claude-orchestra/claude-orchestra/*/ 2>/dev/null | head -1)

  if [ -z "$plugin_dir" ]; then
    echo "ERROR: claude-orchestra plugin not found" >&2
    exit 1
  fi

  echo "${plugin_dir%/}"  # 끝의 / 제거
}

# CLAUDE_PLUGIN_ROOT가 비어있으면 동적으로 찾기
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  export CLAUDE_PLUGIN_ROOT=$(find_plugin_root)
fi

# 첫 번째 인자: 실행할 훅 스크립트
HOOK_SCRIPT="$1"
shift

# 훅 스크립트 실행
exec "$CLAUDE_PLUGIN_ROOT/hooks/$HOOK_SCRIPT" "$@"
