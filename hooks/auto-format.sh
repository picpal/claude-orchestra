#!/bin/bash
# Auto Format Hook (Opt-in)
# Write 후 자동 포맷팅 (Prettier/ESLint/Biome/Ruff/gofmt)
# Hook: PostToolUse (Write matcher)
#
# ⚠️ Opt-in: .orchestra/config.json에 "autoFormat": true 설정 시에만 동작
# 기본값은 비활성화 — 포맷팅이 후속 Edit 작업에 영향을 줄 수 있으므로 Write만 대상

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

# === Opt-in Guard ===
# config.json에 autoFormat: true가 없으면 즉시 종료 (기존 사용자 영향 없음)
CONFIG_FILE="$ORCHESTRA_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

AUTO_FORMAT_ENABLED=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        d = json.load(f)
    print('true' if d.get('autoFormat', False) else 'false')
except:
    print('false')
" "$CONFIG_FILE" 2>/dev/null || echo "false")

if [ "$AUTO_FORMAT_ENABLED" != "true" ]; then
  exit 0
fi

LOG_FILE="$ORCHESTRA_LOG_DIR/auto-format.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 파일 경로 추출 (stdin JSON에서)
FILE_PATH=$(hook_get_field "tool_input.file_path")

# 파일 경로가 없으면 종료
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 빌드 아티팩트/의존성 제외
if echo "$FILE_PATH" | grep -qE "(node_modules|\.git|dist|build|coverage|__pycache__|\.next)/"; then
  exit 0
fi

# 파일이 존재하는지 확인
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"

# Biome 포맷팅 시도
format_with_biome() {
  local file="$1"
  if [ -f "${ORCHESTRA_ROOT}/biome.json" ] || [ -f "${ORCHESTRA_ROOT}/biome.jsonc" ]; then
    if command -v biome &> /dev/null || [ -f "${ORCHESTRA_ROOT}/node_modules/.bin/biome" ]; then
      log "Formatting with Biome: $file"
      npx biome format --write "$file" 2>/dev/null && return 0
    fi
  fi
  return 1
}

# Prettier 포맷팅
format_with_prettier() {
  local file="$1"
  if command -v prettier &> /dev/null || [ -f "${ORCHESTRA_ROOT}/node_modules/.bin/prettier" ]; then
    log "Formatting with Prettier: $file"
    npx prettier --write "$file" 2>/dev/null && return 0
  fi
  return 1
}

# ESLint 자동 수정 (JS/TS만)
fix_with_eslint() {
  local file="$1"
  local ext="${file##*.}"
  case "$ext" in
    ts|tsx|js|jsx) ;;
    *) return 0 ;;
  esac
  if [ -f "${ORCHESTRA_ROOT}/.eslintrc.js" ] || [ -f "${ORCHESTRA_ROOT}/.eslintrc.json" ] || [ -f "${ORCHESTRA_ROOT}/eslint.config.js" ] || [ -f "${ORCHESTRA_ROOT}/eslint.config.mjs" ]; then
    if command -v eslint &> /dev/null || [ -f "${ORCHESTRA_ROOT}/node_modules/.bin/eslint" ]; then
      log "Fixing with ESLint: $file"
      npx eslint --fix "$file" 2>/dev/null || true
    fi
  fi
}

# Python 포맷팅
format_python() {
  local file="$1"
  if command -v ruff &> /dev/null; then
    log "Formatting with Ruff: $file"
    ruff format "$file" 2>/dev/null && return 0
  fi
  if command -v black &> /dev/null; then
    log "Formatting with Black: $file"
    black "$file" 2>/dev/null && return 0
  fi
  return 0
}

# Go 포맷팅
format_go() {
  local file="$1"
  if command -v gofmt &> /dev/null; then
    log "Formatting with gofmt: $file"
    gofmt -w "$file" 2>/dev/null && return 0
  fi
  return 0
}

# 메인 로직
case "$EXT" in
  ts|tsx|js|jsx|json|css|scss|less|html|yaml|yml|md)
    log "Auto-format triggered for: $FILE_PATH"
    format_with_biome "$FILE_PATH" || format_with_prettier "$FILE_PATH" || true
    fix_with_eslint "$FILE_PATH"
    ;;
  py)
    format_python "$FILE_PATH"
    ;;
  go)
    format_go "$FILE_PATH"
    ;;
esac

exit 0
