#!/bin/bash
# Session Evaluation Script
# 세션 종료 시 대화에서 재사용 가능한 패턴을 추출합니다.
# Stop Hook으로 등록하여 사용

set -e

# === 경로 해결 (CLAUDE_PLUGIN_ROOT 지원) ===
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPT_DIR="${PLUGIN_ROOT}/hooks/learning"
CONFIG_FILE="$SCRIPT_DIR/config.json"
STATE_FILE=".orchestra/state.json"
LOG_FILE=".orchestra/logs/learning.log"

# 패턴 저장 경로 (사용자 프로젝트 우선)
if [ -d ".orchestra/learning" ]; then
  PATTERNS_DIR=".orchestra/learning/learned-patterns"
else
  PATTERNS_DIR="$SCRIPT_DIR/learned-patterns"
fi

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
mkdir -p "$PATTERNS_DIR" 2>/dev/null || true

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# === 크로스 플랫폼 해시 함수 ===
get_hash() {
  local input="$1"
  if command -v md5 &> /dev/null; then
    echo "$input" | md5 | cut -c1-8
  elif command -v md5sum &> /dev/null; then
    echo "$input" | md5sum | cut -c1-8
  else
    # Fallback: 간단한 해시 (PID + 시간)
    echo "$$$(date +%s)" | cut -c1-8
  fi
}

# === 락 메커니즘 (동시 실행 방지) ===
LOCK_FILE="/tmp/orchestra-learning-$(get_hash "$PWD").lock"

acquire_lock() {
  if [ -f "$LOCK_FILE" ]; then
    # macOS/Linux 호환 stat
    if [[ "$OSTYPE" == "darwin"* ]]; then
      lock_age=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
    else
      lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
    fi
    if [ "$lock_age" -gt 60 ]; then
      rm -f "$LOCK_FILE"  # 오래된 락 제거 (60초 이상)
    else
      return 1  # 이미 실행 중
    fi
  fi
  echo $$ > "$LOCK_FILE"
  return 0
}

release_lock() {
  rm -f "$LOCK_FILE" 2>/dev/null
}
trap release_lock EXIT

# 설정 로드
load_config() {
  if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
    ENABLED=$(jq -r '.enabled // false' "$CONFIG_FILE")
    MIN_SESSION_LENGTH=$(jq -r '.minSessionLength // 10' "$CONFIG_FILE")
    AUTO_APPROVE=$(jq -r '.autoApprove // false' "$CONFIG_FILE")
    MAX_PATTERNS=$(jq -r '.extractionRules.maxPatternsPerSession // 5' "$CONFIG_FILE")
    MAX_LOG_SIZE_MB=$(jq -r '.extractionRules.maxLogSizeMB // 10' "$CONFIG_FILE")
  else
    ENABLED="false"
    MIN_SESSION_LENGTH=10
    AUTO_APPROVE="false"
    MAX_PATTERNS=5
    MAX_LOG_SIZE_MB=10
  fi
}

# 패턴 ID 생성 (xxd 대신 od 사용)
generate_pattern_id() {
  local category="$1"
  local timestamp=$(date +%Y%m%d%H%M%S)
  # xxd 대신 od 사용 (더 널리 사용 가능)
  local random=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-8)
  echo "${category}-${timestamp}-${random}"
}

