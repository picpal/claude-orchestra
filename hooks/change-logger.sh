#!/usr/bin/env bash
# Change Logger - Edit/Write 변경 캡처 (민감 정보 필터링)
# Phase 1: 기록만 수행, 분석 미연동

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/stdin-reader.sh"

# 로그 파일 경로 설정
LOG_FILE=".orchestra/logs/changes.jsonl"
mkdir -p "$(dirname "$LOG_FILE")"

# 기본 정보 추출
TOOL_NAME="$HOOK_TOOL_NAME"
FILE_PATH=$(hook_get_field "tool_input.file_path")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 민감 파일 제외 (환경변수, 시크릿, 키 파일 등)
is_sensitive_file() {
  local file="$1"
  case "$file" in
    *.env|*.env.*|.env*) return 0 ;;
    *credentials*|*secret*|*secrets*) return 0 ;;
    *.key|*.pem|*.p12|*.pfx) return 0 ;;
    */secrets/*|*/.env/*) return 0 ;;
    *password*|*passwd*) return 0 ;;
    *) return 1 ;;
  esac
}

# 민감 정보 필터링 (API 키, 토큰, 비밀번호 등)
sanitize_content() {
  local content="$1"
  echo "$content" | python3 "$SCRIPT_DIR/sanitize-content.py"
}

# 파일 확장자 기반 언어 추론
infer_language() {
  local file="$1"
  case "$file" in
    *.ts|*.tsx) echo "typescript" ;;
    *.js|*.jsx) echo "javascript" ;;
    *.py) echo "python" ;;
    *.sh|*.bash) echo "bash" ;;
    *.md) echo "markdown" ;;
    *.json) echo "json" ;;
    *.yaml|*.yml) echo "yaml" ;;
    *.html|*.htm) echo "html" ;;
    *.css|*.scss|*.sass) echo "css" ;;
    *.go) echo "go" ;;
    *.rs) echo "rust" ;;
    *.java) echo "java" ;;
    *.rb) echo "ruby" ;;
    *.php) echo "php" ;;
    *.sql) echo "sql" ;;
    *.xml) echo "xml" ;;
    *.toml) echo "toml" ;;
    *) echo "text" ;;
  esac
}

# 파일 경로가 없으면 종료
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 민감 파일이면 기록하지 않음
if is_sensitive_file "$FILE_PATH"; then
  exit 0
fi

# 언어 추론
LANG=$(infer_language "$FILE_PATH")

# Edit 도구 처리
if [ "$TOOL_NAME" = "Edit" ]; then
  OLD_STRING=$(hook_get_field "tool_input.old_string")
  NEW_STRING=$(hook_get_field "tool_input.new_string")

  # 최소 변경 크기 필터 (10자 미만 무시)
  if [ ${#OLD_STRING} -lt 10 ] && [ ${#NEW_STRING} -lt 10 ]; then
    exit 0
  fi

  # 크기 제한 (각각 500자)
  OLD_STRING=$(echo "$OLD_STRING" | head -c 500)
  NEW_STRING=$(echo "$NEW_STRING" | head -c 500)

  # 민감 정보 필터링 적용
  OLD_STRING=$(sanitize_content "$OLD_STRING")
  NEW_STRING=$(sanitize_content "$NEW_STRING")

  # JSONL 형식으로 기록
  python3 -c "
import sys
import json

data = {
    'timestamp': sys.argv[1],
    'tool': 'Edit',
    'file': sys.argv[2],
    'language': sys.argv[3],
    'old_string': sys.argv[4],
    'new_string': sys.argv[5]
}
print(json.dumps(data, ensure_ascii=False))
" "$TIMESTAMP" "$FILE_PATH" "$LANG" "$OLD_STRING" "$NEW_STRING" >> "$LOG_FILE"

# Write 도구 처리
elif [ "$TOOL_NAME" = "Write" ]; then
  CONTENT=$(hook_get_field "tool_input.content")

  # 크기 제한 (500자 샘플)
  CONTENT=$(echo "$CONTENT" | head -c 500)

  # 민감 정보 필터링 적용
  CONTENT=$(sanitize_content "$CONTENT")

  # JSONL 형식으로 기록
  python3 -c "
import sys
import json

data = {
    'timestamp': sys.argv[1],
    'tool': 'Write',
    'file': sys.argv[2],
    'language': sys.argv[3],
    'content_sample': sys.argv[4]
}
print(json.dumps(data, ensure_ascii=False))
" "$TIMESTAMP" "$FILE_PATH" "$LANG" "$CONTENT" >> "$LOG_FILE"
fi

exit 0
