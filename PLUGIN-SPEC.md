# Claude Code Plugin 공식 스펙 정리

> 이 문서는 Claude Code 공식 문서를 기반으로 플러그인 시스템 스펙을 정리한 것입니다.
> 참조: https://code.claude.com/docs/en/plugins-reference

---

## 1. 플러그인 디렉토리 구조

```
my-plugin/
├── .claude-plugin/           # 메타데이터 디렉토리 (선택)
│   └── plugin.json           # 플러그인 매니페스트
├── commands/                 # 명령어 (레거시, skills/ 권장)
│   └── my-command.md
├── skills/                   # 스킬 디렉토리
│   └── my-skill/
│       ├── SKILL.md          # 필수: 스킬 정의
│       ├── reference.md      # 선택: 참조 문서
│       └── scripts/          # 선택: 스크립트
├── agents/                   # 에이전트 정의
│   └── my-agent.md
├── hooks/                    # 훅 설정
│   └── hooks.json            # 메인 훅 설정
├── .mcp.json                 # MCP 서버 정의
├── .lsp.json                 # LSP 서버 설정
└── scripts/                  # 유틸리티 스크립트
```

**중요**: `.claude-plugin/` 안에는 `plugin.json`만 위치. 다른 컴포넌트(commands/, agents/, skills/, hooks/)는 플러그인 루트에 위치해야 함.

---

## 2. Hooks (훅)

### 2.1 Hook 설정 위치 (우선순위 순)

| 위치 | 범위 | 공유 가능 |
|------|------|-----------|
| `~/.claude/settings.json` | 모든 프로젝트 | 아니오 (로컬) |
| `.claude/settings.json` | 현재 프로젝트 | 예 (커밋 가능) |
| `.claude/settings.local.json` | 현재 프로젝트 | 아니오 (gitignore) |
| Plugin `hooks/hooks.json` | 플러그인 활성화 시 | 예 (플러그인과 함께) |
| Skill/Agent frontmatter | 컴포넌트 활성 시 | 예 (컴포넌트에 정의) |

### 2.2 Hook 이벤트 목록

| 이벤트 | 발생 시점 | 차단 가능 |
|--------|----------|-----------|
| `SessionStart` | 세션 시작/재개 | 아니오 |
| `UserPromptSubmit` | 사용자 프롬프트 제출 전 | 예 |
| `PreToolUse` | 도구 실행 전 | 예 |
| `PermissionRequest` | 권한 대화상자 표시 시 | 예 |
| `PostToolUse` | 도구 실행 성공 후 | 아니오 |
| `PostToolUseFailure` | 도구 실행 실패 후 | 아니오 |
| `Notification` | 알림 전송 시 | 아니오 |
| `SubagentStart` | 서브에이전트 시작 시 | 아니오 |
| `SubagentStop` | 서브에이전트 종료 시 | 예 |
| `Stop` | Claude 응답 완료 시 | 예 |
| `TeammateIdle` | 팀원이 유휴 상태로 전환 시 | 예 |
| `TaskCompleted` | 태스크 완료 표시 시 | 예 |
| `PreCompact` | 컨텍스트 압축 전 | 아니오 |
| `SessionEnd` | 세션 종료 시 | 아니오 |

### 2.3 Hook 설정 형식

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/my-hook.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### 2.4 Hook 타입

| 타입 | 설명 |
|------|------|
| `command` | 셸 명령 실행. stdin으로 JSON 입력, stdout으로 JSON 출력 |
| `prompt` | LLM에 프롬프트 전송하여 평가. `$ARGUMENTS`로 입력 삽입 |
| `agent` | 도구 사용 가능한 에이전트로 검증 |

### 2.5 Hook 입출력

**입력 (stdin JSON)**:
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

**출력 (stdout JSON)**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "차단 사유"
  }
}
```

### 2.6 Exit Code

| Exit Code | 의미 |
|-----------|------|
| 0 | 성공. stdout의 JSON 처리 |
| 2 | 차단 에러. stderr를 Claude에게 전달 |
| 기타 | 비차단 에러. stderr는 verbose 모드에서만 표시 |

### 2.7 환경 변수

| 변수 | 설명 |
|------|------|
| `${CLAUDE_PLUGIN_ROOT}` | 플러그인 루트 디렉토리 절대 경로 |
| `$CLAUDE_PROJECT_DIR` | 프로젝트 루트 디렉토리 |
| `$CLAUDE_CODE_REMOTE` | 원격 웹 환경이면 "true" |

---

## 3. Skills (스킬)

### 3.1 스킬 위치

| 위치 | 범위 |
|------|------|
| `~/.claude/skills/<name>/SKILL.md` | 모든 프로젝트 (개인) |
| `.claude/skills/<name>/SKILL.md` | 현재 프로젝트 |
| `<plugin>/skills/<name>/SKILL.md` | 플러그인 활성화 시 |

### 3.2 SKILL.md 형식

```yaml
---
name: my-skill
description: 스킬 설명 (Claude가 자동 호출 판단에 사용)
disable-model-invocation: false  # true면 사용자만 호출 가능
user-invocable: true             # false면 Claude만 호출 가능
allowed-tools: Read, Grep, Glob  # 허용 도구
model: sonnet                    # 사용 모델
context: fork                    # fork면 서브에이전트로 실행
agent: Explore                   # context: fork일 때 사용할 에이전트
hooks:                           # 스킬 활성 시 적용될 훅
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate.sh"
---

스킬 지시사항...

