#!/bin/bash
# Phase 3: Lint Check
# 코드 스타일을 검사합니다.

set -e

RESULT_FILE="${1:-.orchestra/logs/verification-lint.json}"

# 시작 시간
START_TIME=$(date +%s%3N)

# 결과 초기화
STATUS="pass"
ERRORS=0
WARNINGS=0
OUTPUT=""

# ESLint 확인
if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
  echo "🔍 Running ESLint..."

  # ESLint 실행 (JSON 출력)
  LINT_OUTPUT=$(npx eslint . --format json 2>/dev/null) || true

  # 에러/경고 카운트
  if command -v jq &> /dev/null && [ -n "$LINT_OUTPUT" ]; then
    ERRORS=$(echo "$LINT_OUTPUT" | jq '[.[].errorCount] | add // 0')
    WARNINGS=$(echo "$LINT_OUTPUT" | jq '[.[].warningCount] | add // 0')
  else
    # jq 없으면 텍스트 출력으로 카운트
    TEXT_OUTPUT=$(npx eslint . 2>&1) || true
    ERRORS=$(echo "$TEXT_OUTPUT" | grep -c "error" || echo "0")
    WARNINGS=$(echo "$TEXT_OUTPUT" | grep -c "warning" || echo "0")
  fi

  if [ "$ERRORS" -gt 0 ]; then
    STATUS="fail"
    OUTPUT=$(npx eslint . 2>&1 | head -50) || true
    echo "❌ Lint check failed: $ERRORS errors, $WARNINGS warnings"
  elif [ "$WARNINGS" -gt 0 ]; then
    STATUS="warn"
    OUTPUT=$(npx eslint . 2>&1 | head -30) || true
    echo "⚠️ Lint check passed with $WARNINGS warnings"
  else
    echo "✅ Lint check passed"
  fi

# Biome 확인
elif [ -f "biome.json" ]; then
  echo "🔍 Running Biome..."

  OUTPUT=$(npx biome lint . 2>&1) || true
  ERRORS=$(echo "$OUTPUT" | grep -c "error" || echo "0")
  WARNINGS=$(echo "$OUTPUT" | grep -c "warning" || echo "0")

  if [ "$ERRORS" -gt 0 ]; then
    STATUS="fail"
    echo "❌ Biome lint failed: $ERRORS errors"
  else
    STATUS="pass"
    echo "✅ Biome lint passed"
  fi

# Python (ruff/flake8/pylint)
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  if command -v ruff &> /dev/null; then
    echo "🔍 Running Ruff..."
    OUTPUT=$(ruff check . 2>&1) || true
    ERRORS=$(echo "$OUTPUT" | grep -cE "^[^ ]" || echo "0")
  elif command -v flake8 &> /dev/null; then
    echo "🔍 Running Flake8..."
    OUTPUT=$(flake8 . 2>&1) || true
    ERRORS=$(echo "$OUTPUT" | wc -l)
  else
    STATUS="skip"
    echo "⏭️ No Python linter found"
  fi

  if [ "$STATUS" != "skip" ]; then
    if [ "$ERRORS" -gt 0 ]; then
      STATUS="fail"
      echo "❌ Lint failed: $ERRORS issues"
    else
      STATUS="pass"
      echo "✅ Lint passed"
    fi
  fi

# Go
elif [ -f "go.mod" ]; then
  if command -v golangci-lint &> /dev/null; then
    echo "🔍 Running golangci-lint..."
    OUTPUT=$(golangci-lint run 2>&1) || true
    ERRORS=$(echo "$OUTPUT" | grep -c "error" || echo "0")

    if [ "$ERRORS" -gt 0 ]; then
      STATUS="fail"
    else
      STATUS="pass"
      echo "✅ Lint passed"
    fi
  else
    STATUS="skip"
    echo "⏭️ golangci-lint not installed"
  fi

else
  STATUS="skip"
  echo "⏭️ No lint configuration found"
fi

# 종료 시간 및 duration 계산
END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

# 결과 JSON 생성
mkdir -p "$(dirname "$RESULT_FILE")"
cat > "$RESULT_FILE" << EOF
{
  "phase": "lint",
  "status": "$STATUS",
  "duration": $DURATION,
  "errors": $ERRORS,
  "warnings": $WARNINGS,
  "output": $(echo "$OUTPUT" | head -c 2000 | jq -Rs .),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# 에러 시 종료 코드 1
if [ "$STATUS" = "fail" ]; then
  exit 1
fi

exit 0
