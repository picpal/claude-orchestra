#!/bin/bash
# tdd-post-check.sh - Agent Groups 작업 완료 후 TDD 준수 검증 + Conflict-Checker 리마인더
# Hook: SubagentStop
#
# TDD 3-Layer Defense의 Verification Layer 역할:
# - 테스트 삭제/스킵 감지
# - 테스트 없는 구현 감지
# - 테스트 실패 감지
# - 병렬 실행 완료 시 Conflict-Checker 리마인더

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"

ensure_orchestra_dirs

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$ORCHESTRA_LOG_DIR/tdd-violations.log"

VIOLATIONS=0
WARNINGS=""

# 1. 테스트 삭제 감지
check_test_deletion() {
  if git diff --name-status HEAD~1 2>/dev/null | grep -E "^D.*\.(test|spec)\.(ts|js|tsx|jsx)$" > /dev/null; then
    VIOLATIONS=$((VIOLATIONS + 1))
    WARNINGS="${WARNINGS}[CRITICAL] Test file deletion detected\n"
    echo "[$TIMESTAMP] TDD_VIOLATION: Test file deleted" >> "$LOG_FILE"
    return 1
  fi
  return 0
}

# 2. 테스트 스킵 감지 (.skip, .only 추가)
check_test_skip() {
  if git diff HEAD~1 2>/dev/null | grep -E "^\+.*\.(skip|only)\(" > /dev/null; then
    VIOLATIONS=$((VIOLATIONS + 1))
    WARNINGS="${WARNINGS}[HIGH] Test skip/only detected in changes\n"
    echo "[$TIMESTAMP] TDD_VIOLATION: Test skip/only added" >> "$LOG_FILE"
    return 1
  fi
  return 0
}

# 3. 구현 파일 변경 시 테스트 파일 변경 확인
check_impl_without_test() {
  local impl_files=$(git diff --name-only HEAD~1 2>/dev/null | grep -E "\.(ts|js|tsx|jsx)$" | grep -vE "\.(test|spec)\." | grep -v "__tests__" || true)
  local test_files=$(git diff --name-only HEAD~1 2>/dev/null | grep -E "\.(test|spec)\.(ts|js|tsx|jsx)$" || true)

  if [ -n "$impl_files" ] && [ -z "$test_files" ]; then
    # 새 구현 파일이 추가되었는데 테스트가 없는 경우
    if git diff --name-status HEAD~1 2>/dev/null | grep -E "^A.*\.(ts|js|tsx|jsx)$" | grep -vE "\.(test|spec)\." > /dev/null; then
      WARNINGS="${WARNINGS}[MEDIUM] New implementation without corresponding test\n"
      echo "[$TIMESTAMP] TDD_WARNING: Implementation added without test" >> "$LOG_FILE"
    fi
  fi
  return 0
}

# 4. 테스트 실행 확인 (npm test가 가능한 경우)
check_tests_pass() {
  if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    if ! npm test --silent 2>/dev/null; then
      VIOLATIONS=$((VIOLATIONS + 1))
      WARNINGS="${WARNINGS}[CRITICAL] Tests are failing\n"
      echo "[$TIMESTAMP] TDD_VIOLATION: Tests failing" >> "$LOG_FILE"
      return 1
    fi
  fi
  return 0
}

# 메인 실행
echo "[$TIMESTAMP] TDD_POST_CHECK: Starting verification" >> "$LOG_FILE"

# Git이 있고 커밋이 있는 경우에만 검사
if git rev-parse --git-dir > /dev/null 2>&1; then
  if git rev-parse HEAD~1 > /dev/null 2>&1; then
    check_test_deletion || true
    check_test_skip || true
    check_impl_without_test || true
    # 테스트 실행은 선택적 (시간이 오래 걸릴 수 있음)
    # check_tests_pass || true
  fi
fi

# 결과 기록
if [ $VIOLATIONS -gt 0 ]; then
  echo "[$TIMESTAMP] TDD_POST_CHECK: FAILED (violations=$VIOLATIONS)" >> "$LOG_FILE"

  # state.json에 위반 기록
  if [ -f "$ORCHESTRA_STATE_FILE" ]; then
    python3 -c "
import json
import sys
state_file = sys.argv[1]
violations = int(sys.argv[2])
with open(state_file, 'r') as f:
    d = json.load(f)
if 'tddMetrics' not in d:
    d['tddMetrics'] = {'testCount': 0, 'redGreenCycles': 0, 'testDeletionAttempts': 0}
d['tddMetrics']['testDeletionAttempts'] = d['tddMetrics'].get('testDeletionAttempts', 0) + violations
with open(state_file, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" "$ORCHESTRA_STATE_FILE" "$VIOLATIONS" 2>/dev/null || true
  fi

  # STDERR로 경고 출력 (사용자에게 표시)
  echo -e "$WARNINGS" >&2

  # 위반이 있어도 hook 자체는 실패하지 않음 (로깅만)
  # 차단이 필요하면 exit 1
fi

echo "[$TIMESTAMP] TDD_POST_CHECK: Completed (violations=$VIOLATIONS)" >> "$LOG_FILE"

# 병렬 실행 완료 확인 및 Conflict-Checker 리마인더
if [ -f "$ORCHESTRA_STATE_FILE" ]; then
  # 모든 팀원이 완료되었는지 확인
  ALL_DONE=$(python3 -c "
import json
import sys
try:
    with open(sys.argv[1], 'r') as f:
        d = json.load(f)
    ats = d.get('agentGroupsStatus', {})
    teammates = ats.get('teammates', [])
    if len(teammates) >= 2:  # 2명 이상 병렬 실행
        all_completed = all(t.get('status') == 'completed' for t in teammates)
        if all_completed:
            print('yes')
        else:
            print('no')
    else:
        print('no')
except:
    print('no')
" "$ORCHESTRA_STATE_FILE" 2>/dev/null)

  if [ "$ALL_DONE" = "yes" ]; then
    echo ""
    echo "🔍 [Orchestra] 병렬 실행 완료 - Conflict-Checker 실행 필요!"
    echo ""
    echo "다음 단계로 Conflict-Checker를 호출하세요:"
    echo "  Task(subagent_type=\"general-purpose\","
    echo "       description=\"Conflict-Checker: 병렬 실행 충돌 검사\","
    echo "       model=\"sonnet\","
    echo "       prompt=\"병렬 실행된 작업들의 충돌을 검사해주세요.\")"
    echo ""

    echo "[$TIMESTAMP] CONFLICT_CHECK_REMINDER: Parallel execution completed, conflict check needed" >> "$LOG_FILE"
  fi
fi

exit 0
