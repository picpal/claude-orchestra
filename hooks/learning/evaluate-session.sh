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
0

## Last Used
Never
EOF

  echo "$pattern_id"
  log "Created pattern: $pattern_id - $title"
}

# 에러 해결 패턴 추출
extract_error_patterns() {
  local session_log="$1"
  local patterns_found=0

  # TypeScript 일반 에러 패턴
  if echo "$session_log" | grep -q "TS[0-9]\{4\}"; then
    # TS2532: Object is possibly undefined
    if echo "$session_log" | grep -q "TS2532\|possibly.*undefined"; then
      create_pattern_file \
        "error_resolution" \
        "TypeScript Null Check" \
        "'Object is possibly undefined' 에러 발생" \
        "Optional chaining (?.) 또는 nullish coalescing (??) 연산자 사용" \
        "// Before
const name = user.profile.name;

// After
const name = user?.profile?.name ?? 'Unknown';" \
        "TS2532, Object is possibly, undefined, null check"
      patterns_found=$((patterns_found + 1))
    fi

    # TS2339: Property does not exist
    if echo "$session_log" | grep -q "TS2339\|Property.*does not exist"; then
      create_pattern_file \
        "error_resolution" \
        "TypeScript Property Check" \
        "'Property X does not exist on type Y' 에러 발생" \
        "타입 정의 확인 및 타입 가드 사용" \
        "// Type guard 사용
if ('property' in object) {
  // object.property 사용 가능
}

// 또는 타입 단언
const value = (object as ExtendedType).property;" \
        "TS2339, Property does not exist, type guard"
      patterns_found=$((patterns_found + 1))
    fi
  fi

  # React 에러 패턴
  if echo "$session_log" | grep -q "React\|hook\|useEffect\|useState"; then
    # Hook 의존성 경고
    if echo "$session_log" | grep -q "exhaustive-deps\|missing dependency"; then
      create_pattern_file \
        "error_resolution" \
        "React Hook Dependencies" \
        "useEffect/useCallback 의존성 배열 누락 경고" \
        "의존성 배열에 사용되는 모든 변수 추가, 또는 eslint-disable 주석으로 무시" \
        "useEffect(() => {
  fetchData(userId);
}, [userId]); // userId 의존성 추가

// 또는 함수를 useCallback으로 감싸기
const fetchData = useCallback(() => {
  // ...
}, [dependency]);" \
        "exhaustive-deps, missing dependency, useEffect, useCallback"
      patterns_found=$((patterns_found + 1))
    fi
  fi

  echo "$patterns_found"
}

# 사용자 수정 패턴 추출
extract_correction_patterns() {
  local session_log="$1"
  local patterns_found=0

  # 수정 요청 감지 (간단한 휴리스틱)
  if echo "$session_log" | grep -qE "(아니|다시|수정해|고쳐|잘못)"; then
    log "User correction detected - manual review needed"
    # 실제 구현에서는 LLM을 통해 패턴 추출
  fi

  echo "$patterns_found"
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
  echo "📚 Learned Patterns"
  echo "==================="

  local count=0
  for pattern_file in "$PATTERNS_DIR"/*.md; do
    if [ -f "$pattern_file" ]; then
      local title=$(grep "^# Pattern:" "$pattern_file" | sed 's/# Pattern: //')
      local category=$(grep "^## Category" -A 1 "$pattern_file" | tail -1)
      local id=$(basename "$pattern_file" .md)

      printf "  [%s] %s (%s)\n" "$category" "$title" "$id"
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
        echo "⏭️ Learning is disabled in config"
        exit 0
      fi

      log "Starting session evaluation..."
      echo "🎓 Evaluating session for learning patterns..."

      # 세션 로그가 있으면 분석 (실제 구현에서는 세션 로그 경로 필요)
      local session_log="${2:-}"
      local total_patterns=0

      if [ -n "$session_log" ] && [ -f "$session_log" ]; then
        # 에러 패턴 추출
        error_patterns=$(extract_error_patterns "$(cat "$session_log")")
        total_patterns=$((total_patterns + error_patterns))

        # 수정 패턴 추출
        correction_patterns=$(extract_correction_patterns "$(cat "$session_log")")
        total_patterns=$((total_patterns + correction_patterns))
      fi

      # 상태 업데이트
      update_state "$total_patterns"

      echo "✅ Session evaluated. Patterns extracted: $total_patterns"
      log "Session evaluation complete. Patterns: $total_patterns"
      ;;

    list)
      list_patterns
      ;;

    add)
      # 수동 패턴 추가
      local category="${2:-project_specific}"
      local title="${3:-Manual Pattern}"
      echo "Adding manual pattern..."
      create_pattern_file "$category" "$title" "" "" "" ""
      echo "✅ Pattern added"
      ;;

    clear)
      echo "⚠️ Clearing all learned patterns..."
      rm -f "$PATTERNS_DIR"/*.md
      echo "✅ All patterns cleared"
      ;;

    *)
      echo "Usage: $0 {evaluate|list|add|clear}"
      exit 1
      ;;
  esac
}

main "$@"
