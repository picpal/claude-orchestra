#!/bin/bash
# Session Evaluation Script
# 세션 종료 시 대화에서 재사용 가능한 패턴을 추출합니다.
# Stop Hook으로 등록하여 사용

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
PATTERNS_DIR="$SCRIPT_DIR/learned-patterns"
STATE_FILE=".orchestra/state.json"
LOG_FILE=".orchestra/logs/learning.log"

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$PATTERNS_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 설정 로드
load_config() {
  if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
    ENABLED=$(jq -r '.enabled // false' "$CONFIG_FILE")
    MIN_SESSION_LENGTH=$(jq -r '.minSessionLength // 10' "$CONFIG_FILE")
    AUTO_APPROVE=$(jq -r '.autoApprove // false' "$CONFIG_FILE")
    MAX_PATTERNS=$(jq -r '.extractionRules.maxPatternsPerSession // 5' "$CONFIG_FILE")
  else
    ENABLED="false"
    MIN_SESSION_LENGTH=10
    AUTO_APPROVE="false"
    MAX_PATTERNS=5
  fi
}

# 패턴 ID 생성
generate_pattern_id() {
  local category="$1"
  local timestamp=$(date +%Y%m%d%H%M%S)
  local random=$(head -c 4 /dev/urandom | xxd -p)
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

# 메인 로직
main() {
  local command="${1:-evaluate}"

  load_config

  case "$command" in
    evaluate)
      if [ "$ENABLED" != "true" ]; then
        log "Learning is disabled"
        echo "Learning is disabled in config"
        exit 0
      fi

      log "Starting session evaluation..."

      local activity_log="${2:-.orchestra/logs/activity.log}"
      if [ ! -f "$activity_log" ]; then
        log "No activity log found: $activity_log"
        echo "No activity log found."
        exit 0
      fi

      # Python 분석기 호출
      local count
      count=$(python3 "$SCRIPT_DIR/analyze-session.py" \
        --activity "$activity_log" \
        --tests ".orchestra/logs/test-runs.log" \
        --tdd-guard ".orchestra/logs/tdd-guard.log" \
        --config "$CONFIG_FILE" \
        --patterns-dir "$PATTERNS_DIR" \
        --max-patterns "$MAX_PATTERNS" 2>>"$LOG_FILE")

      update_state "${count:-0}"

      echo "Session evaluated. Patterns extracted: ${count:-0}"
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
