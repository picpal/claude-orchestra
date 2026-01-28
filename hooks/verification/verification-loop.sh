#!/bin/bash
# Verification Loop - Main Orchestrator
# 6단계 검증 루프를 실행합니다.

set -e

# macOS/Linux 호환 밀리초 타임스탬프
now_ms() {
  python3 -c "import time; print(int(time.time()*1000))"
}

# 인자 파싱
MODE="${1:-standard}"  # quick, standard, full, pre-pr
EXPECTED_FILES="${2:-}"
MIN_COVERAGE="${3:-80}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR=".orchestra/logs"
STATE_FILE=".orchestra/state.json"

# 로그 디렉토리 생성
mkdir -p "$LOG_DIR"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 시작 시간
LOOP_START=$(now_ms)

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               VERIFICATION LOOP                                ║"
echo "║               Mode: $MODE                                      "
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# 결과 추적
BUILD_STATUS="skip"
TYPE_STATUS="skip"
LINT_STATUS="skip"
TEST_STATUS="skip"
SECURITY_STATUS="skip"
DIFF_STATUS="skip"

BUILD_DURATION=0
TYPE_DURATION=0
LINT_DURATION=0
TEST_DURATION=0
SECURITY_DURATION=0
DIFF_DURATION=0

BLOCKERS=()
PR_READY=true

# Phase 실행 함수
run_phase() {
  local phase_name="$1"
  local script="$2"
  local result_file="$3"
  shift 3
  local args=("$@")

  echo "────────────────────────────────────────────────────────────────"
  echo "Phase: $phase_name"
  echo "────────────────────────────────────────────────────────────────"

  if [ -x "$script" ]; then
    if "$script" "$result_file" "${args[@]}"; then
      return 0
    else
      return 1
    fi
  else
    echo "⏭️ Script not found: $script"
    return 0
  fi
}

# Mode에 따른 Phase 실행
case "$MODE" in
  quick)
    # Quick: Build + Types only
    PHASES=("build" "types")
    ;;
  standard)
    # Standard: Build + Types + Lint + Tests
    PHASES=("build" "types" "lint" "tests")
    ;;
  full)
    # Full: All 6 phases
    PHASES=("build" "types" "lint" "tests" "security" "diff")
    ;;
  pre-pr)
    # Pre-PR: All phases with stricter checks
    PHASES=("build" "types" "lint" "tests" "security" "diff")
    MIN_COVERAGE=80
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Available modes: quick, standard, full, pre-pr"
    exit 1
    ;;
esac

# Phase 1: Build
if [[ " ${PHASES[*]} " =~ " build " ]]; then
  if run_phase "Build Verification" "$SCRIPT_DIR/build-check.sh" "$LOG_DIR/verification-build.json"; then
    BUILD_STATUS="pass"
  else
    BUILD_STATUS="fail"
    BLOCKERS+=("Build failed")
    PR_READY=false
    echo ""
    echo -e "${RED}❌ Build failed - stopping verification${NC}"
    # Build 실패 시 중단
    LOOP_END=$(now_ms)
    TOTAL_DURATION=$((LOOP_END - LOOP_START))

    # 결과 출력
    "$SCRIPT_DIR/verification-report.sh" "$MODE" "$TOTAL_DURATION" \
      "$BUILD_STATUS" "$TYPE_STATUS" "$LINT_STATUS" "$TEST_STATUS" "$SECURITY_STATUS" "$DIFF_STATUS" \
      "$PR_READY"
    exit 1
  fi

  if [ -f "$LOG_DIR/verification-build.json" ] && command -v jq &> /dev/null; then
    BUILD_DURATION=$(jq '.duration // 0' "$LOG_DIR/verification-build.json")
  fi
fi

echo ""

# Phase 2: Type Check
if [[ " ${PHASES[*]} " =~ " types " ]]; then
  if run_phase "Type Check" "$SCRIPT_DIR/type-check.sh" "$LOG_DIR/verification-types.json"; then
    TYPE_STATUS="pass"
  else
    TYPE_STATUS="fail"
    BLOCKERS+=("Type check failed")
    PR_READY=false
  fi

  if [ -f "$LOG_DIR/verification-types.json" ] && command -v jq &> /dev/null; then
    TYPE_DURATION=$(jq '.duration // 0' "$LOG_DIR/verification-types.json")
  fi
fi

echo ""

