#!/bin/bash
# Phase 5: Security Scan
# 보안 취약점을 스캔합니다.

set -e

# macOS/Linux 호환 밀리초 타임스탬프
now_ms() {
  python3 -c "import time; print(int(time.time()*1000))"
}

RESULT_FILE="${1:-.orchestra/logs/verification-security.json}"

# 시작 시간
START_TIME=$(now_ms)

# 결과 초기화
STATUS="pass"
ISSUES=()
ISSUE_COUNT=0

# 검사할 디렉토리
SCAN_DIRS="src lib app"
SCAN_EXTENSIONS="ts tsx js jsx py go rs"

# 실제 존재하는 디렉토리 찾기
EXISTING_DIRS=""
for dir in $SCAN_DIRS; do
  if [ -d "$dir" ]; then
    EXISTING_DIRS="$EXISTING_DIRS $dir"
  fi
done

# 디렉토리가 없으면 현재 디렉토리
if [ -z "$EXISTING_DIRS" ]; then
  EXISTING_DIRS="."
fi

echo "🔒 Running security scan..."

# 1. 하드코딩된 API 키 검사
echo "   Checking for hardcoded API keys..."
API_KEY_PATTERN='(API_KEY|api_key|apiKey|API_SECRET|api_secret)\s*[=:]\s*["\x27][^"\x27]{10,}["\x27]'
API_KEY_RESULTS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
  -E "$API_KEY_PATTERN" $EXISTING_DIRS 2>/dev/null || true)

if [ -n "$API_KEY_RESULTS" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      ISSUES+=("{\"type\": \"hardcoded_api_key\", \"location\": \"$(echo "$line" | cut -d: -f1-2)\", \"severity\": \"critical\"}")
      ISSUE_COUNT=$((ISSUE_COUNT + 1))
    fi
  done <<< "$API_KEY_RESULTS"
  echo "   ⚠️ Found potential hardcoded API keys"
fi

# 2. OpenAI/Anthropic 키 패턴
echo "   Checking for AI service keys..."
AI_KEY_PATTERN='(sk-[A-Za-z0-9]{20,}|anthropic-[A-Za-z0-9]{20,})'
AI_KEY_RESULTS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  -E "$AI_KEY_PATTERN" $EXISTING_DIRS 2>/dev/null || true)

if [ -n "$AI_KEY_RESULTS" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      ISSUES+=("{\"type\": \"ai_service_key\", \"location\": \"$(echo "$line" | cut -d: -f1-2)\", \"severity\": \"critical\"}")
      ISSUE_COUNT=$((ISSUE_COUNT + 1))
    fi
  done <<< "$AI_KEY_RESULTS"
  echo "   ⚠️ Found potential AI service keys"
fi

# 3. 비밀번호 하드코딩
echo "   Checking for hardcoded passwords..."
PASSWORD_PATTERN='(password|passwd|pwd)\s*[=:]\s*["\x27][^"\x27]+["\x27]'
PASSWORD_RESULTS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
  -E "$PASSWORD_PATTERN" $EXISTING_DIRS 2>/dev/null | grep -v "test" | grep -v "spec" | grep -v "mock" || true)

if [ -n "$PASSWORD_RESULTS" ]; then
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      ISSUES+=("{\"type\": \"hardcoded_password\", \"location\": \"$(echo "$line" | cut -d: -f1-2)\", \"severity\": \"critical\"}")
      ISSUE_COUNT=$((ISSUE_COUNT + 1))
    fi
  done <<< "$PASSWORD_RESULTS"
  echo "   ⚠️ Found potential hardcoded passwords"
fi

# 4. console.log / debugger 검사 (프로덕션 코드만)
echo "   Checking for debug statements..."
DEBUG_PATTERN='console\.(log|debug)\(|debugger;'
DEBUG_RESULTS=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  -E "$DEBUG_PATTERN" $EXISTING_DIRS 2>/dev/null | grep -v "test" | grep -v "spec" | grep -v "__tests__" || true)

if [ -n "$DEBUG_RESULTS" ]; then
  DEBUG_COUNT=$(echo "$DEBUG_RESULTS" | wc -l | tr -d ' ')
  if [ "$DEBUG_COUNT" -gt 0 ]; then
    ISSUES+=("{\"type\": \"debug_statement\", \"count\": $DEBUG_COUNT, \"severity\": \"low\"}")
    echo "   ⚠️ Found $DEBUG_COUNT debug statements"
  fi
fi

# 5. .env 파일 스테이징 확인
echo "   Checking for staged sensitive files..."
if git diff --cached --name-only 2>/dev/null | grep -qE "\.env|credentials|secret"; then
  ISSUES+=("{\"type\": \"sensitive_file_staged\", \"severity\": \"critical\"}")
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
  echo "   ⚠️ Sensitive file is staged for commit"
fi

# 6. Private key 파일 확인
echo "   Checking for private key files..."
KEY_FILES=$(find $EXISTING_DIRS -name "*.pem" -o -name "*.key" -o -name "*_rsa" 2>/dev/null || true)
if [ -n "$KEY_FILES" ]; then
  while IFS= read -r file; do
    if [ -n "$file" ]; then
      ISSUES+=("{\"type\": \"private_key_file\", \"file\": \"$file\", \"severity\": \"high\"}")
      ISSUE_COUNT=$((ISSUE_COUNT + 1))
    fi
  done <<< "$KEY_FILES"
  echo "   ⚠️ Found private key files"
fi

# 상태 결정
CRITICAL_COUNT=$(printf '%s\n' "${ISSUES[@]}" | grep -c '"critical"' || echo "0")
if [ "$CRITICAL_COUNT" -gt 0 ]; then
  STATUS="fail"
  echo "❌ Security scan failed: $CRITICAL_COUNT critical issues"
elif [ "$ISSUE_COUNT" -gt 0 ]; then
  STATUS="warn"
  echo "⚠️ Security scan completed with $ISSUE_COUNT warnings"
else
  echo "✅ Security scan passed"
fi

# 종료 시간 및 duration 계산
END_TIME=$(now_ms)
DURATION=$((END_TIME - START_TIME))

# Issues 배열을 JSON 배열로 변환
ISSUES_JSON="["
first=true
for issue in "${ISSUES[@]}"; do
  if [ "$first" = true ]; then
    first=false
  else
    ISSUES_JSON+=","
  fi
  ISSUES_JSON+="$issue"
done
ISSUES_JSON+="]"

# 결과 JSON 생성
mkdir -p "$(dirname "$RESULT_FILE")"
cat > "$RESULT_FILE" << EOF
{
  "phase": "security",
  "status": "$STATUS",
  "duration": $DURATION,
  "issueCount": $ISSUE_COUNT,
  "criticalCount": $CRITICAL_COUNT,
  "issues": $ISSUES_JSON,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# 크리티컬 이슈 시 종료 코드 1
if [ "$STATUS" = "fail" ]; then
  exit 1
fi

exit 0
