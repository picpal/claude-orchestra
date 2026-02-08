#!/bin/bash
# Journal 작성 감지 및 상태 자동 업데이트
# PostToolUse/Write hook으로 Journal 작성을 감지하고 상태를 업데이트합니다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

FILE_PATH=$(hook_get_field "tool_input.file_path")
STATE_FILE="$ORCHESTRA_STATE_FILE"

# .orchestra/journal/ 경로 감지 (YYYYMMDD 포함 형식: *-YYYYMMDD.md 또는 *-YYYYMMDD-HHmm.md)
# 상대 경로 또는 절대 경로 모두 지원
if echo "$FILE_PATH" | grep -qE '(^|/)\.orchestra/journal/.*-[0-9]{8}(-[0-9]{4})?\.md$'; then
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    jq --arg path "$FILE_PATH" \
       '.workflowStatus.journalWritten = true |
        .workflowStatus.lastJournalPath = $path |
        .mode = "IDLE"' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo "[Orchestra] Journal 리포트 작성 완료: $FILE_PATH"
    echo "[Orchestra] Mode 전환: EXECUTE -> IDLE"
  fi
fi
