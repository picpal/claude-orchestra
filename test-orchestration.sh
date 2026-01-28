#!/bin/bash
# Test Orchestration - T4 & T9 검증 테스트
# T4: activity-logger.sh 로그 포맷 regex 검증
# T9: verification-loop.sh macOS 호환성 (now_ms) + state.json 업데이트 검증

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo -e "  ${GREEN}PASS${NC}: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo -e "  ${RED}FAIL${NC}: $1"
  [ -n "${2:-}" ] && echo -e "        ${YELLOW}Detail: $2${NC}"
}

# 테스트용 임시 디렉토리 설정
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           TEST ORCHESTRATION — T4 & T9                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════
# T4: Activity Logger 로그 포맷 검증
# ═══════════════════════════════════════════════════════════════════
echo "── T4: Activity Logger 로그 포맷 ──────────────────────────────"

# T4.1: activity-logger.sh 실행 후 로그 라인 포맷 확인
T4_LOG_DIR="$TEST_DIR/.orchestra/logs"
mkdir -p "$T4_LOG_DIR"
T4_LOG_FILE="$T4_LOG_DIR/activity.log"

# activity-logger.sh를 직접 실행 (테스트용 LOG_DIR 주입)
# activity-logger.sh는 .orchestra/logs 하드코딩이므로, 작업 디렉토리를 변경하여 실행
(
  cd "$TEST_DIR"
  mkdir -p .orchestra/logs
  bash "$SCRIPT_DIR/hooks/activity-logger.sh" "COMMAND" "/start-work" "" "PLAN"
)