# Phase 3: Lint
if [[ " ${PHASES[*]} " =~ " lint " ]]; then
  if run_phase "Lint Check" "$SCRIPT_DIR/lint-check.sh" "$LOG_DIR/verification-lint.json"; then
    LINT_STATUS="pass"
    # warn 상태 확인
    if [ -f "$LOG_DIR/verification-lint.json" ] && command -v jq &> /dev/null; then
      LINT_STATUS=$(jq -r '.status // "pass"' "$LOG_DIR/verification-lint.json")
    fi
  else
    LINT_STATUS="fail"
    BLOCKERS+=("Lint check failed")
    PR_READY=false
  fi

  if [ -f "$LOG_DIR/verification-lint.json" ] && command -v jq &> /dev/null; then
    LINT_DURATION=$(jq '.duration // 0' "$LOG_DIR/verification-lint.json")
  fi
fi

echo ""

# Phase 4: Tests
if [[ " ${PHASES[*]} " =~ " tests " ]]; then
  if run_phase "Test Suite" "$SCRIPT_DIR/test-coverage.sh" "$LOG_DIR/verification-tests.json" "$MIN_COVERAGE"; then
    TEST_STATUS="pass"
  else
    TEST_STATUS="fail"
    BLOCKERS+=("Tests failed or coverage below ${MIN_COVERAGE}%")
    PR_READY=false
  fi

  if [ -f "$LOG_DIR/verification-tests.json" ] && command -v jq &> /dev/null; then
    TEST_DURATION=$(jq '.duration // 0' "$LOG_DIR/verification-tests.json")
  fi
fi

echo ""

# Phase 5: Security
if [[ " ${PHASES[*]} " =~ " security " ]]; then
  if run_phase "Security Scan" "$SCRIPT_DIR/security-scan.sh" "$LOG_DIR/verification-security.json"; then
    SECURITY_STATUS="pass"
    # warn 상태 확인
    if [ -f "$LOG_DIR/verification-security.json" ] && command -v jq &> /dev/null; then
      SECURITY_STATUS=$(jq -r '.status // "pass"' "$LOG_DIR/verification-security.json")
    fi
  else
    SECURITY_STATUS="fail"
    BLOCKERS+=("Security scan found critical issues")
    PR_READY=false
  fi

  if [ -f "$LOG_DIR/verification-security.json" ] && command -v jq &> /dev/null; then
    SECURITY_DURATION=$(jq '.duration // 0' "$LOG_DIR/verification-security.json")
  fi
fi

echo ""

# Phase 6: Diff Review
if [[ " ${PHASES[*]} " =~ " diff " ]]; then
  if run_phase "Diff Review" "$SCRIPT_DIR/diff-review.sh" "$LOG_DIR/verification-diff.json" "$EXPECTED_FILES"; then
    DIFF_STATUS="pass"
    # warn 상태 확인
    if [ -f "$LOG_DIR/verification-diff.json" ] && command -v jq &> /dev/null; then
      DIFF_STATUS=$(jq -r '.status // "pass"' "$LOG_DIR/verification-diff.json")
    fi
  else
    DIFF_STATUS="fail"
  fi

  if [ -f "$LOG_DIR/verification-diff.json" ] && command -v jq &> /dev/null; then
    DIFF_DURATION=$(jq '.duration // 0' "$LOG_DIR/verification-diff.json")
  fi
fi

# 종료 시간
LOOP_END=$(now_ms)
TOTAL_DURATION=$((LOOP_END - LOOP_START))

# 리포트 생성
"$SCRIPT_DIR/verification-report.sh" "$MODE" "$TOTAL_DURATION" \
  "$BUILD_STATUS" "$TYPE_STATUS" "$LINT_STATUS" "$TEST_STATUS" "$SECURITY_STATUS" "$DIFF_STATUS" \
  "$PR_READY"

# state.json 업데이트
if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
  BLOCKERS_JSON="["
  first=true
  for blocker in "${BLOCKERS[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      BLOCKERS_JSON+=","
    fi
    BLOCKERS_JSON+="\"$blocker\""
  done
  BLOCKERS_JSON+="]"

  jq --arg mode "$MODE" \
     --arg lastRun "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg prReady "$PR_READY" \
     --argjson blockers "$BLOCKERS_JSON" \
     '.verificationMetrics.mode = $mode |
      .verificationMetrics.lastRun = $lastRun |
      .verificationMetrics.prReady = ($prReady == "true") |
      .verificationMetrics.blockers = $blockers' \
     "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# 최종 결과
if [ "$PR_READY" = "true" ]; then
  echo ""
  echo -e "${GREEN}✅ PR Ready - All checks passed${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}❌ Not PR Ready - Please fix the blockers${NC}"
  exit 1
fi
