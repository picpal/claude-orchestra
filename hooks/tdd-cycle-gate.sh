#!/usr/bin/env bash
# TDD Cycle Gate Hook
# Player 에이전트의 TDD RED->GREEN 순서를 강제합니다.
# PreToolUse Hook (Edit|Write 매처) — tdd-guard.sh 뒤에 실행
#
# 상태 머신:
#   IDLE -> RED_PENDING -> RED_CONFIRMED -> GREEN_PENDING -> GREEN_CONFIRMED -> REFACTOR
#
# 상태 파일: .orchestra/logs/.tdd-cycle-state-{agent_id}.json (에이전트별 분리)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

LOG_FILE="$ORCHESTRA_LOG_DIR/tdd-cycle-gate.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# === 에이전트 스택에서 현재 에이전트 정보 조회 ===
AGENT_STACK_FILE="$ORCHESTRA_LOG_DIR/.agent-stack"

get_current_agent_info() {
  if [ -f "$AGENT_STACK_FILE" ]; then
    tail -1 "$AGENT_STACK_FILE" 2>/dev/null
  fi
}

get_current_agent_type() {
  local info
  info=$(get_current_agent_info)
  if [ -n "$info" ]; then
    echo "$info" | cut -d'|' -f2
  fi
}

get_current_agent_id() {
  local info
  info=$(get_current_agent_info)
  if [ -n "$info" ]; then
    echo "$info" | cut -d'|' -f1
  fi
}

# === Player 에이전트 확인 ===
is_player_agent() {
  local agent="$1"
  local agent_lower
  agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')
  case "$agent_lower" in
    high-player|low-player) return 0 ;;
    *) return 1 ;;
  esac
}

# === 면제 파일 확인 ===
# TDD 강제 대상이 아닌 파일들
is_exempt_file() {
  local file_path="$1"

  # 마크다운, YAML, TOML, env 파일
  if echo "$file_path" | grep -qE '\.(md|yaml|yml|toml)$'; then
    return 0
  fi

  # env 파일
  if echo "$file_path" | grep -qE '\.env'; then
    return 0
  fi

  # src/ 외부의 JSON 파일 (package.json, tsconfig.json 등)
  if echo "$file_path" | grep -qE '\.json$'; then
    if ! echo "$file_path" | grep -qE '^src/'; then
      return 0
    fi
  fi

  # .orchestra/*, .claude/* 디렉토리
  if echo "$file_path" | grep -qE '^\.(orchestra|claude)/'; then
    return 0
  fi

  # 타입 정의 파일
  if echo "$file_path" | grep -qE '\.d\.ts$'; then
    return 0
  fi

  # 설정 파일
  if echo "$file_path" | grep -qE '\.(config|rc)\.(ts|js|mjs|cjs)$'; then
    return 0
  fi
  if echo "$file_path" | grep -qE '^\.' | grep -qE 'rc$'; then
    return 0
  fi

  # 루트 설정 파일들
  if echo "$file_path" | grep -qE '^(package\.json|tsconfig\.json|jest\.config|vite\.config|next\.config|webpack\.config|\.eslintrc|\.prettierrc|tailwind\.config|postcss\.config)'; then
    return 0
  fi

  return 1
}

# === 테스트 파일 확인 ===
is_test_file() {
  local file="$1"
  if echo "$file" | grep -qE '\.(test|spec)\.(ts|tsx|js|jsx)$'; then
    return 0
  fi
  if echo "$file" | grep -qE '__tests__/'; then
    return 0
  fi
  return 1
}

