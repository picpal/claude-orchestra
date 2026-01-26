#!/bin/bash
# Git Push Review Hook
# push 전에 검토를 수행합니다.
# PreToolUse Hook (Bash 매처, git push 패턴)

set -e

TOOL_INPUT="$1"
STATE_FILE=".orchestra/state.json"
LOG_FILE=".orchestra/logs/git-push-review.log"

# 로그 디렉토리 확인
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# git push 명령인지 확인
is_git_push() {
  echo "$TOOL_INPUT" | grep -qE '"command"\s*:\s*"[^"]*git\s+push'
}

# force push 확인
is_force_push() {
  echo "$TOOL_INPUT" | grep -qE '(-f|--force|--force-with-lease)'
}

# main/master 브랜치 확인
is_protected_branch() {
  local current_branch=$(git branch --show-current 2>/dev/null || echo "")

  if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
    return 0
  fi

  # push 대상 브랜치 확인
  if echo "$TOOL_INPUT" | grep -qE 'origin\s+(main|master)'; then
    return 0
  fi

  return 1
}

# 검증 상태 확인
check_verification_status() {
  if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
    local pr_ready=$(jq -r '.verificationMetrics.prReady // false' "$STATE_FILE")
    local last_run=$(jq -r '.verificationMetrics.lastRun // null' "$STATE_FILE")

    if [ "$pr_ready" != "true" ]; then
      return 1
    fi

    # 마지막 검증이 1시간 이내인지 확인
    if [ "$last_run" != "null" ]; then
      local last_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_run" +%s 2>/dev/null || echo "0")
      local current_timestamp=$(date +%s)
      local diff=$((current_timestamp - last_timestamp))

      if [ "$diff" -gt 3600 ]; then
        echo "⚠️ 마지막 검증이 1시간 이상 지났습니다. /verify를 실행하세요."
        return 1
      fi
    fi
  fi

  return 0
}

# 미커밋 변경사항 확인
check_uncommitted_changes() {
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    return 1
  fi
  return 0
}

# push 전 체크리스트
run_pre_push_checks() {
  local issues=0

  echo ""
  echo "🔍 Pre-Push Review"
  echo "==================="

  # 1. 미커밋 변경사항
  echo -n "  Uncommitted changes: "
  if check_uncommitted_changes; then
    echo "✅ None"
  else
    echo "⚠️ Found"
    issues=$((issues + 1))
  fi

  # 2. 검증 상태
  echo -n "  Verification status: "
  if check_verification_status; then
    echo "✅ PR Ready"
  else
    echo "❌ Not verified"
    issues=$((issues + 1))
  fi

  # 3. 테스트 실행
  echo -n "  Running quick tests: "
  if npm test --passWithNoTests 2>/dev/null || yarn test --passWithNoTests 2>/dev/null; then
    echo "✅ Passed"
  else
    echo "❌ Failed"
    issues=$((issues + 1))
  fi

  echo ""

  if [ "$issues" -gt 0 ]; then
    return 1
  fi

  return 0
}

# 메인 로직
main() {
  # git push가 아니면 종료
  if ! is_git_push; then
    exit 0
  fi

  log "Git push detected"

  # Force push 경고
  if is_force_push; then
    log "Force push detected"
    echo ""
    echo "⚠️ Force Push Detected!"
    echo ""
    echo "Force push는 히스토리를 덮어쓸 수 있습니다."
    echo "정말 진행하시겠습니까?"
    echo ""

    # Protected branch에 force push 시 차단
    if is_protected_branch; then
      echo "❌ Force push to protected branch (main/master) is blocked!"
      echo ""
      log "Blocked force push to protected branch"
      exit 1
    fi
  fi

  # Protected branch 직접 push 경고
  if is_protected_branch; then
    echo ""
    echo "⚠️ Direct Push to Protected Branch!"
    echo ""
    echo "main/master 브랜치에 직접 push하고 있습니다."
    echo "PR을 통한 merge를 권장합니다."
    echo ""
  fi

  # Pre-push 체크 실행
  if ! run_pre_push_checks; then
    echo "❌ Pre-push checks failed!"
    echo ""
    echo "다음을 확인하세요:"
    echo "  1. 모든 변경사항이 커밋되었는지"
    echo "  2. /verify가 성공했는지"
    echo "  3. 테스트가 통과하는지"
    echo ""
    log "Pre-push checks failed"
    exit 1
  fi

  echo "✅ Pre-push review passed"
  log "Pre-push review passed"
  exit 0
}

main
