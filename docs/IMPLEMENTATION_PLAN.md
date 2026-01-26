# Claude Orchestra 구현 계획서

> Kent Beck의 AI TDD 원칙을 따르는 12-Agent 오케스트레이션 시스템

**작성일**: 2026-01-25
**상태**: 계획 수립 완료

---

## 목차

1. [현재 상태 분석](#1-현재-상태-분석)
2. [Kent Beck AI TDD 원칙](#2-kent-beck-ai-tdd-원칙)
3. [구현 Phase 개요](#3-구현-phase-개요)
4. [상세 구현 계획](#4-상세-구현-계획)
5. [의존성 그래프](#5-의존성-그래프)
6. [검증 체크리스트](#6-검증-체크리스트)
7. [위험 관리](#7-위험-관리)

---

## 1. 현재 상태 분석

### 1.1 프로젝트 현황

| 항목 | 상태 |
|------|------|
| 기존 파일 | 3개 (설계 문서만 존재) |
| 구현 파일 | 0개 |
| 목표 파일 | 65개 |
| 구현 Phase | 12개 |

### 1.2 기존 파일 목록

```
claude-orchestra/
├── CLAUDE_ORCHESTRA_IMPLEMENTATION.md  ← 마스터 설계 문서 (1922줄)
└── docs/
    ├── everything-claude-code-analysis.md  ← 레퍼런스 분석
    └── oh-my-opencode-analysis.md  ← 레퍼런스 분석
```

### 1.3 목표 구조

```
claude-orchestra/
├── templates/
│   ├── .claude/
│   │   ├── agents/          # 12개 에이전트
│   │   ├── commands/        # 10개 명령어
│   │   └── settings.json
│   ├── .orchestra/
│   │   ├── hooks/           # 15+ 스크립트
│   │   ├── rules/           # 6개 규칙
│   │   ├── contexts/        # 3개 컨텍스트
│   │   ├── config.json
│   │   └── state.json
│   └── CLAUDE.md
├── .claude-plugin/
├── install.sh
├── uninstall.sh
└── README.md
```

---

## 2. Kent Beck AI TDD 원칙

### 2.1 핵심 원칙

```
┌─────────────────────────────────────────────────────────────┐
│                    RED-GREEN-REFACTOR                        │
├─────────────────────────────────────────────────────────────┤
│  RED      │ 실패하는 테스트 작성 (기대 동작 정의)           │
│  GREEN    │ 테스트 통과하는 최소 구현                       │
│  REFACTOR │ 테스트 유지하며 코드 개선                       │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 적용 방식

| 원칙 | 적용 |
|------|------|
| **Test-First** | 각 파일 생성 전 검증 명령어 정의 |
| **Small Steps** | Phase를 3-5개 하위 작업으로 분할 |
| **AI-Assisted** | AI가 구현, 테스트가 검증 |
| **Human-Validated** | 주요 결정은 사람이 검토 |

### 2.3 TDD 사이클 (TODO 레벨)

모든 TODO는 다음 형식을 따름:

```
[TEST] 실패하는 테스트 작성
[IMPL] 테스트 통과하는 최소 구현
[REFACTOR] 코드 정리 (테스트 유지)
```

---

## 3. 구현 Phase 개요

### 3.1 Phase 요약

| Phase | 이름 | 파일 수 | 의존성 |
|-------|------|---------|--------|
| 1 | Foundation | 4 | - |
| 2 | Core Agents (1-6) | 6 | Phase 1 |
| 3 | Extended Agents (7-12) | 6 | Phase 2 |
| 4 | TDD Hooks | 2 | Phase 1 |
| 5 | Verification Loop | 9 | Phase 4 |
| 6 | Core Commands | 5 | Phase 3, 5 |
| 7 | Learning System | 4 | Phase 1 |
| 8 | Strategic Compaction | 2 | Phase 1 |
| 9 | Extended Commands | 5 | Phase 6 |
| 10 | Rules & Contexts | 9 | Phase 1 |
| 11 | Extended Hooks | 5 | Phase 4 |
| 12 | Distribution | 8 | All |

### 3.2 우선순위 그룹

**Critical Path (필수)**: Phase 1 → 2 → 3 → 4 → 5 → 6 → 12

**Enhancement (향상)**: Phase 7, 8, 9, 10, 11

---

## 4. 상세 구현 계획

### Phase 1: Foundation (기초 인프라)

**목표**: 디렉토리 구조 및 핵심 설정 파일 생성

#### 1.1 디렉토리 구조

**[TEST] 검증 명령어**:
```bash
# 디렉토리 존재 확인
test -d templates/.claude/agents && echo "PASS" || echo "FAIL"
test -d templates/.claude/commands && echo "PASS" || echo "FAIL"
test -d templates/.orchestra/hooks && echo "PASS" || echo "FAIL"
test -d templates/.orchestra/hooks/verification && echo "PASS" || echo "FAIL"
test -d templates/.orchestra/rules && echo "PASS" || echo "FAIL"
test -d templates/.orchestra/contexts && echo "PASS" || echo "FAIL"
```

**[IMPL] 생성할 디렉토리**:
```
templates/
├── .claude/
│   ├── agents/
│   └── commands/
└── .orchestra/
    ├── hooks/
    │   ├── verification/
    │   ├── learning/
    │   │   └── learned-patterns/
    │   └── compact/
    ├── rules/
    ├── contexts/
    ├── templates/
    ├── mcp-configs/
    ├── plans/
    ├── notepads/
    └── logs/
```

#### 1.2 핵심 설정 파일

**[TEST] 검증 명령어**:
```bash
# JSON 유효성 검사
jq '.' templates/.claude/settings.json > /dev/null 2>&1 && echo "settings.json: PASS" || echo "FAIL"
jq '.' templates/.orchestra/config.json > /dev/null 2>&1 && echo "config.json: PASS" || echo "FAIL"
jq '.' templates/.orchestra/state.json > /dev/null 2>&1 && echo "state.json: PASS" || echo "FAIL"
```

**[IMPL] 생성할 파일**:

| 파일 | 내용 |
|------|------|
| `templates/.claude/settings.json` | 에이전트 설정, 권한, Hook 등록 |
| `templates/.orchestra/config.json` | 프로젝트 설정 (언어, 테스트러너) |
| `templates/.orchestra/state.json` | 상태 관리 템플릿 |

**settings.json 스키마**:
```json
{
  "agents": {
    "maestro": { "model": "opus", "allowedTools": ["Task", "Read", "Grep"] },
    "planner": { "model": "opus", "allowedTools": ["Task", "Bash", "Edit"] }
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "command": ".orchestra/hooks/tdd-guard.sh" }
    ],
    "PostToolUse": [
      { "matcher": "Bash(npm test*)", "command": ".orchestra/hooks/test-logger.sh" }
    ]
  }
}
```

**✅ Phase 1 완료 기준**:
- [ ] 모든 디렉토리 존재
- [ ] 3개 JSON 파일 유효
- [ ] settings.json에 agents, hooks 필드 존재

---

### Phase 2: Core Agents (1-6)

**목표**: 핵심 오케스트레이션 에이전트 생성

#### 2.1 에이전트 파일 구조

**[TEST] 검증 명령어**:
```bash
# 에이전트 파일 구조 검증
for agent in maestro planner interviewer plan-checker plan-reviewer architecture; do
  FILE="templates/.claude/agents/${agent}.md"
  if test -f "$FILE" && \
     grep -q "^## Model" "$FILE" && \
     grep -q "^## Role" "$FILE" && \
     grep -q "^## Capabilities" "$FILE" && \
     grep -q "^## Restrictions" "$FILE"; then
    echo "${agent}: PASS"
  else
    echo "${agent}: FAIL"
  fi
done
```

**[IMPL] 생성할 파일**:

| 순서 | 파일 | 모델 | 역할 |
|------|------|------|------|
| 1 | `maestro.md` | Opus | 사용자 대화, Intent 분류 |
| 2 | `planner.md` | Opus | TODO 관리, Executor 위임 |
| 3 | `interviewer.md` | Opus | 요구사항 인터뷰 |
| 4 | `plan-checker.md` | Sonnet | 계획 전 분석 |
| 5 | `plan-reviewer.md` | Sonnet | 계획 검증 |
| 6 | `architecture.md` | Opus | 아키텍처 조언 |

**에이전트 마크다운 템플릿**:
```markdown
# {Agent Name}

## Model
claude-{opus|sonnet|haiku}-4-5

## Role
{역할 설명 1-2문장}

## Capabilities
- 기능 1
- 기능 2
- 기능 3

## Restrictions
- 금지 사항 1
- 금지 사항 2

## Workflow
1. 단계 1
2. 단계 2
3. 단계 3

## Handoff Protocol
다음 에이전트로 넘길 때: {handoff 조건}
```

**✅ Phase 2 완료 기준**:
- [ ] 6개 에이전트 파일 존재
- [ ] 각 파일에 필수 섹션 포함
- [ ] 모델 할당이 설계서와 일치

---

### Phase 3: Extended Agents (7-12)

**목표**: 연구 및 실행 전문 에이전트 생성

#### 3.1 Research Agents (Read-Only)

**[TEST] 검증 명령어**:
```bash
# Read-Only 제약 검증
for agent in searcher explorer image-analyst; do
  FILE="templates/.claude/agents/${agent}.md"
  if grep -qi "read.only\|write.*forbidden\|edit.*forbidden" "$FILE"; then
    echo "${agent} read-only: PASS"
  else
    echo "${agent} read-only: FAIL"
  fi
done
```

**[IMPL] 생성할 파일**:

| 순서 | 파일 | 모델 | 역할 |
|------|------|------|------|
| 7 | `searcher.md` | Sonnet | 외부 문서/GitHub 검색 |
| 8 | `explorer.md` | Haiku | 내부 코드베이스 검색 |
| 9 | `image-analyst.md` | Sonnet | 이미지 분석 |

#### 3.2 Execution Agents

**[IMPL] 생성할 파일**:

| 순서 | 파일 | 모델 | 역할 |
|------|------|------|------|
| 10 | `high-player.md` | Opus | 복잡한 작업 실행 |
| 11 | `low-player.md` | Sonnet | 간단한 작업 실행 |
| 12 | `code-reviewer.md` | Sonnet | 코드 리뷰 (25+ 차원) |

**✅ Phase 3 완료 기준**:
- [ ] 12개 에이전트 파일 모두 존재
- [ ] Research 에이전트에 Read-Only 제약 명시
- [ ] Execution 에이전트에 delegate_task 금지 명시

---

### Phase 4: TDD Hooks

**목표**: TDD 강제 메커니즘 구현

#### 4.1 tdd-guard.sh

**[TEST] 검증 명령어**:
```bash
# 테스트 파일 삭제 차단 검증
echo 'test("example", () => {})' > /tmp/test.test.ts
./templates/.orchestra/hooks/tdd-guard.sh "Edit" '{"file_path":"/tmp/test.test.ts","old_string":"test(","new_string":""}'
if [ $? -ne 0 ]; then echo "PASS - blocked"; else echo "FAIL"; fi
```

**[IMPL] 생성할 파일**: `templates/.orchestra/hooks/tdd-guard.sh`

```bash
#!/bin/bash
# tdd-guard.sh - 테스트 삭제 방지 Hook

TOOL_NAME="$1"
INPUT="$2"

# Edit/Write만 검사
[[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // .path // ""')

# 테스트 파일 검사
if [[ "$FILE_PATH" =~ \.(test|spec)\.(ts|js|tsx|jsx)$ ]]; then
  OLD_CONTENT=$(echo "$INPUT" | jq -r '.old_string // ""')
  NEW_CONTENT=$(echo "$INPUT" | jq -r '.new_string // .content // ""')

  # 테스트 케이스 삭제 감지
  if [[ "$OLD_CONTENT" =~ (test|it|describe)\( ]] && \
     [[ ! "$NEW_CONTENT" =~ (test|it|describe)\( ]]; then
    echo "❌ TDD Guard: 테스트 케이스 삭제가 감지되었습니다."
    echo "테스트를 삭제하려면 명시적인 승인이 필요합니다."
    exit 1
  fi
fi

exit 0
```

#### 4.2 test-logger.sh

**[IMPL] 생성할 파일**: `templates/.orchestra/hooks/test-logger.sh`

```bash
#!/bin/bash
# test-logger.sh - 테스트 결과 기록

STATE_FILE=".orchestra/state.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 테스트 결과 파싱 및 state.json 업데이트
# ... (구현 내용)
```

**✅ Phase 4 완료 기준**:
- [ ] tdd-guard.sh 실행 가능
- [ ] 테스트 파일 삭제 차단 동작
- [ ] test-logger.sh가 메트릭 업데이트
- [ ] settings.json에 Hook 등록

---

### Phase 5: 6-Stage Verification Loop

**목표**: 종합 검증 시스템 구현

#### 5.1 검증 스크립트

**[TEST] 검증 명령어**:
```bash
# 각 스크립트 실행 가능 확인
for script in build-check type-check lint-check test-coverage security-scan diff-review; do
  test -x "templates/.orchestra/hooks/verification/${script}.sh" && \
    echo "${script}: PASS" || echo "${script}: FAIL"
done
```

**[IMPL] 생성할 파일**:

| 순서 | 파일 | 역할 | 실패 시 |
|------|------|------|---------|
| 1 | `build-check.sh` | 빌드 검증 | STOP |
| 2 | `type-check.sh` | 타입 체크 | 에러 리포트 |
| 3 | `lint-check.sh` | 린트 검사 | 경고/에러 목록 |
| 4 | `test-coverage.sh` | 테스트 + 커버리지 | 80% 미만 시 BLOCK |
| 5 | `security-scan.sh` | 보안 스캔 | 이슈 목록 |
| 6 | `diff-review.sh` | 변경사항 검토 | 경고 |
| 7 | `verification-loop.sh` | 오케스트레이터 | - |
| 8 | `verification-report.sh` | 리포트 생성 | - |

#### 5.2 검증 리포트 형식

```
╔═══════════════════════════════════════════════════════════════╗
║                   VERIFICATION REPORT                          ║
║                   Mode: full | 2026-01-25 10:30:00            ║
╠═══════════════════════════════════════════════════════════════╣
║  Phase 1: Build         ✅ PASS          (3.2s)               ║
║  Phase 2: Type Check    ✅ PASS          (1.8s)               ║
║  Phase 3: Lint          ⚠️ 5 warnings    (2.1s)               ║
║  Phase 4: Tests         ✅ 47/47 passed  (8.5s)               ║
║           Coverage      ✅ 84.5%                              ║
║  Phase 5: Security      ✅ No issues     (0.8s)               ║
║  Phase 6: Diff Review   ✅ 5 files       (0.3s)               ║
╠═══════════════════════════════════════════════════════════════╣
║  Total Duration: 16.7s                                         ║
║  PR Ready: ✅ YES                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

**✅ Phase 5 완료 기준**:
- [ ] 8개 스크립트 모두 실행 가능
- [ ] verification-loop.sh가 순차 실행
- [ ] JSON 형식 결과 출력
- [ ] /verify 명령어 추가

---

### Phase 6: Core Commands (핵심 명령어)

**목표**: 5개 필수 슬래시 명령어 구현

**[TEST] 검증 명령어**:
```bash
for cmd in start-work tdd-cycle status verify code-review; do
  FILE="templates/.claude/commands/${cmd}.md"
  if test -f "$FILE" && grep -q "^## Usage" "$FILE"; then
    echo "${cmd}: PASS"
  else
    echo "${cmd}: FAIL"
  fi
done
```

**[IMPL] 생성할 파일**:

| 파일 | 용도 |
|------|------|
| `start-work.md` | 작업 세션 시작 |
| `tdd-cycle.md` | TDD 사이클 안내 |
| `status.md` | 현재 상태 표시 |
| `verify.md` | 6단계 검증 실행 |
| `code-review.md` | 코드 리뷰 트리거 |

**명령어 마크다운 템플릿**:
```markdown
# /{command-name}

## Usage
`/{command-name} [options]`

## Description
{명령어 설명}

## Options
- `option1`: 설명
- `option2`: 설명

## Examples
```
/{command-name}
/{command-name} --option
```

## Related Agents
- {관련 에이전트}
```

**✅ Phase 6 완료 기준**:
- [ ] 5개 명령어 파일 존재
- [ ] 각 파일에 Usage, Description 섹션 포함
- [ ] CLAUDE.md에 명령어 목록 추가

---

### Phase 7: Continuous Learning (연속 학습)

**목표**: 세션 패턴 추출 및 학습 시스템

**[IMPL] 생성할 파일**:

| 파일 | 용도 |
|------|------|
| `hooks/learning/config.json` | 학습 설정 |
| `hooks/learning/evaluate-session.sh` | 세션 평가 스크립트 |
| `hooks/learning/learned-patterns/.gitkeep` | 패턴 저장소 |
| `commands/learn.md` | /learn 명령어 |

**config.json**:
```json
{
  "min_session_length": 10,
  "extraction_threshold": "medium",
  "auto_approve": false,
  "pattern_categories": [
    "error_resolution",
    "debugging_techniques",
    "workarounds",
    "project_specific"
  ]
}
```

**✅ Phase 7 완료 기준**:
- [ ] config.json 유효
- [ ] evaluate-session.sh 실행 가능
- [ ] /learn 명령어 동작

---

### Phase 8: Strategic Compaction (전략적 컴팩션)

**목표**: 컨텍스트 효율성을 위한 압축 제안 시스템

**[IMPL] 생성할 파일**:

| 파일 | 용도 |
|------|------|
| `hooks/compact/compact-config.json` | 컴팩션 설정 |
| `hooks/compact/suggest-compact.sh` | 컴팩션 제안 스크립트 |

**트리거 조건**:
- 50회 도구 호출 → 첫 제안
- 이후 25회마다 → 리마인더
- Phase 전환 시 → 자동 제안

**✅ Phase 8 완료 기준**:
- [ ] suggest-compact.sh가 도구 호출 카운트 추적
- [ ] 임계값에서 제안 출력
- [ ] PreToolUse Hook에 등록

---

### Phase 9: Extended Commands (확장 명령어)

**목표**: 5개 추가 명령어 구현

**[IMPL] 생성할 파일**:

| 파일 | 용도 |
|------|------|
| `checkpoint.md` | 상태 스냅샷 |
| `e2e.md` | E2E 테스트 실행 |
| `refactor-clean.md` | 리팩토링 모드 |
| `update-docs.md` | 문서 동기화 |
| `context.md` | 컨텍스트 모드 전환 |

**✅ Phase 9 완료 기준**:
- [ ] 10개 명령어 파일 모두 존재
- [ ] 일관된 구조

---

### Phase 10: Rules & Contexts (규칙 및 컨텍스트)

**목표**: 상시 적용 규칙 및 모드별 컨텍스트

#### 10.1 Rules (6개)

| 파일 | 내용 |
|------|------|
| `security.md` | 8가지 보안 체크 |
| `testing.md` | TDD 요구사항 |
| `git-workflow.md` | Git 컨벤션 |
| `coding-style.md` | 코딩 스타일 |
| `performance.md` | 성능 가이드라인 |
| `agent-rules.md` | 에이전트 사용 규칙 |

#### 10.2 Contexts (3개)

| 파일 | 모드 | 우선순위 |
|------|------|----------|
| `dev.md` | 개발 | 기능성 > 정확성 > 품질 |
| `research.md` | 연구 | 이해도 > 완전성 > 정확성 |
| `review.md` | 리뷰 | 보안 > 정확성 > 성능 |

**✅ Phase 10 완료 기준**:
- [ ] 6개 규칙 파일 존재
- [ ] 3개 컨텍스트 파일 존재
- [ ] CLAUDE.md에서 참조

---

### Phase 11: Extended Hooks (확장 Hook)

**목표**: 추가 자동화 Hook 및 템플릿

**[IMPL] 생성할 파일**:

| 파일 | 용도 |
|------|------|
| `auto-format.sh` | Prettier 자동 포맷팅 |
| `git-push-review.sh` | Push 전 검토 |
| `load-context.sh` | 세션 시작 시 로드 |
| `save-context.sh` | 세션 종료 시 저장 |
| `templates/handoff-document.md` | 에이전트 핸드오프 템플릿 |

**✅ Phase 11 완료 기준**:
- [ ] 4개 Hook 실행 가능
- [ ] settings.json에 등록
- [ ] handoff 템플릿 완성

---

### Phase 12: Distribution (배포)

**목표**: 설치 및 배포 시스템 완성

#### 12.1 Plugin 파일

| 파일 | 용도 |
|------|------|
| `.claude-plugin/plugin.json` | 플러그인 메타데이터 |
| `.claude-plugin/marketplace.json` | 마켓플레이스 설정 |

#### 12.2 설치 스크립트

| 파일 | 용도 |
|------|------|
| `install.sh` | 설치 스크립트 |
| `uninstall.sh` | 제거 스크립트 |

**[TEST] 검증 명령어**:
```bash
# Clean install 테스트
rm -rf ~/.claude/agents/maestro.md .orchestra/
./install.sh
test -f ".claude/agents/maestro.md" && echo "Install: PASS" || echo "FAIL"
test -f ".orchestra/state.json" && echo "State: PASS" || echo "FAIL"
```

#### 12.3 문서

| 파일 | 용도 |
|------|------|
| `README.md` | 사용 가이드 |
| `CHANGELOG.md` | 버전 이력 |
| `templates/CLAUDE.md` | 프로젝트 가이드 |

#### 12.4 CI/CD

| 파일 | 용도 |
|------|------|
| `.github/workflows/release.yml` | Release 자동화 |

**✅ Phase 12 완료 기준**:
- [ ] install.sh 정상 동작
- [ ] uninstall.sh 정상 동작
- [ ] README.md 완성
- [ ] GitHub Actions 검증 통과

---

## 5. 의존성 그래프

```
Phase 1 (Foundation)
    │
    ├──► Phase 2 (Agents 1-6)
    │       │
    │       └──► Phase 3 (Agents 7-12)
    │
    ├──► Phase 4 (TDD Hooks)
    │       │
    │       └──► Phase 5 (Verification Loop)
    │               │
    │               └──► Phase 6 (Core Commands)
    │                       │
    │                       └──► Phase 9 (Extended Commands)
    │
    ├──► Phase 7 (Learning) ─────────────┐
    │                                     │
    ├──► Phase 8 (Compaction) ───────────┤
    │                                     │
    ├──► Phase 10 (Rules & Contexts) ────┤
    │                                     │
    └──► Phase 11 (Extended Hooks) ──────┘
                                          │
                                          ▼
                                   Phase 12 (Distribution)
```

**Critical Path**: 1 → 2 → 3 → 4 → 5 → 6 → 12

**병렬 가능**: Phase 7, 8, 10은 Phase 1 이후 병렬 진행 가능

---

## 6. 검증 체크리스트

### Phase별 체크리스트

#### Phase 1: Foundation
- [ ] `templates/.claude/agents/` 디렉토리 존재
- [ ] `templates/.claude/commands/` 디렉토리 존재
- [ ] `templates/.orchestra/hooks/` 디렉토리 존재
- [ ] `templates/.claude/settings.json` 유효한 JSON
- [ ] `templates/.orchestra/config.json` 유효한 JSON
- [ ] `templates/.orchestra/state.json` 유효한 JSON

#### Phase 2-3: Agents
- [ ] 12개 에이전트 파일 모두 존재
- [ ] 각 파일에 Model, Role, Capabilities, Restrictions 섹션 포함
- [ ] Research 에이전트에 Read-Only 제약 명시

#### Phase 4: TDD Hooks
- [ ] `tdd-guard.sh` 실행 가능 (chmod +x)
- [ ] 테스트 삭제 차단 동작
- [ ] `test-logger.sh` 실행 가능
- [ ] settings.json에 Hook 등록

#### Phase 5: Verification Loop
- [ ] 8개 검증 스크립트 실행 가능
- [ ] `verification-loop.sh`가 6단계 순차 실행
- [ ] JSON 결과 출력

#### Phase 6: Core Commands
- [ ] 5개 명령어 파일 존재
- [ ] 각 파일에 Usage, Description 섹션

#### Phase 7-11: Enhancement
- [ ] Learning config.json 유효
- [ ] Compaction suggest-compact.sh 동작
- [ ] 6개 Rules 파일 존재
- [ ] 3개 Contexts 파일 존재
- [ ] 4개 Extended Hook 실행 가능

#### Phase 12: Distribution
- [ ] `install.sh` 정상 실행
- [ ] `uninstall.sh` 정상 실행
- [ ] `README.md` 완성
- [ ] GitHub Actions 통과

---

## 7. 위험 관리

### 7.1 위험 요소

| 위험 | 영향도 | 완화 전략 |
|------|--------|-----------|
| Hook 복잡성 | 높음 | 단순 Hook부터 시작, 점진적 확장 |
| 에이전트 조율 | 중간 | 각 에이전트 독립 테스트 우선 |
| 상태 관리 | 높음 | JSON 스키마 엄격 검증 |
| Shell 호환성 | 중간 | macOS, Linux 모두 테스트 |
| 설치 실패 | 높음 | install.sh 멱등성 보장 |

### 7.2 성공 지표

| 지표 | 목표 | 측정 |
|------|------|------|
| 테스트 커버리지 | 80%+ | Verification Loop 리포트 |
| TDD 준수율 | 100% | 모든 [IMPL] 앞에 [TEST] |
| 설치 성공률 | 100% | Clean install 테스트 |
| 문서 완성도 | 100% | 모든 명령어 문서화 |

---

## 참조 문서

1. **마스터 설계서**: `CLAUDE_ORCHESTRA_IMPLEMENTATION.md`
2. **Everything Claude Code 분석**: `docs/everything-claude-code-analysis.md`
3. **Oh-My-OpenCode 분석**: `docs/oh-my-opencode-analysis.md`

---

*작성: Claude Opus 4.5*
*최종 수정: 2026-01-25*
