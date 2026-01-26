#!/bin/bash
# Phase 4: Test Suite + Coverage
# 테스트를 실행하고 커버리지를 확인합니다.

set -e

RESULT_FILE="${1:-.orchestra/logs/verification-tests.json}"
MIN_COVERAGE="${2:-80}"

# 시작 시간
START_TIME=$(date +%s%3N)

# 결과 초기화
STATUS="pass"
PASSED=0
FAILED=0
SKIPPED=0
COVERAGE_LINES=0
COVERAGE_BRANCHES=0
COVERAGE_FUNCTIONS=0
COVERAGE_STATEMENTS=0
OUTPUT=""

# 패키지 매니저 감지
detect_package_manager() {
  if [ -f "bun.lockb" ]; then
    echo "bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "yarn.lock" ]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

PM=$(detect_package_manager)

# Node.js 프로젝트 (Jest/Vitest)
if [ -f "package.json" ]; then
  # 테스트 스크립트 확인
  if grep -q '"test"' package.json; then
    echo "🧪 Running tests with coverage..."

    # Jest 또는 Vitest
    if grep -q "vitest" package.json; then
      OUTPUT=$($PM run test -- --coverage --reporter=json 2>&1) || true
    else
      OUTPUT=$($PM test -- --coverage --coverageReporters=json-summary --passWithNoTests 2>&1) || true
    fi

    # 결과 파싱 (Jest 형식)
    if echo "$OUTPUT" | grep -q "Tests:"; then
      PASSED=$(echo "$OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1 || echo "0")
      FAILED=$(echo "$OUTPUT" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1 || echo "0")
      SKIPPED=$(echo "$OUTPUT" | grep -oE "[0-9]+ skipped" | grep -oE "[0-9]+" | head -1 || echo "0")
    fi

    # 커버리지 파싱
    if [ -f "coverage/coverage-summary.json" ] && command -v jq &> /dev/null; then
      COVERAGE_LINES=$(jq '.total.lines.pct // 0' coverage/coverage-summary.json)
      COVERAGE_BRANCHES=$(jq '.total.branches.pct // 0' coverage/coverage-summary.json)
      COVERAGE_FUNCTIONS=$(jq '.total.functions.pct // 0' coverage/coverage-summary.json)
      COVERAGE_STATEMENTS=$(jq '.total.statements.pct // 0' coverage/coverage-summary.json)
    fi

    # 상태 결정
    if [ "$FAILED" -gt 0 ]; then
      STATUS="fail"
      echo "❌ Tests failed: $PASSED passed, $FAILED failed"
    else
      echo "✅ Tests passed: $PASSED passed, $SKIPPED skipped"

      # 커버리지 확인
      if [ -n "$COVERAGE_LINES" ] && [ "$COVERAGE_LINES" != "0" ]; then
        COVERAGE_INT=${COVERAGE_LINES%.*}
        if [ "$COVERAGE_INT" -lt "$MIN_COVERAGE" ]; then
          STATUS="fail"
          echo "❌ Coverage below minimum: ${COVERAGE_LINES}% < ${MIN_COVERAGE}%"
        else
          echo "   Coverage: ${COVERAGE_LINES}%"
        fi
      fi
    fi
  else
    STATUS="skip"
    echo "⏭️ No test script found in package.json"
  fi

# Python (pytest)
elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.py" ]; then
  if command -v pytest &> /dev/null; then
    echo "🧪 Running pytest with coverage..."

    OUTPUT=$(pytest --cov=. --cov-report=json -q 2>&1) || true

    # 결과 파싱
    PASSED=$(echo "$OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" || echo "0")
    FAILED=$(echo "$OUTPUT" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" || echo "0")

    # 커버리지 파싱
    if [ -f "coverage.json" ] && command -v jq &> /dev/null; then
      COVERAGE_LINES=$(jq '.totals.percent_covered // 0' coverage.json)
    fi

    if [ "$FAILED" -gt 0 ]; then
      STATUS="fail"
      echo "❌ Tests failed"
    else
      STATUS="pass"
      echo "✅ Tests passed"
    fi
  else
    STATUS="skip"
    echo "⏭️ pytest not installed"
  fi

# Go
elif [ -f "go.mod" ]; then
  echo "🧪 Running go test with coverage..."

  OUTPUT=$(go test -cover ./... 2>&1) || true

  if echo "$OUTPUT" | grep -q "FAIL"; then
    STATUS="fail"
    FAILED=1
    echo "❌ Tests failed"
  else
    STATUS="pass"
    # 커버리지 추출
    COVERAGE_LINES=$(echo "$OUTPUT" | grep -oE "coverage: [0-9.]+" | grep -oE "[0-9.]+" | head -1 || echo "0")
    echo "✅ Tests passed (Coverage: ${COVERAGE_LINES}%)"
  fi

# Rust
elif [ -f "Cargo.toml" ]; then
  echo "🧪 Running cargo test..."

  OUTPUT=$(cargo test 2>&1) || true

  if echo "$OUTPUT" | grep -q "FAILED"; then
    STATUS="fail"
    echo "❌ Tests failed"
  else
    STATUS="pass"
    PASSED=$(echo "$OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" || echo "0")
    echo "✅ Tests passed: $PASSED"
  fi

else
  STATUS="skip"
  echo "⏭️ No test configuration found"
fi

# 종료 시간 및 duration 계산
END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

# 결과 JSON 생성
mkdir -p "$(dirname "$RESULT_FILE")"
cat > "$RESULT_FILE" << EOF
{
  "phase": "tests",
  "status": "$STATUS",
  "duration": $DURATION,
  "passed": $PASSED,
  "failed": $FAILED,
  "skipped": $SKIPPED,
  "coverage": {
    "lines": ${COVERAGE_LINES:-0},
    "branches": ${COVERAGE_BRANCHES:-0},
    "functions": ${COVERAGE_FUNCTIONS:-0},
    "statements": ${COVERAGE_STATEMENTS:-0}
  },
  "minCoverage": $MIN_COVERAGE,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# 실패 시 종료 코드 1
if [ "$STATUS" = "fail" ]; then
  exit 1
fi

exit 0