# === 대응 테스트 파일 추론 ===
# impl 파일 경로에서 가능한 테스트 파일 경로들을 생성
find_corresponding_test() {
  local impl_file="$1"
  local dir base ext

  dir=$(dirname "$impl_file")
  base=$(basename "$impl_file")
  ext="${base##*.}"
  base="${base%.*}"

  # 가능한 테스트 파일 경로들
  local test_paths=(
    "${dir}/__tests__/${base}.test.${ext}"
    "${dir}/__tests__/${base}.spec.${ext}"
    "${dir}/${base}.test.${ext}"
    "${dir}/${base}.spec.${ext}"
  )

  # tsx/jsx 변환도 고려
  if [ "$ext" = "ts" ]; then
    test_paths+=(
      "${dir}/__tests__/${base}.test.tsx"
      "${dir}/${base}.test.tsx"
    )
  fi

  for test_path in "${test_paths[@]}"; do
    if [ -f "$ORCHESTRA_ROOT/$test_path" ]; then
      echo "$test_path"
      return 0
    fi
  done

  # 첫 번째 후보 경로 반환 (존재하지 않더라도 제안용)
  echo "${test_paths[0]}"
  return 1
}

# === TDD 상태 파일 읽기 ===
get_tdd_phase() {
  local state_file="$1"
  if [ ! -f "$state_file" ]; then
    echo "IDLE"
    return
  fi
  python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    print(d.get('phase', 'IDLE'))
except Exception:
    print('IDLE')
" "$state_file" 2>/dev/null
}

get_tdd_test_files() {
  local state_file="$1"
  if [ ! -f "$state_file" ]; then
    echo "[]"
    return
  fi
  python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    files = d.get('testFiles', [])
    print(', '.join(files) if files else '(none)')
except Exception:
    print('(none)')
" "$state_file" 2>/dev/null
}

