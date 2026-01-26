#!/bin/bash
# Auto Format Hook
# 파일 저장 시 자동으로 Prettier/ESLint 포맷팅을 적용합니다.
# PostToolUse Hook (Write|Edit 매처)

set -e

TOOL_INPUT="$1"
CONFIG_FILE=".orchestra/config.json"
LOG_FILE=".orchestra/logs/auto-format.log"

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 파일 경로 추출
get_file_path() {
  echo "$TOOL_INPUT" | grep -oE '"file_path"\s*:\s*"[^"]+"' | sed 's/"file_path"\s*:\s*"//' | sed 's/"$//' || echo ""
}

# 포맷팅 가능한 파일인지 확인
is_formattable() {
  local file="$1"
  local ext="${file##*.}"

  case "$ext" in
    ts|tsx|js|jsx|json|css|scss|less|html|md|yaml|yml)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Prettier 포맷팅
format_with_prettier() {
  local file="$1"

  if command -v prettier &> /dev/null || [ -f "node_modules/.bin/prettier" ]; then
    log "Formatting with Prettier: $file"

    if npx prettier --write "$file" 2>/dev/null; then
      echo "✨ Formatted: $file"
      return 0
    else
      log "Prettier formatting failed for: $file"
      return 1
    fi
  fi

  return 1
}

# ESLint 자동 수정
fix_with_eslint() {
  local file="$1"
  local ext="${file##*.}"

  # JS/TS 파일만
  case "$ext" in
    ts|tsx|js|jsx)
      ;;
    *)
      return 0
      ;;
  esac

  if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ]; then
    if command -v eslint &> /dev/null || [ -f "node_modules/.bin/eslint" ]; then
      log "Fixing with ESLint: $file"

      if npx eslint --fix "$file" 2>/dev/null; then
        return 0
      else
        log "ESLint fix failed for: $file"
        return 1
      fi
    fi
  fi

  return 0
}

# Biome 포맷팅
format_with_biome() {
  local file="$1"

  if [ -f "biome.json" ]; then
    if command -v biome &> /dev/null || [ -f "node_modules/.bin/biome" ]; then
      log "Formatting with Biome: $file"

      if npx biome format --write "$file" 2>/dev/null; then
        return 0
      fi
    fi
  fi

  return 1
}

# Python 포맷팅 (Black/Ruff)
format_python() {
  local file="$1"
  local ext="${file##*.}"

  if [ "$ext" != "py" ]; then
    return 0
  fi

  # Ruff 우선
  if command -v ruff &> /dev/null; then
    log "Formatting with Ruff: $file"
    ruff format "$file" 2>/dev/null && return 0
  fi

  # Black 대체
  if command -v black &> /dev/null; then
    log "Formatting with Black: $file"
    black "$file" 2>/dev/null && return 0
  fi

  return 0
}

# Go 포맷팅
format_go() {
  local file="$1"
  local ext="${file##*.}"

  if [ "$ext" != "go" ]; then
    return 0
  fi

  if command -v gofmt &> /dev/null; then
    log "Formatting with gofmt: $file"
    gofmt -w "$file" 2>/dev/null && return 0
  fi

  return 0
}

# 메인 로직
main() {
  local file_path=$(get_file_path)

  # 파일 경로가 없으면 종료
  if [ -z "$file_path" ]; then
    exit 0
  fi

  # 테스트 파일이나 설정 파일 제외 옵션
  if echo "$file_path" | grep -qE "(node_modules|\.git|dist|build|coverage)/"; then
    exit 0
  fi

  # 포맷팅 가능 여부 확인
  if ! is_formattable "$file_path"; then
    # Python, Go 파일 확인
    local ext="${file_path##*.}"
    case "$ext" in
      py)
        format_python "$file_path"
        ;;
      go)
        format_go "$file_path"
        ;;
    esac
    exit 0
  fi

  log "Auto-format triggered for: $file_path"

  # Biome 먼저 시도
  if format_with_biome "$file_path"; then
    exit 0
  fi

  # Prettier + ESLint
  format_with_prettier "$file_path"
  fix_with_eslint "$file_path"
}

main
