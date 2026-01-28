#!/bin/bash
# Phase 2: Type Check
# 타입 안전성을 검증합니다.

set -e

# macOS/Linux 호환 밀리초 타임스탬프
now_ms() {
  python3 -c "import time; print(int(time.time()*1000))"
}

RESULT_FILE="${1:-.orchestra/logs/verification-types.json}"

# 시작 시간
START_TIME=$(now_ms)

# 결과 초기화
STATUS="pass"
ERRORS=0
WARNINGS=0
ERROR_LIST=""

# TypeScript 프로젝트 확인
if [ -f "tsconfig.json" ]; then
  echo "🔍 Running TypeScript type check..."

  # tsc 실행
  OUTPUT=$(npx tsc --noEmit 2>&1) || true

  # 에러 카운트
  ERRORS=$(echo "$OUTPUT" | grep -c "error TS" || echo "0")
  WARNINGS=$(echo "$OUTPUT" | grep -c "warning" || echo "0")

  if [ "$ERRORS" -gt 0 ]; then
    STATUS="fail"
    ERROR_LIST="$OUTPUT"
    echo "❌ Type check failed: $ERRORS errors"
    echo "$OUTPUT" | head -20
  else
    echo "✅ Type check passed"
    if [ "$WARNINGS" -gt 0 ]; then
      echo "   ⚠️ $WARNINGS warnings"
    fi
  fi

# Python 타입 체크 (mypy)
elif [ -f "pyproject.toml" ] || [ -f "mypy.ini" ]; then
  if command -v mypy &> /dev/null; then
    echo "🔍 Running mypy type check..."

    OUTPUT=$(mypy . 2>&1) || true
    ERRORS=$(echo "$OUTPUT" | grep -c "error:" || echo "0")

    if [ "$ERRORS" -gt 0 ]; then
      STATUS="fail"
      ERROR_LIST="$OUTPUT"
      echo "❌ Type check failed: $ERRORS errors"
    else
      echo "✅ Type check passed"
    fi
  else
    STATUS="skip"
    echo "⏭️ mypy not installed, skipping"
  fi

# Go 타입 체크
elif [ -f "go.mod" ]; then
  echo "🔍 Running Go vet..."

  OUTPUT=$(go vet ./... 2>&1) || true
  ERRORS=$(echo "$OUTPUT" | grep -c "." || echo "0")

  if [ -n "$OUTPUT" ]; then
    STATUS="fail"
    ERROR_LIST="$OUTPUT"
    echo "❌ Go vet failed"
  else
    STATUS="pass"
    echo "✅ Go vet passed"
  fi

else
  STATUS="skip"
  echo "⏭️ No type checking configuration found"
fi

# 종료 시간 및 duration 계산
END_TIME=$(now_ms)
DURATION=$((END_TIME - START_TIME))

# 결과 JSON 생성
mkdir -p "$(dirname "$RESULT_FILE")"
cat > "$RESULT_FILE" << EOF
{
  "phase": "types",
  "status": "$STATUS",
  "duration": $DURATION,
  "errors": $ERRORS,
  "warnings": $WARNINGS,
  "errorList": $(echo "$ERROR_LIST" | head -c 2000 | jq -Rs .),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# 실패 시 종료 코드 1
if [ "$STATUS" = "fail" ]; then
  exit 1
fi

exit 0
