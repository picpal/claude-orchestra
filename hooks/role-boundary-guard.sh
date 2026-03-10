#!/usr/bin/env bash
# Role Boundary Guard Hook
# 에이전트별 도구 사용 경계를 하드 차단합니다.
#
# 현재 차단 대상:
#   - Interviewer: Bash 사용 전면 금지, Read/Grep은 설정/문서만 허용
#   - Research-Team: Bash 읽기전용만 허용
#
# 트리거: PreToolUse/Bash, PreToolUse/Read|Grep (hooks.json에서 등록)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/find-root.sh"
source "$SCRIPT_DIR/stdin-reader.sh"

ensure_orchestra_dirs

LOG_FILE="$ORCHESTRA_LOG_DIR/role-boundary.log"
AGENT_STACK_FILE="$ORCHESTRA_LOG_DIR/.agent-stack"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

get_current_agent_type() {
  if [ -f "$AGENT_STACK_FILE" ]; then
    tail -1 "$AGENT_STACK_FILE" 2>/dev/null | cut -d'|' -f2
  fi
}

# === Interviewer 경계 ===

is_interviewer() {
  local agent="$1"
  local agent_lower
  agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')
  [ "$agent_lower" = "interviewer" ]
}

is_research_team() {
  local agent_lower
  agent_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  [ "$agent_lower" = "research-team" ]
}

# Interviewer가 Read 가능한 파일
is_interviewer_readable() {
  local file_path="$1"

  # 절대경로 → 상대경로 변환
  if [ -n "${ORCHESTRA_ROOT:-}" ] && [[ "$file_path" == "$ORCHESTRA_ROOT"/* ]]; then
    file_path="${file_path#$ORCHESTRA_ROOT/}"
  fi

  # .orchestra/, .claude/ 디렉토리
  if echo "$file_path" | grep -qE '^\.(orchestra|claude)/'; then
    return 0
  fi

  # 프로젝트 루트 설정/문서 파일
  if echo "$file_path" | grep -qE '^(package\.json|tsconfig\.json|README\.md|CLAUDE\.md|\.gitignore)$'; then
    return 0
  fi

  # 마크다운, 설정 파일
  if echo "$file_path" | grep -qE '\.(md|yaml|yml|toml)$'; then
    return 0
  fi

  # 그 외 소스 코드 → 불허
  return 1
}

# === 메인 로직 ===
main() {
  local current_agent
  current_agent=$(get_current_agent_type)

  # 에이전트 스택이 비어있으면 (Main Agent) → 통과
  [ -z "$current_agent" ] && exit 0

  local tool_name="$HOOK_TOOL_NAME"

  # --- Interviewer 차단 ---
  if is_interviewer "$current_agent"; then

    # Bash 전면 금지
    if [ "$tool_name" = "Bash" ]; then
      local cmd
      cmd=$(hook_get_field "tool_input.command")
      log "BLOCKED: Interviewer Bash: $cmd"

      echo ""
      echo "[Role Boundary] Interviewer는 Bash를 사용할 수 없습니다."
      echo ""
      echo "  차단된 명령: ${cmd:0:80}"
      echo ""
      echo "  Interviewer의 역할:"
      echo "    - 사용자 인터뷰 (AskUserQuestion)"
      echo "    - 계획 초안 작성 (Write → .orchestra/plans/)"
      echo "    - 문서/설정 참조 (Read → .md, .yaml, .orchestra/)"
      echo ""
      exit 1
    fi

    # Read/Grep: 소스 코드 차단
    if [ "$tool_name" = "Read" ] || [ "$tool_name" = "Grep" ] || [ "$tool_name" = "Glob" ]; then
      local file_path=""
      if [ "$tool_name" = "Read" ]; then
        file_path=$(hook_get_field "tool_input.file_path")
      elif [ "$tool_name" = "Grep" ]; then
        file_path=$(hook_get_field "tool_input.path")
      elif [ "$tool_name" = "Glob" ]; then
        file_path=$(hook_get_field "tool_input.path")
      fi

      # 경로가 없으면 통과 (기본 디렉토리 Grep 등)
      [ -z "$file_path" ] && exit 0

      if ! is_interviewer_readable "$file_path"; then
        log "BLOCKED: Interviewer Read source: $file_path"

        echo ""
        echo "[Role Boundary] Interviewer는 소스 코드를 읽을 수 없습니다."
        echo ""
        echo "  차단된 파일: $file_path"
        echo ""
        echo "  읽을 수 있는 파일:"
        echo "    - .orchestra/ (계획, 상태)"
        echo "    - *.md, *.yaml (문서, 설정)"
        echo "    - package.json, tsconfig.json"
        echo ""
        echo "  소스 탐색이 필요하면 계획에 명시하세요."
        echo "  Maestro가 Explorer를 호출합니다."
        echo ""
        exit 1
      fi
    fi
  fi

  # --- Research-Team: Bash 읽기전용만 허용 ---
  if is_research_team "$current_agent"; then
    if [ "$tool_name" = "Bash" ]; then
      local cmd
      cmd=$(hook_get_field "tool_input.command")
      if echo "$cmd" | grep -qE '^\s*(cat|ls|find|grep|head|tail|wc|echo|pwd|which|file|stat|git (log|status|diff|show|ls-files))'; then
        exit 0
      fi
      log "BLOCKED: Research-Team non-readonly Bash: $cmd"
      echo "[Role Boundary] Research-Team은 읽기 전용 Bash만 사용할 수 있습니다."
      exit 1
    fi
  fi

  # 다른 에이전트는 통과
  exit 0
}

main