$ARGUMENTS 로 인자 접근
$0, $1 등으로 개별 인자 접근
!`command` 로 동적 컨텍스트 주입
```

### 3.3 호출 제어

| 설정 | 사용자 호출 | Claude 호출 |
|------|------------|-------------|
| (기본) | O | O |
| `disable-model-invocation: true` | O | X |
| `user-invocable: false` | X | O |

---

## 4. Agents (에이전트/서브에이전트)

### 4.1 에이전트 위치

| 위치 | 범위 | 우선순위 |
|------|------|----------|
| `--agents` CLI 플래그 | 현재 세션 | 1 (최고) |
| `.claude/agents/` | 현재 프로젝트 | 2 |
| `~/.claude/agents/` | 모든 프로젝트 | 3 |
| `<plugin>/agents/` | 플러그인 활성화 시 | 4 |

### 4.2 에이전트 정의 형식

```yaml
---
name: my-agent
description: 에이전트 설명 (Claude가 자동 위임 판단에 사용)
tools: Read, Grep, Glob, Bash    # 허용 도구
disallowedTools: Write, Edit     # 차단 도구
model: sonnet                    # sonnet, opus, haiku, inherit
permissionMode: default          # default, acceptEdits, dontAsk, bypassPermissions, plan
maxTurns: 50                     # 최대 턴 수
skills:                          # 로드할 스킬
  - api-conventions
mcpServers:                      # MCP 서버
  slack: {}
hooks:                           # 에이전트 활성 시 훅
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate.sh"
memory: user                     # user, project, local (지속 메모리)
---

에이전트 시스템 프롬프트...
```

### 4.3 내장 에이전트

| 에이전트 | 모델 | 도구 | 용도 |
|----------|------|------|------|
| **Explore** | Haiku | 읽기 전용 | 코드베이스 탐색/검색 |
| **Plan** | 상속 | 읽기 전용 | 계획 모드에서 컨텍스트 수집 |
| **general-purpose** | 상속 | 전체 | 복잡한 다단계 작업 |

---

## 5. MCP Servers

### 5.1 설정 위치

- 플러그인: `.mcp.json` 또는 `plugin.json` 내 인라인
- 프로젝트: `.claude/settings.json`

### 5.2 설정 형식

```json
{
  "mcpServers": {
    "my-server": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/my-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": {
        "API_KEY": "xxx"
      },
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

---

## 6. plugin.json 매니페스트

```json
{
  "name": "plugin-name",           // 필수
  "version": "1.0.0",
  "description": "설명",
  "author": {
    "name": "이름",
    "email": "email@example.com"
  },
  "commands": "./custom/commands/",
  "agents": "./custom/agents/",
  "skills": "./custom/skills/",
  "hooks": "./hooks/hooks.json",
  "mcpServers": "./.mcp.json",
  "lspServers": "./.lsp.json"
}
```

---

## 7. 플러그인 로딩 동작

### 7.1 훅 로딩 순서

1. 글로벌 `~/.claude/settings.json`
2. 프로젝트 `.claude/settings.json`
3. 프로젝트 `.claude/settings.local.json`
4. 활성화된 플러그인의 `hooks/hooks.json`

**중요**: 플러그인의 `hooks/hooks.json`은 **플러그인이 활성화되어 있을 때만** 자동으로 로드됨. 프로젝트의 `.claude/hooks.json`은 **별도 파일로 인식되지 않음**.

### 7.2 플러그인 캐시

- 플러그인은 `~/.claude/plugins/cache/` 에 캐시됨
- 설치 시 플러그인 전체가 캐시 디렉토리로 복사됨
- `${CLAUDE_PLUGIN_ROOT}`는 이 캐시 경로를 가리킴

### 7.3 hooks 설정 방법 (정리)

**방법 1: 플러그인의 hooks/hooks.json 사용 (권장)**
- 플러그인 활성화 시 자동 로드
- `${CLAUDE_PLUGIN_ROOT}` 환경변수 자동 설정

**방법 2: settings.json에 hooks 추가**
- `.claude/settings.json` 또는 `~/.claude/settings.json`
- `"hooks": { ... }` 키로 직접 정의
- 프로젝트별 절대 경로 필요

**방법 3: Skill/Agent frontmatter에 정의**
- 해당 컴포넌트 활성화 시에만 적용

---

## 8. 트러블슈팅

### 8.1 훅이 실행되지 않음

1. 스크립트 실행 권한 확인: `chmod +x script.sh`
2. shebang 확인: `#!/bin/bash` 또는 `#!/usr/bin/env bash`
3. 경로에 `${CLAUDE_PLUGIN_ROOT}` 사용 확인
4. 플러그인 활성화 확인

### 8.2 별도의 .claude/hooks.json이 인식되지 않음

Claude Code는 다음 위치의 hooks만 읽음:
- `settings.json` 내 `"hooks"` 키
- 플러그인의 `hooks/hooks.json`

**해결책**: `settings.json`에 hooks를 병합하거나, 플러그인 hooks.json 사용

### 8.3 ${CLAUDE_PLUGIN_ROOT}가 비어있음

- 이 변수는 **플러그인의 hook 스크립트 실행 시에만** 설정됨
- 프로젝트의 settings.json에서 직접 정의한 hooks는 이 변수 사용 불가
- **해결책**: 절대 경로 사용 또는 wrapper 스크립트로 플러그인 경로 동적 탐지

---

## 참고 자료

- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Skills](https://code.claude.com/docs/en/skills)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
- [Settings](https://code.claude.com/docs/en/settings)