# 패턴 파일 생성
create_pattern_file() {
  local category="$1"
  local title="$2"
  local problem="$3"
  local solution="$4"
  local code_example="$5"
  local keywords="$6"

  local pattern_id=$(generate_pattern_id "$category")
  local pattern_file="$PATTERNS_DIR/${pattern_id}.md"

  cat > "$pattern_file" << EOF
# Pattern: $title

## ID
$pattern_id

## Category
$category

## Created
$(date -u +%Y-%m-%dT%H:%M:%SZ)

## Problem
$problem

## Solution
$solution

## Code Example
\`\`\`
$code_example
\`\`\`

## Trigger Keywords
$keywords

## Usage Count
1

## Last Used
$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  echo "$pattern_id"
  log "Created pattern: $pattern_id - $title"
}

# 패턴 Usage Count 증가 및 Last Used 갱신
update_pattern_usage() {
  local pattern_file="$1"
  if [ ! -f "$pattern_file" ]; then
    return
  fi
  python3 -c "
import re, sys
from datetime import datetime, timezone

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Update Usage Count
m = re.search(r'(## Usage Count\n)(\d+)', content)
if m:
    old = int(m.group(2))
    content = content[:m.start(2)] + str(old + 1) + content[m.end(2):]

# Update Last Used
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
content = re.sub(r'(## Last Used\n).*', r'\g<1>' + now, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
" "$pattern_file"
}

# 상태 업데이트
update_state() {
  local patterns_extracted="$1"

  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local total_sessions=$(jq '.learningMetrics.totalSessions // 0' "$STATE_FILE")
    local total_patterns=$(jq '.learningMetrics.patternsExtracted // 0' "$STATE_FILE")

    jq --arg lastRun "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson sessions "$((total_sessions + 1))" \
       --argjson patterns "$((total_patterns + patterns_extracted))" \
       '.learningMetrics.totalSessions = $sessions |
        .learningMetrics.patternsExtracted = $patterns |
        .learningMetrics.lastLearningRun = $lastRun' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  fi
}

# 패턴 목록 출력
list_patterns() {
  echo ""
  echo "Learned Patterns"
  echo "==================="

  local count=0
  for pattern_file in "$PATTERNS_DIR"/*.md; do
    if [ -f "$pattern_file" ]; then
      local title=$(grep "^# Pattern:" "$pattern_file" | sed 's/# Pattern: //')
      local category=$(grep "^## Category" -A 1 "$pattern_file" | tail -1)
      local usage=$(grep "^## Usage Count" -A 1 "$pattern_file" | tail -1)
      local id=$(basename "$pattern_file" .md)

      printf "  [%s] %s (usage: %s) (%s)\n" "$category" "$title" "$usage" "$id"
      count=$((count + 1))
    fi
  done

  if [ "$count" -eq 0 ]; then
    echo "  No patterns found."
  else
    echo ""
    echo "  Total: $count patterns"
  fi
}

# 로그 크기 체크 (MB)
check_log_size() {
  local log_path="$1"
  local max_mb="$2"

  if [ ! -f "$log_path" ]; then
    return 0  # 파일 없으면 OK
  fi

  # 크로스 플랫폼 파일 크기 확인
  local size_bytes
  if [[ "$OSTYPE" == "darwin"* ]]; then
    size_bytes=$(stat -f %z "$log_path" 2>/dev/null || echo 0)
  else
    size_bytes=$(stat -c %s "$log_path" 2>/dev/null || echo 0)
  fi

  local size_mb=$((size_bytes / 1024 / 1024))

  if [ "$size_mb" -gt "$max_mb" ]; then
    log "Log too large (${size_mb}MB > ${max_mb}MB): $log_path"
    return 1
  fi
  return 0
}

# 메인 로직
main() {
  local command="${1:-evaluate}"

  load_config

  case "$command" in
    evaluate)
      if [ "$ENABLED" != "true" ]; then
        log "Learning is disabled"
        echo "0"
        exit 0
      fi

      # Python 가용성 체크
      if ! command -v python3 &> /dev/null; then
        log "Python3 not available, skipping analysis"
        echo "0"
        exit 0
      fi

      # 락 획득 시도
      if ! acquire_lock; then
        log "Another learning process is running, skipping"
        echo "0"
        exit 0
      fi

      log "Starting session evaluation..."

      local activity_log="${2:-.orchestra/logs/activity.log}"

      # 로그 파일 존재 확인
      if [ ! -f "$activity_log" ]; then
        log "No activity log found: $activity_log"
        echo "0"
        exit 0
      fi

      # 로그 크기 체크
      if ! check_log_size "$activity_log" "$MAX_LOG_SIZE_MB"; then
        echo "0"
        exit 0
      fi

      # 최소 세션 길이 체크
      local line_count=$(wc -l < "$activity_log" 2>/dev/null | tr -d ' ' || echo 0)
      if [ "$line_count" -lt "$MIN_SESSION_LENGTH" ]; then
        log "Session too short ($line_count lines < $MIN_SESSION_LENGTH), skipping"
        echo "0"
        exit 0
      fi

      # Python 분석기 호출
      local count
      count=$(python3 "$SCRIPT_DIR/analyze-session.py" \
        --activity "$activity_log" \
        --tests ".orchestra/logs/test-runs.log" \
        --tdd-guard ".orchestra/logs/tdd-guard.log" \
        --changes ".orchestra/logs/changes.jsonl" \
        --config "$CONFIG_FILE" \
        --patterns-dir "$PATTERNS_DIR" \
        --max-patterns "$MAX_PATTERNS" 2>>"$LOG_FILE") || count=0

      update_state "${count:-0}"

      echo "${count:-0}"
      log "Session evaluation complete. Patterns: ${count:-0}"
      ;;

    list)
      list_patterns
      ;;

    add)
      local category="${2:-project_specific}"
      local title="${3:-Manual Pattern}"
      local problem="${4:-}"
      local solution="${5:-}"
      local keywords="${6:-}"
      create_pattern_file "$category" "$title" "$problem" "$solution" "" "$keywords"
      echo "Pattern added"
      ;;

    clear)
      echo "Clearing all learned patterns..."
      rm -f "$PATTERNS_DIR"/*.md
      echo "All patterns cleared"
      ;;

    *)
      echo "Usage: $0 {evaluate|list|add|clear}"
      exit 1
      ;;
  esac
}

main "$@"
