#!/usr/bin/env bash
# Orchestra UserPromptSubmit Hook
# 매 사용자 요청마다 프로토콜과 상태를 Claude에게 주입

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCHESTRA_DIR=".orchestra"

# 슬래시 커맨드 감지 및 활동 로그 기록
if [ -n "${PROMPT:-}" ]; then
  CMD_NAME=$(echo "$PROMPT" | grep -oE '^/[a-zA-Z0-9_-]+' || true)
  if [ -n "$CMD_NAME" ]; then
    # 슬래시 명령어별 PHASE 매핑
    case "$CMD_NAME" in
      /verify)       CMD_PHASE="VERIFY" ;;
      /code-review)  CMD_PHASE="REVIEW" ;;
      /start-work)   CMD_PHASE="PLAN" ;;
      /tdd-cycle)    CMD_PHASE="EXECUTE" ;;
      /learn)        CMD_PHASE="RESEARCH" ;;
      *)             CMD_PHASE="-" ;;
    esac
    "$SCRIPT_DIR/activity-logger.sh" COMMAND "$CMD_NAME" "" "$CMD_PHASE" 2>/dev/null || true
  fi
fi
STATE_FILE="$ORCHESTRA_DIR/state.json"

# 기본값
MODE="IDLE"
CONTEXT="dev"
PLAN_INFO=""
TODO_INFO=""

# .orchestra/state.json 읽기 (있을 때만)
if [ -f "$STATE_FILE" ]; then
  MODE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('mode','IDLE'))" 2>/dev/null || echo "IDLE")
  CONTEXT=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('currentContext','dev'))" 2>/dev/null || echo "dev")

  # 활성 계획 확인
  CURRENT_PLAN=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('currentPlan','') or '')" 2>/dev/null || echo "")
  if [ -n "$CURRENT_PLAN" ]; then
    PLAN_INFO="- active-plan: $CURRENT_PLAN"
  fi

  # TODO 진행률
  TOTAL=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(len(d.get('todos',[])))" 2>/dev/null || echo "0")
  if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
    DONE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(sum(1 for t in d.get('todos',[]) if t.get('status')=='done'))" 2>/dev/null || echo "0")
    TODO_INFO="- progress: $DONE/$TOTAL TODOs"
  fi
fi

# 출력: 모드에 따라 분기
if [ "$MODE" = "EXECUTE" ]; then
  # EXECUTE 모드: 간소화된 실행 지시 (Planner가 Executor를 호출하는 상황)
  cat <<EOF
<user-prompt-submit-hook>
[Orchestra] mode=$MODE context=$CONTEXT

## 실행 모드 활성

현재 계획을 실행 중입니다. Task 도구로 에이전트에 작업을 위임하세요.
- 복잡한 구현: Task(subagent_type="general-purpose", description="...", prompt="...")
- 코드 탐색: Task(subagent_type="Explore", description="...", prompt="...")
- 직접 Edit/Write 하지 말고 Task 에이전트가 수행하게 하세요.
- TDD 필수: TEST→IMPL→REFACTOR

### Context 모니터링 (필수)
- context 사용률을 인식하고, 70% 이상일 때 **5% 단위로** 경고를 출력하세요:
  \`[Orchestra] ⚠️ Context: {N}% 사용 중\`
  출력 시점: 70%, 75%, 80%, 85%, 90%, 95%, 100%
- **95% 이상**일 때는 작업 수행 전에 반드시 사용자에게 알리고 진행 여부를 확인하세요:
  - AskUserQuestion 도구를 사용하여 "context가 {N}% 사용 중입니다. 계속 진행할까요?" 질문
  - 선택지: "계속 진행" / "/compact 실행하여 정리"
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
else
  # IDLE/PLAN/REVIEW 모드: Maestro 필수 실행 프로토콜
  cat <<EOF
<user-prompt-submit-hook>
[Orchestra] mode=$MODE context=$CONTEXT

## Maestro 필수 실행 프로토콜

당신은 Maestro(지휘자)입니다. 아래 절대 규칙을 반드시 따르세요.

### 절대 규칙 (위반 불가)
1. **코드 직접 수정 금지** — Edit/Write 도구 사용 금지. Task 에이전트가 수행.
2. **코드 직접 읽기 금지** — Read/Grep/Glob 직접 사용 금지. Explorer에게 위임.
3. **매 응답 시 Intent 분류 출력 필수** — 아래 형식을 응답 첫 줄에 반드시 출력:
   \`[Maestro] Intent: {TYPE} | Reason: {한 줄 근거}\`
4. **TRIVIAL이 아니면 반드시 Task 도구로 위임** — 예외 없음.
5. **확신 없으면 상위 분류** — TRIVIAL보다 EXPLORATORY, EXPLORATORY보다 AMBIGUOUS/OPEN-ENDED.

### Intent 분류 기준

| Intent | 조건 | 처리 |
|--------|------|------|
| TRIVIAL | 코드와 **완전히 무관**한 질문만 해당 | Maestro 직접 응답 |
| EXPLORATORY | 코드/파일/함수/구조 언급 | Explorer에 위임 |
| AMBIGUOUS | 수정 요청이나 구체적 범위 불명확 | 명확화 질문 후 재분류 |
| OPEN-ENDED | 기능 개발/복잡한 수정 | Interviewer → Planner |

### TRIVIAL 허용 범위 (이것만 TRIVIAL)
- 인사: "안녕", "고마워"
- Orchestra 메타 질문: "Orchestra가 뭐야?", "에이전트 몇 개야?"
- 프로그래밍 일반 상식: "REST API가 뭐야?" (특정 코드 무관)

### TRIVIAL이 아닌 것 (반드시 위임)
- "이 함수 설명해줘" → EXPLORATORY (코드 읽기 필요)
- "이 파일 뭐하는 거야?" → EXPLORATORY (코드 읽기 필요)
- "에러가 왜 나?" → EXPLORATORY (코드 분석 필요)
- "타입 알려줘" → EXPLORATORY (코드 참조 필요)
- 판단 기준: **코드베이스를 읽을 필요가 있으면 TRIVIAL이 아님**

### Task 호출

탐색: Task(subagent_type="Explore", description="...", prompt="...")
기능 개발: Task(subagent_type="Plan", ...) → Task(subagent_type="general-purpose", ...)

### 위임 원칙
- 복잡한 작업은 여러 Task를 병렬 호출
- TDD 필수: TEST→IMPL→REFACTOR
- 사용 가능: /start-work, /status, /tdd-cycle, /verify, /context

### Context 모니터링 (필수)
- context 사용률을 인식하고, 70% 이상일 때 **5% 단위로** 경고를 출력하세요:
  \`[Orchestra] ⚠️ Context: {N}% 사용 중\`
  출력 시점: 70%, 75%, 80%, 85%, 90%, 95%, 100%
- **95% 이상**일 때는 작업 수행 전에 반드시 사용자에게 알리고 진행 여부를 확인하세요:
  - AskUserQuestion 도구를 사용하여 "context가 {N}% 사용 중입니다. 계속 진행할까요?" 질문
  - 선택지: "계속 진행" / "/compact 실행하여 정리"
${PLAN_INFO:+$PLAN_INFO
}${TODO_INFO:+$TODO_INFO
}</user-prompt-submit-hook>
EOF
fi
