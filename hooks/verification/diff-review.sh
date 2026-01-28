#!/bin/bash
# Phase 6: Diff Review
# 변경사항을 검토합니다.

set -e

# macOS/Linux 호환 밀리초 타임스탬프
now_ms() {
  python3 -c "import time; print(int(time.time()*1000))"
}

RESULT_FILE="${1:-.orchestra/logs/verification-diff.json}"
EXPECTED_FILES="${2:-}"  # 예상되는 변경 파일 목록 (쉼표 구분)

# 시작 시간
START_TIME=$(now_ms)

# 결과 초기화
STATUS="pass"
FILES_CHANGED=0
UNEXPECTED_CHANGES=()

echo "📋 Running diff review..."

# Git 상태 확인
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "⏭️ Not a git repository, skipping diff review"
  STATUS="skip"
else
  # 변경된 파일 목록
  CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only)
  STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)

  # 모든 변경 파일
  ALL_CHANGED=$(echo -e "$CHANGED_FILES\n$STAGED_FILES" | sort -u | grep -v "^$" || true)

  if [ -n "$ALL_CHANGED" ]; then
    FILES_CHANGED=$(echo "$ALL_CHANGED" | wc -l | tr -d ' ')

    echo "   Changed files: $FILES_CHANGED"
    echo "$ALL_CHANGED" | while read -r file; do
      echo "   - $file"
    done

    # 예상 파일 목록이 주어진 경우 비교
    if [ -n "$EXPECTED_FILES" ]; then
      IFS=',' read -ra EXPECTED_ARRAY <<< "$EXPECTED_FILES"

      while IFS= read -r changed_file; do
        if [ -z "$changed_file" ]; then
          continue
        fi

        # 자동 생성 파일 제외
        if [[ "$changed_file" == *"lock"* ]] || \
           [[ "$changed_file" == *".log"* ]] || \
           [[ "$changed_file" == "coverage/"* ]] || \
           [[ "$changed_file" == "dist/"* ]] || \
           [[ "$changed_file" == "node_modules/"* ]] || \
           [[ "$changed_file" == ".orchestra/logs/"* ]]; then
          continue
        fi

        # 예상 목록에 있는지 확인
        FOUND=false
        for expected in "${EXPECTED_ARRAY[@]}"; do
          # 와일드카드 지원
          if [[ "$changed_file" == $expected ]] || [[ "$changed_file" == *"$expected"* ]]; then
            FOUND=true
            break
          fi
        done

        if [ "$FOUND" = false ]; then
          UNEXPECTED_CHANGES+=("$changed_file")
        fi
      done <<< "$ALL_CHANGED"

      if [ ${#UNEXPECTED_CHANGES[@]} -gt 0 ]; then
        STATUS="warn"
        echo ""
        echo "   ⚠️ Unexpected changes detected:"
        for file in "${UNEXPECTED_CHANGES[@]}"; do
          echo "      - $file"
        done
      fi
    fi

    # 대규모 변경 경고
    if [ "$FILES_CHANGED" -gt 20 ]; then
      echo ""
      echo "   ⚠️ Large change set: $FILES_CHANGED files"
      STATUS="warn"
    fi

    # 변경 통계
    echo ""
    echo "   Change statistics:"
    git diff --stat HEAD 2>/dev/null | tail -1 || true

  else
    echo "   No changes detected"
  fi
fi

# 종료 시간 및 duration 계산
END_TIME=$(now_ms)
DURATION=$((END_TIME - START_TIME))

# Unexpected changes 배열을 JSON 배열로 변환
UNEXPECTED_JSON="["
first=true
for file in "${UNEXPECTED_CHANGES[@]}"; do
  if [ "$first" = true ]; then
    first=false
  else
    UNEXPECTED_JSON+=","
  fi
  UNEXPECTED_JSON+="\"$file\""
done
UNEXPECTED_JSON+="]"

# Changed files 배열을 JSON으로
CHANGED_JSON="["
first=true
while IFS= read -r file; do
  if [ -n "$file" ]; then
    if [ "$first" = true ]; then
      first=false
    else
      CHANGED_JSON+=","
    fi
    CHANGED_JSON+="\"$file\""
  fi
done <<< "$ALL_CHANGED"
CHANGED_JSON+="]"

# 결과 JSON 생성
mkdir -p "$(dirname "$RESULT_FILE")"
cat > "$RESULT_FILE" << EOF
{
  "phase": "diff",
  "status": "$STATUS",
  "duration": $DURATION,
  "filesChanged": $FILES_CHANGED,
  "changedFiles": $CHANGED_JSON,
  "unexpectedChanges": $UNEXPECTED_JSON,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo ""
if [ "$STATUS" = "pass" ]; then
  echo "✅ Diff review passed"
elif [ "$STATUS" = "warn" ]; then
  echo "⚠️ Diff review completed with warnings"
fi

exit 0
