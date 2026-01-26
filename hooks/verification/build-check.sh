#!/bin/bash
# Phase 1: Build Verification
# 프로젝트 빌드를 검증합니다.

set -e

RESULT_FILE="${1:-.orchestra/logs/verification-build.json}"

# 시작 시간
START_TIME=$(date +%s%3N)

# 결과 초기화
STATUS="pass"
ERROR_MESSAGE=""
OUTPUT=""

# 패키지 매니저 감지
detect_package_manager() {
  if [ -f "bun.lockb" ]; then
    echo "bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "yarn.lock" ]; then
    echo "yarn"
  elif [ -f "package-lock.json" ]; then
    echo "npm"
  else
    echo "npm"
  fi
}

PM=$(detect_package_manager)

# 빌드 명령어 확인
get_build_command() {
  if [ -f "package.json" ]; then
    # build 스크립트가 있는지 확인
    if grep -q '"build"' package.json; then
      echo "$PM run build"
    elif [ -f "tsconfig.json" ]; then
      echo "npx tsc --noEmit"
    else
      echo ""
    fi
  elif [ -f "Cargo.toml" ]; then
    echo "cargo build"
  elif [ -f "go.mod" ]; then
    echo "go build ./..."
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    echo "python -m py_compile *.py"
  else
    echo ""
  fi
}

BUILD_CMD=$(get_build_command)

if [ -z "$BUILD_CMD" ]; then
  STATUS="skip"
  OUTPUT="No build configuration found"
else
  echo "🔨 Running build check: $BUILD_CMD"

  # 빌드 실행
  if OUTPUT=$(eval "$BUILD_CMD" 2>&1); then
    STATUS="pass"
    echo "✅ Build passed"
  else
    STATUS="fail"
    ERROR_MESSAGE="$OUTPUT"
    echo "❌ Build failed"
    echo "$OUTPUT"
  fi
fi

# 종료 시간 및 duration 계산
END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

# 결과 JSON 생성
mkdir -p "$(dirname "$RESULT_FILE")"
cat > "$RESULT_FILE" << EOF
{
  "phase": "build",
  "status": "$STATUS",
  "duration": $DURATION,
  "command": "$BUILD_CMD",
  "errorMessage": $(echo "$ERROR_MESSAGE" | head -c 1000 | jq -Rs .),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# 실패 시 종료 코드 1
if [ "$STATUS" = "fail" ]; then
  exit 1
fi

exit 0
