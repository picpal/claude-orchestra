#!/bin/bash
# Git Push Review Hook
# git push 전 안전성 검토 (Force push 차단, 미검증 경고)
# Hook: PreToolUse (Bash matcher)
#
# 차단 조건: Protected branch에 force push만 차단 (exit 1)
# 나머지는 경고만 출력 (exit 0) — 기존 워크플로우 영향 없음

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

# git push 명령인지 확인 (아니면 즉시 종료)
COMMAND=$(hook_get_field "tool_input.command")
if ! echo "$COMMAND" | grep -qE 'git\s+push'; then
  exit 0
fi

ensure_orchestra_dirs

LOG_FILE="$ORCHESTRA_LOG_DIR/git-push-review.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Git push detected: $COMMAND"

# force push 확인
is_force_push() {
  echo "$COMMAND" | grep -qE '(\s-f\s|\s--force\s|--force-with-lease)'
}

# main/master 브랜치 확인
is_protected_branch() {
  local current_branch
  current_branch=$(git branch --show-current 2>/dev/null || echo "")

  if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
    return 0
  fi

  if echo "$COMMAND" | grep -qE 'origin\s+(main|master)'; then
    return 0
  fi

  return 1
}

# === 유일한 Hard Block: Protected branch에 force push ===
if is_force_push && is_protected_branch; then
  echo ""
  echo "❌ [Orchestra] Force push to protected branch (main/master) is BLOCKED!"
  echo ""
  log "BLOCKED: Force push to protected branch"
  exit 1
fi

# === 이하 경고만 (exit 0) ===

# Force push 경고
if is_force_push; then
  echo ""
  echo "⚠️ [Orchestra] Force push detected — 히스토리를 덮어쓸 수 있습니다."
  echo ""
  log "WARNING: Force push detected"
fi

# Protected branch 직접 push 경고
if is_protected_branch; then
  echo ""
  echo "⚠️ [Orchestra] main/master 브랜치에 직접 push — PR을 통한 merge를 권장합니다."
  echo ""
  log "WARNING: Direct push to protected branch"
fi

# 미커밋 변경사항 경고
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo "⚠️ [Orchestra] Uncommitted changes detected — push 전 커밋하세요."
  log "WARNING: Uncommitted changes"
fi

# 검증 상태 경고
if [ -f "$ORCHESTRA_STATE_FILE" ] && command -v jq &> /dev/null; then
  PR_READY=$(jq -r '.verificationMetrics.prReady // "unknown"' "$ORCHESTRA_STATE_FILE" 2>/dev/null || echo "unknown")
  if [ "$PR_READY" = "false" ]; then
    echo "⚠️ [Orchestra] Verification 미완료 — /verify 실행을 권장합니다."
    log "WARNING: Not verified"
  fi
fi

log "Git push review passed (warnings only)"
exit 0
