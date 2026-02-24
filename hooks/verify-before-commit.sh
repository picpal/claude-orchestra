#!/usr/bin/env bash
# verify-before-commit.sh
# PreToolUse/Bash hook: Blocks git commit if Code-Review is not completed.
#
# This is the most impactful hook addition - it prevents skipping Code-Review.
#
# Logic:
#   1. Detect git commit command
#   2. Check state.json for codeReviewCompleted
#   3. If false → exit 1 (BLOCK)
#   4. Exception: all changed files are non-code (.md, .json) → pass

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

# Only intercept Bash tool calls
COMMAND=$(hook_get_field "tool_input.command")
[ -z "$COMMAND" ] && exit 0

# Only check git commit commands
case "$COMMAND" in
  *"git commit"*|*"git -c"*"commit"*) ;;
  *) exit 0 ;;
esac

# Skip if no orchestra state file
STATE_FILE="$ORCHESTRA_STATE_FILE"
[ -f "$STATE_FILE" ] || exit 0

# Check if all changed files are non-code (docs/config only)
NON_CODE_ONLY=$(python3 -c "
import subprocess, sys
try:
    result = subprocess.run(['git', 'diff', '--cached', '--name-only'], capture_output=True, text=True)
    files = [f.strip() for f in result.stdout.strip().split('\n') if f.strip()]
    if not files:
        # No staged files, check unstaged
        result = subprocess.run(['git', 'diff', '--name-only'], capture_output=True, text=True)
        files = [f.strip() for f in result.stdout.strip().split('\n') if f.strip()]
    non_code_exts = {'.md', '.json', '.yaml', '.yml', '.toml', '.txt', '.cfg', '.ini', '.env.example'}
    all_non_code = all(
        any(f.endswith(ext) for ext in non_code_exts)
        for f in files
    ) if files else True
    print('true' if all_non_code else 'false')
except Exception:
    print('false')
" 2>/dev/null)

# If all files are non-code, skip the check
if [ "$NON_CODE_ONLY" = "true" ]; then
  exit 0
fi

# Check codeReviewCompleted in state.json
CR_COMPLETED=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        d = json.load(f)
    print('true' if d.get('codeReviewCompleted', False) else 'false')
except Exception:
    print('false')
" "$STATE_FILE" 2>/dev/null)

if [ "$CR_COMPLETED" != "true" ]; then
  echo "⛔ [verify-before-commit] Code-Review Team 실행이 필요합니다."
  echo "   /code-review 또는 /verify 명령어를 먼저 실행하세요."
  echo "   (Verification 통과 후 Code-Review Team 5명 병렬 실행 필요)"
  echo ""
  echo "   비코드 파일만 커밋하려면 .md/.json 파일만 스테이징하세요."
  exit 1
fi

exit 0