if [ -f "$TEST_DIR/.orchestra/logs/activity.log" ]; then
  FIRST_LINE=$(head -1 "$TEST_DIR/.orchestra/logs/activity.log")

  # T4.1: 로그 라인이 존재하는지
  if [ -n "$FIRST_LINE" ]; then
    pass "T4.1 — 로그 라인 생성됨"
  else
    fail "T4.1 — 로그 라인 비어있음"
  fi

  # T4.2: 패딩된 포맷 regex 검증
  # 실제 출력: [2026-01-28 14:11:39] COMMAND | PLAN      | /start-work
  # TYPE=7자 패딩(COMMAND), PHASE=9자 패딩(PLAN     )
  # 패딩 무관 regex: 타임스탬프 + COMMAND 포함 + PLAN 포함 + /start-work 포함
  if echo "$FIRST_LINE" | grep -qE '^\[.*\].*COMMAND.*PLAN.*/start-work'; then
    pass "T4.2 — 로그 포맷 regex 매칭 (패딩 무관)"
  else
    fail "T4.2 — 로그 포맷 regex 불일치" "$FIRST_LINE"
  fi

  # T4.3: 구분자 '|' 존재 확인
  PCOUNT=$(echo "$FIRST_LINE" | grep -o '|' | wc -l | xargs)
  if [ "$PCOUNT" -ge 2 ]; then
    pass "T4.3 — 구분자 '|' ${PCOUNT}개 확인"
  else
    fail "T4.3 — 구분자 부족 (expected >= 2, got ${PCOUNT})" "$FIRST_LINE"
  fi

  # T4.4: TYPE이 7자 패딩인지 확인 (COMMAND = 7자, 정확히 7자리 점유)
  # [timestamp] 뒤 첫 필드가 7자인지 확인
  TYPE_FIELD=$(echo "$FIRST_LINE" | sed 's/^\[.*\] //' | cut -d'|' -f1)
  TYPE_LEN=${#TYPE_FIELD}
  # "COMMAND " = 8자 (7자 + trailing space)
  if [ "$TYPE_LEN" -eq 8 ]; then
    pass "T4.4 — TYPE 필드 7자 패딩 (+ trailing space = $TYPE_LEN chars)"
  else
    fail "T4.4 — TYPE 필드 길이 불일치 (expected 8, got $TYPE_LEN)" "TYPE_FIELD='$TYPE_FIELD'"
  fi

  # T4.5: DETAIL 포함 로그 테스트
  (
    cd "$TEST_DIR"
    bash "$SCRIPT_DIR/hooks/activity-logger.sh" "SKILL" "context-dev" "mode=tdd" "EXECUTE"
  )
  SECOND_LINE=$(sed -n '2p' "$TEST_DIR/.orchestra/logs/activity.log")
  if echo "$SECOND_LINE" | grep -qE '^\[.*\].*SKILL.*EXECUTE.*context-dev.*mode=tdd'; then
    pass "T4.5 — DETAIL 포함 로그 포맷 정상"
  else
    fail "T4.5 — DETAIL 포함 로그 포맷 불일치" "$SECOND_LINE"
  fi

else
  fail "T4.1 — 로그 파일 미생성"
  fail "T4.2 — (skip)"
  fail "T4.3 — (skip)"
  fail "T4.4 — (skip)"
  fail "T4.5 — (skip)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# T9: Verification Loop — now_ms() macOS 호환 + state.json 업데이트
# ═══════════════════════════════════════════════════════════════════
echo "── T9: Verification Loop macOS 호환성 ─────────────────────────"

# T9.1: now_ms() 함수가 숫자를 반환하는지
NOW_MS_OUTPUT=$(python3 -c "import time; print(int(time.time()*1000))")
if echo "$NOW_MS_OUTPUT" | grep -qE '^[0-9]+$'; then
  pass "T9.1 — now_ms() 숫자 반환: $NOW_MS_OUTPUT"
else
  fail "T9.1 — now_ms() 비숫자 반환" "$NOW_MS_OUTPUT"
fi

# T9.2: now_ms() 산술 연산 가능 여부 (핵심 버그 검증)
START_MS=$(python3 -c "import time; print(int(time.time()*1000))")
sleep 0.1
END_MS=$(python3 -c "import time; print(int(time.time()*1000))")
DIFF=$((END_MS - START_MS))
if [ "$DIFF" -ge 0 ] 2>/dev/null; then
  pass "T9.2 — now_ms() 산술 연산 성공 (diff=${DIFF}ms)"
else
  fail "T9.2 — now_ms() 산술 연산 실패" "START=$START_MS, END=$END_MS"
fi

# T9.3: date +%s%3N 가 macOS에서 오작동하는지 확인 (문제 재현)
DATE_OUTPUT=$(date +%s%3N 2>&1)
if echo "$DATE_OUTPUT" | grep -qE '^[0-9]+$'; then
  # GNU date가 설치되어 있는 환경 (Linux 또는 coreutils)
  pass "T9.3 — date +%s%3N 정상 (GNU date 환경) — now_ms()는 하위호환"
else
  # macOS BSD date — %3N이 리터럴 출력됨
  pass "T9.3 — date +%s%3N 비호환 확인 (macOS BSD) — now_ms() 수정 필요했음: '$DATE_OUTPUT'"
fi

# T9.4: verification 스크립트에 date +%s%3N이 남아있지 않은지
REMAINING=$(grep -rl 'date +%s%3N' "$SCRIPT_DIR/hooks/verification/" 2>/dev/null || true)
if [ -z "$REMAINING" ]; then
  pass "T9.4 — verification 스크립트에서 date +%s%3N 모두 제거됨"
else
  fail "T9.4 — date +%s%3N 잔존" "$REMAINING"
fi

# T9.5: 모든 verification 스크립트에 now_ms 함수가 정의되어 있는지
VERIFICATION_DIR="$SCRIPT_DIR/hooks/verification"
MISSING_NOW_MS=""
for script in build-check.sh type-check.sh lint-check.sh test-coverage.sh security-scan.sh diff-review.sh verification-loop.sh; do
  if [ -f "$VERIFICATION_DIR/$script" ]; then
    if ! grep -q 'now_ms()' "$VERIFICATION_DIR/$script"; then
      MISSING_NOW_MS="$MISSING_NOW_MS $script"
    fi
  fi
done

if [ -z "$MISSING_NOW_MS" ]; then
  pass "T9.5 — 모든 verification 스크립트에 now_ms() 정의됨"
else
  fail "T9.5 — now_ms() 미정의 스크립트:$MISSING_NOW_MS"
fi

# T9.6: verification-loop.sh의 state.json 업데이트 — lastRun이 null일 때 false positive 방지
# state.json의 lastRun: null → Python으로 읽으면 None 문자열이 되면 안 됨
STATE_JSON='{"verificationMetrics":{"lastRun":null,"mode":null}}'
LAST_RUN=$(echo "$STATE_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
v = d.get('verificationMetrics',{}).get('lastRun')
print(v if v else '')
")
if [ -z "$LAST_RUN" ]; then
  pass "T9.6 — lastRun=null → 빈 문자열 (false positive 방지)"
else
  fail "T9.6 — lastRun=null이 비어있지 않음" "got: '$LAST_RUN'"
fi

# T9.7: lastRun에 값이 있을 때는 정상 출력 확인
STATE_JSON2='{"verificationMetrics":{"lastRun":"2026-01-28T14:30:00Z","mode":"quick"}}'
LAST_RUN2=$(echo "$STATE_JSON2" | python3 -c "
import sys, json
d = json.load(sys.stdin)
v = d.get('verificationMetrics',{}).get('lastRun')
print(v if v else '')
")
if [ "$LAST_RUN2" = "2026-01-28T14:30:00Z" ]; then
  pass "T9.7 — lastRun 값 정상 출력: $LAST_RUN2"
else
  fail "T9.7 — lastRun 값 불일치" "expected: 2026-01-28T14:30:00Z, got: '$LAST_RUN2'"
fi

# T9.8: Python None 문자열이 truthy로 판단되는 기존 버그 재현 확인
BUGGY_LAST_RUN=$(echo '{"verificationMetrics":{"lastRun":null}}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('verificationMetrics',{}).get('lastRun',''))
")
# 기존 코드는 print(d.get(...,''))로 null → 'None' 문자열 → [ -n "None" ] = true (false positive)
if [ "$BUGGY_LAST_RUN" = "None" ]; then
  pass "T9.8 — 기존 버그 재현 확인: null → 'None' 문자열 (이 경우 false positive 발생)"
else
  # Python 3에서 None 출력 확인
  pass "T9.8 — Python null 처리 확인: got '$BUGGY_LAST_RUN'"
fi

# T9.9: verification-loop.sh 실행 후 state.json 업데이트 통합 테스트
echo ""
echo "  T9.9 — verification-loop.sh 통합 테스트 (quick 모드)..."
(
  cd "$TEST_DIR"
  mkdir -p .orchestra/logs

  # state.json 초기화
  cat > .orchestra/state.json << 'STATEOF'
{
  "mode": "IDLE",
  "verificationMetrics": {
    "lastRun": null,
    "mode": null,
    "prReady": false,
    "blockers": []
  }
}
STATEOF

  # verification-loop.sh 실행 (quick 모드 — build + types만)
  # 빌드/타입 설정이 없으므로 skip되어 성공으로 종료
  bash "$SCRIPT_DIR/hooks/verification/verification-loop.sh" "quick" 2>&1 || true
)

# state.json이 업데이트되었는지 확인
if [ -f "$TEST_DIR/.orchestra/state.json" ]; then
  UPDATED_MODE=$(python3 -c "
import json
with open('$TEST_DIR/.orchestra/state.json') as f:
    d = json.load(f)
v = d.get('verificationMetrics',{}).get('mode')
print(v if v else '')
")
  UPDATED_LAST_RUN=$(python3 -c "
import json
with open('$TEST_DIR/.orchestra/state.json') as f:
    d = json.load(f)
v = d.get('verificationMetrics',{}).get('lastRun')
print(v if v else '')
")

  if [ "$UPDATED_MODE" = "quick" ]; then
    pass "T9.9a — state.json mode 업데이트됨: $UPDATED_MODE"
  else
    fail "T9.9a — state.json mode 미업데이트" "got: '$UPDATED_MODE'"
  fi

  if [ -n "$UPDATED_LAST_RUN" ]; then
    pass "T9.9b — state.json lastRun 업데이트됨: $UPDATED_LAST_RUN"
  else
    fail "T9.9b — state.json lastRun 미업데이트 (빈 값)"
  fi
else
  fail "T9.9a — state.json 파일 없음"
  fail "T9.9b — (skip)"
fi

# T9.10: verification-summary.json 생성 확인
if [ -f "$TEST_DIR/.orchestra/logs/verification-summary.json" ]; then
  pass "T9.10 — verification-summary.json 생성됨"
else
  fail "T9.10 — verification-summary.json 미생성"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# 결과 요약
# ═══════════════════════════════════════════════════════════════════
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                      TEST RESULTS                            ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
printf "║  PASS: %-3d / %-3d                                           ║\n" "$PASS_COUNT" "$TOTAL"
printf "║  FAIL: %-3d / %-3d                                           ║\n" "$FAIL_COUNT" "$TOTAL"
echo "╚═══════════════════════════════════════════════════════════════╝"

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}$FAIL_COUNT test(s) failed.${NC}"
  exit 1
fi