# === TDD 상태 파일 업데이트 ===
set_tdd_phase() {
  local state_file="$1"
  local new_phase="$2"
  local file_path="${3:-}"

  python3 -c "
import json, sys
from datetime import datetime

state_file = sys.argv[1]
new_phase = sys.argv[2]
file_path = sys.argv[3] if len(sys.argv) > 3 else ''

try:
    with open(state_file) as f:
        d = json.load(f)
except Exception:
    d = {'phase': 'IDLE', 'testFiles': [], 'implFiles': [], 'cycleHistory': []}

old_phase = d.get('phase', 'IDLE')
d['phase'] = new_phase
d['updatedAt'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

if file_path:
    if new_phase in ('RED_PENDING',) and file_path not in d.get('testFiles', []):
        d.setdefault('testFiles', []).append(file_path)
    elif new_phase in ('GREEN_PENDING',) and file_path not in d.get('implFiles', []):
        d.setdefault('implFiles', []).append(file_path)

# 사이클 히스토리에 전이 기록
d.setdefault('cycleHistory', []).append({
    'from': old_phase,
    'to': new_phase,
    'file': file_path,
    'at': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
})

with open(state_file, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" "$state_file" "$new_phase" "$file_path" 2>/dev/null
}

# === TODO 타입 확인 (CHORE면 면제) ===
is_chore_todo() {
  local agent_id="$1"
  local chore_flag="$ORCHESTRA_LOG_DIR/.todo-type-${agent_id}"
  if [ -f "$chore_flag" ] && grep -qi "CHORE" "$chore_flag" 2>/dev/null; then
    return 0
  fi
  return 1
}

# === 메인 로직 ===
main() {
  local current_agent
  current_agent=$(get_current_agent_type)

  # Player 에이전트가 아니면 SKIP
  if [ -z "$current_agent" ] || ! is_player_agent "$current_agent"; then
    exit 0
  fi

  local agent_id
  agent_id=$(get_current_agent_id)

  # CHORE 타입이면 SKIP
  if is_chore_todo "$agent_id"; then
    log "SKIP: CHORE type TODO for agent $agent_id"
    exit 0
  fi

  # 파일 경로 추출
  local file_path
  file_path=$(hook_get_field "tool_input.file_path")

  if [ -z "$file_path" ]; then
    exit 0
  fi

  # 상대 경로로 변환 (ORCHESTRA_ROOT 기준)
  local rel_path="$file_path"
  if [[ "$file_path" == "$ORCHESTRA_ROOT"/* ]]; then
    rel_path="${file_path#$ORCHESTRA_ROOT/}"
  fi

  log "Check: agent=$current_agent, id=$agent_id, file=$rel_path"

  # 면제 파일이면 SKIP
  if is_exempt_file "$rel_path"; then
    log "SKIP: exempt file $rel_path"
    exit 0
  fi

  # TDD 상태 파일
  local tdd_state_file="$ORCHESTRA_LOG_DIR/.tdd-cycle-state-${agent_id}.json"
  local current_phase
  current_phase=$(get_tdd_phase "$tdd_state_file")

  log "Phase: $current_phase, file: $rel_path"

  # === 테스트 파일 작성 ===
  if is_test_file "$rel_path"; then
    # 테스트 파일 작성은 항상 허용
    if [ "$current_phase" = "IDLE" ] || [ "$current_phase" = "GREEN_CONFIRMED" ] || [ "$current_phase" = "REFACTOR" ]; then
      set_tdd_phase "$tdd_state_file" "RED_PENDING" "$rel_path"
      log "ALLOWED: test file → RED_PENDING"
    fi
    # RED_PENDING/RED_CONFIRMED 상태에서도 테스트 추가 편집 허용
    exit 0
  fi

  # === 구현(impl) 파일 작성 ===

  case "$current_phase" in
    RED_CONFIRMED|GREEN_PENDING)
      # 테스트 실패 확인 후 구현 허용
      set_tdd_phase "$tdd_state_file" "GREEN_PENDING" "$rel_path"
      log "ALLOWED: impl file in $current_phase → GREEN_PENDING"
      exit 0
      ;;

    GREEN_CONFIRMED|REFACTOR)
      # 리팩토링 단계 허용
      set_tdd_phase "$tdd_state_file" "REFACTOR" "$rel_path"
      log "ALLOWED: impl file in $current_phase → REFACTOR"
      exit 0
      ;;

    IDLE)
      # 대응 테스트 파일이 이미 존재하면 허용 (기존 코드 수정)
      local test_path
      test_path=$(find_corresponding_test "$rel_path")
      local test_exists=$?

      if [ $test_exists -eq 0 ]; then
        log "ALLOWED: existing test found at $test_path (IDLE → bypass)"
        echo ""
        echo "[TDD Cycle Gate] 기존 테스트 파일 감지. 수정 후 테스트 실행을 권장합니다."
        echo "  테스트 파일: $test_path"
        echo ""
        exit 0
      fi

      # 대응 테스트 없음 → BLOCK
      local test_files
      test_files=$(get_tdd_test_files "$tdd_state_file")

      log "BLOCKED: no test for $rel_path in IDLE"
      echo ""
      echo "[TDD Cycle Gate] RED Phase Not Confirmed!"
      echo ""
      echo "  현재 상태: $current_phase"
      echo "  차단된 파일: $rel_path"
      echo ""
      echo "  다음 단계:"
      echo "    1. 테스트 파일을 작성하세요: $test_path"
      echo "    2. 테스트를 실행하세요: npm test (또는 jest/pytest)"
      echo "    3. 테스트 FAIL을 확인한 후 구현을 작성하세요"
      echo ""
      echo "  작성된 테스트 파일: $test_files"
      echo ""
      exit 1
      ;;

    RED_PENDING)
      # 테스트를 작성했지만 아직 실행하지 않음 → BLOCK
      local test_files
      test_files=$(get_tdd_test_files "$tdd_state_file")

      log "BLOCKED: test not executed yet ($current_phase)"
      echo ""
      echo "[TDD Cycle Gate] RED Phase Not Confirmed!"
      echo ""
      echo "  현재 상태: $current_phase (테스트 작성됨, 실행 필요)"
      echo "  차단된 파일: $rel_path"
      echo ""
      echo "  다음 단계:"
      echo "    1. 테스트를 실행하세요: npm test (또는 jest/pytest)"
      echo "    2. 테스트 FAIL을 확인한 후 구현을 작성하세요"
      echo ""
      echo "  작성된 테스트 파일: $test_files"
      echo ""
      exit 1
      ;;

    *)
      # 알 수 없는 상태 → 안전을 위해 허용 (경고)
      log "WARNING: unknown phase $current_phase, allowing"
      exit 0
      ;;
  esac
}

main
