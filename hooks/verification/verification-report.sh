#!/bin/bash
# Verification Report Generator
# 검증 결과를 보기 좋게 출력합니다.

MODE="$1"
TOTAL_DURATION="$2"
BUILD_STATUS="$3"
TYPE_STATUS="$4"
LINT_STATUS="$5"
TEST_STATUS="$6"
SECURITY_STATUS="$7"
DIFF_STATUS="$8"
PR_READY="$9"

LOG_DIR=".orchestra/logs"

# 상태 아이콘 함수
status_icon() {
  case "$1" in
    pass) echo "✅" ;;
    fail) echo "❌" ;;
    warn) echo "⚠️" ;;
    skip) echo "⏭️" ;;
    *) echo "❓" ;;
  esac
}

# 상태 텍스트 함수
status_text() {
  case "$1" in
    pass) echo "PASS" ;;
    fail) echo "FAIL" ;;
    warn) echo "WARN" ;;
    skip) echo "SKIP" ;;
    *) echo "N/A" ;;
  esac
}

# Duration 포맷 (ms → s)
format_duration() {
  local ms="$1"
  if [ -z "$ms" ] || [ "$ms" = "0" ]; then
    echo "-"
  else
    printf "%.1fs" "$(echo "scale=1; $ms / 1000" | bc 2>/dev/null || echo "0")"
  fi
}

# 추가 정보 로드
TEST_COVERAGE="-"
TEST_PASSED=0
TEST_FAILED=0
LINT_ERRORS=0
LINT_WARNINGS=0
SECURITY_ISSUES=0
FILES_CHANGED=0

if command -v jq &> /dev/null; then
  if [ -f "$LOG_DIR/verification-tests.json" ]; then
    TEST_COVERAGE=$(jq '.coverage.lines // 0' "$LOG_DIR/verification-tests.json")
    TEST_PASSED=$(jq '.passed // 0' "$LOG_DIR/verification-tests.json")
    TEST_FAILED=$(jq '.failed // 0' "$LOG_DIR/verification-tests.json")
  fi

  if [ -f "$LOG_DIR/verification-lint.json" ]; then
    LINT_ERRORS=$(jq '.errors // 0' "$LOG_DIR/verification-lint.json")
    LINT_WARNINGS=$(jq '.warnings // 0' "$LOG_DIR/verification-lint.json")
  fi

  if [ -f "$LOG_DIR/verification-security.json" ]; then
    SECURITY_ISSUES=$(jq '.issueCount // 0' "$LOG_DIR/verification-security.json")
  fi

  if [ -f "$LOG_DIR/verification-diff.json" ]; then
    FILES_CHANGED=$(jq '.filesChanged // 0' "$LOG_DIR/verification-diff.json")
  fi
fi

# 리포트 출력
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   VERIFICATION REPORT                          ║"
echo "║                   Mode: $MODE | $(date '+%Y-%m-%d %H:%M:%S')            "
echo "╠═══════════════════════════════════════════════════════════════╣"

# Build
BUILD_ICON=$(status_icon "$BUILD_STATUS")
BUILD_TEXT=$(status_text "$BUILD_STATUS")
printf "║  Phase 1: Build         %s %-4s                              ║\n" "$BUILD_ICON" "$BUILD_TEXT"

# Types
TYPE_ICON=$(status_icon "$TYPE_STATUS")
TYPE_TEXT=$(status_text "$TYPE_STATUS")
printf "║  Phase 2: Type Check    %s %-4s                              ║\n" "$TYPE_ICON" "$TYPE_TEXT"

# Lint
LINT_ICON=$(status_icon "$LINT_STATUS")
LINT_TEXT=$(status_text "$LINT_STATUS")
if [ "$LINT_ERRORS" -gt 0 ] || [ "$LINT_WARNINGS" -gt 0 ]; then
  printf "║  Phase 3: Lint          %s %-4s  (%d err, %d warn)           ║\n" "$LINT_ICON" "$LINT_TEXT" "$LINT_ERRORS" "$LINT_WARNINGS"
else
  printf "║  Phase 3: Lint          %s %-4s                              ║\n" "$LINT_ICON" "$LINT_TEXT"
fi

# Tests
TEST_ICON=$(status_icon "$TEST_STATUS")
TEST_TEXT=$(status_text "$TEST_STATUS")
if [ "$TEST_PASSED" -gt 0 ] || [ "$TEST_FAILED" -gt 0 ]; then
  TOTAL_TESTS=$((TEST_PASSED + TEST_FAILED))
  printf "║  Phase 4: Tests         %s %-4s  (%d/%d passed)             ║\n" "$TEST_ICON" "$TEST_TEXT" "$TEST_PASSED" "$TOTAL_TESTS"
  if [ "$TEST_COVERAGE" != "-" ] && [ "$TEST_COVERAGE" != "0" ]; then
    printf "║           Coverage      %s %.1f%%                            ║\n" "$(status_icon pass)" "$TEST_COVERAGE"
  fi
else
  printf "║  Phase 4: Tests         %s %-4s                              ║\n" "$TEST_ICON" "$TEST_TEXT"
fi

# Security
SECURITY_ICON=$(status_icon "$SECURITY_STATUS")
SECURITY_TEXT=$(status_text "$SECURITY_STATUS")
if [ "$SECURITY_ISSUES" -gt 0 ]; then
  printf "║  Phase 5: Security      %s %-4s  (%d issues)                ║\n" "$SECURITY_ICON" "$SECURITY_TEXT" "$SECURITY_ISSUES"
else
  printf "║  Phase 5: Security      %s %-4s                              ║\n" "$SECURITY_ICON" "$SECURITY_TEXT"
fi

# Diff
DIFF_ICON=$(status_icon "$DIFF_STATUS")
DIFF_TEXT=$(status_text "$DIFF_STATUS")
if [ "$FILES_CHANGED" -gt 0 ]; then
  printf "║  Phase 6: Diff Review   %s %-4s  (%d files)                 ║\n" "$DIFF_ICON" "$DIFF_TEXT" "$FILES_CHANGED"
else
  printf "║  Phase 6: Diff Review   %s %-4s                              ║\n" "$DIFF_ICON" "$DIFF_TEXT"
fi

echo "╠═══════════════════════════════════════════════════════════════╣"

# Total Duration
TOTAL_SECONDS=$(format_duration "$TOTAL_DURATION")
printf "║  Total Duration: %-10s                                    ║\n" "$TOTAL_SECONDS"

# PR Ready
if [ "$PR_READY" = "true" ]; then
  echo "║  PR Ready: ✅ YES                                             ║"
else
  echo "║  PR Ready: ❌ NO                                              ║"
fi

echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# 결과를 JSON 파일로도 저장
if command -v jq &> /dev/null; then
  cat > "$LOG_DIR/verification-summary.json" << EOF
{
  "mode": "$MODE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration": $TOTAL_DURATION,
  "results": {
    "build": "$BUILD_STATUS",
    "types": "$TYPE_STATUS",
    "lint": "$LINT_STATUS",
    "tests": "$TEST_STATUS",
    "security": "$SECURITY_STATUS",
    "diff": "$DIFF_STATUS"
  },
  "metrics": {
    "testsPassed": $TEST_PASSED,
    "testsFailed": $TEST_FAILED,
    "coverage": $TEST_COVERAGE,
    "lintErrors": $LINT_ERRORS,
    "lintWarnings": $LINT_WARNINGS,
    "securityIssues": $SECURITY_ISSUES,
    "filesChanged": $FILES_CHANGED
  },
  "prReady": $( [ "$PR_READY" = "true" ] && echo "true" || echo "false" )
}
EOF
fi
