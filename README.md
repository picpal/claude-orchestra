# Claude Orchestra 🎼

12개 전문 에이전트 기반 TDD 개발 오케스트레이션 시스템

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue)](https://claude.com/claude-code)

## 개요

Claude Orchestra는 12개의 전문 에이전트가 계층 구조로 협력하여 TDD(Test-Driven Development) 기반의 고품질 코드를 생성하는 오케스트레이션 시스템입니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER INTERACTION LAYER                        │
│                         Maestro (Opus)                           │
├─────────────────────────────────────────────────────────────────┤
│                    PLANNING LAYER                                │
│    Interviewer │ Planner │ Plan-Checker │ Plan-Reviewer         │
├─────────────────────────────────────────────────────────────────┤
│                    RESEARCH LAYER                                │
│    Architecture │ Searcher │ Explorer │ Image-Analyst           │
├─────────────────────────────────────────────────────────────────┤
│                    EXECUTION LAYER                               │
│              High-Player │ Low-Player                            │
├─────────────────────────────────────────────────────────────────┤
│                    REVIEW LAYER                                  │
│                      Code-Reviewer                               │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Plugin Marketplace (권장)

```bash
# Claude Code에서 실행
/plugin marketplace add picpal/claude-orchestra
/plugin install claude-orchestra@claude-orchestra

# 프로젝트 초기화 (rules 복사 + 상태 디렉토리 생성)
/tuning
```

### Clone + Install

```bash
git clone https://github.com/picpal/claude-orchestra.git
cd claude-orchestra
./install.sh /path/to/your/project
```

설치 후 바로 사용:
```bash
/start-work     # 작업 세션 시작
/status         # 현재 상태 확인
```

---

## 주요 기능

### 🧪 TDD 강제
- TEST → IMPL → REFACTOR 사이클 강제
- 테스트 삭제/스킵 방지 Hook
- 최소 80% 커버리지 요구

### ✅ 6단계 검증 루프
1. **Build** - 컴파일 확인
2. **Types** - 타입 안전성
3. **Lint** - 코드 스타일
4. **Tests** - 테스트 + 커버리지
5. **Security** - 보안 스캔
6. **Diff** - 변경사항 검토

### 🤖 스마트 에이전트 선택
- Intent 분류 (TRIVIAL, EXPLORATORY, AMBIGUOUS, OPEN-ENDED)
- 복잡도 기반 Executor 선택 (High/Low Player)

### 📚 연속 학습
- 세션에서 재사용 가능한 패턴 자동 추출
- 학습된 패턴 기반 개선 제안

### 🔍 코드 리뷰
- 25+ 차원 품질 평가
- Security, Quality, Performance 분석

---

## 설치

### 방법 1: Plugin Marketplace (권장) ⭐

Claude Code 터미널에서:

```bash
# Step 1: 플러그인 추가 및 설치
/plugin marketplace add picpal/claude-orchestra
/plugin install claude-orchestra@claude-orchestra

# Step 2: 프로젝트 초기화 (필수!)
/tuning

# Step 3: 작업 시작
/start-work
```


```json
{
  "extraKnownMarketplaces": {
    "claude-orchestra": {
      "source": {
        "source": "github",
        "repo": "picpal/claude-orchestra"
      }
    }
  },
  "enabledPlugins": {
    "claude-orchestra@claude-orchestra": true
  }
}
```

### 방법 2: Clone + Install Script

**Linux / macOS:**
```bash
git clone https://github.com/picpal/claude-orchestra.git
cd claude-orchestra

# 대화형 모드
./install.sh

# 또는 직접 경로 지정
./install.sh /path/to/your/project
```

**Windows:**
```cmd
git clone https://github.com/picpal/claude-orchestra.git
cd claude-orchestra

# 대화형 모드
install.bat

# 또는 직접 경로 지정
install.bat C:\path\to\your\project
```

### 방법 3: 수동 설치

```bash
git clone https://github.com/picpal/claude-orchestra.git
cd claude-orchestra

# 플러그인으로 설치 (권장)
# claude --plugin-dir /path/to/claude-orchestra

# 또는 수동 복사
mkdir -p /path/to/your/project/.claude/rules
cp -r rules/*.md /path/to/your/project/.claude/rules/
```

---

## 설치되는 컴포넌트

| 카테고리 | 개수 | 경로 | 설명 |
|----------|------|------|------|
| **Agents** | 12 | `agents/` | AI 에이전트 정의 |
| **Commands** | 12 | `commands/` | 슬래시 명령어 |
| **Skills** | 3 | `skills/` | 컨텍스트 스킬 (dev, research, review) |
| **Hooks** | 15 | `hooks/` | 자동화 훅 스크립트 + `hooks.json` |
| **Rules** | 6 | `rules/` | 코드 규칙 (`/tuning` 시 프로젝트에 복사) |
| **Settings** | 1 | `.claude/settings.json` | 에이전트/권한 설정 |
| **Orchestra** | 2+ | `.orchestra/` | 상태 관리 파일 (`/tuning` 시 생성) |

---

## 사용법

### 명령어 요약

| 명령어 | 설명 | 사용 시점 |
|--------|------|-----------|
| `/tuning` | Orchestra 초기화 (rules 복사 + 상태 디렉토리 생성) | 최초 1회 |
| `/start-work` | 작업 세션 시작, Intent 분류 | 세션 시작 |
| `/context` | dev / research / review 모드 전환 | 작업 성격 변경 |
| `/tdd-cycle` | TDD RED→GREEN→REFACTOR 가이드 | 개발 중 |
| `/status` | 현재 상태, TODO 진행률, TDD 메트릭 | 수시 확인 |
| `/checkpoint` | 상태 스냅샷 저장 | 리팩토링/실험 전 |
| `/verify` | 6단계 검증 루프 (quick/standard/full/pre-pr) | 커밋/PR 전 |
| `/code-review` | 25+ 차원 코드 리뷰 | 검증 후 |
| `/e2e` | E2E 테스트 실행 (Playwright/Cypress) | 통합 테스트 |
| `/refactor-clean` | 안전한 리팩토링 (테스트 유지) | 코드 정리 |
| `/update-docs` | 코드-문서 동기화 | 코드 변경 후 |
| `/learn` | 세션 패턴 추출/저장 | 세션 종료 |

> 각 명령어의 상세 활용법과 실전 시나리오는 **[명령어 활용 가이드](docs/command-guide.md)**를 참고하세요.

### 컨텍스트 스킬

```bash
/claude-orchestra:context-dev       # 개발 모드 - 코드 작성 집중
/claude-orchestra:context-research  # 연구 모드 - 탐색/분석 집중
/claude-orchestra:context-review    # 리뷰 모드 - 품질 검증 집중
```

---

## 에이전트

| 에이전트 | 모델 | 역할 |
|----------|------|------|
| **Maestro** | Opus | 사용자 대화, Intent 분류, 전체 조율 |
| **Planner** | Opus | TODO 조율, 검증, Git 커밋 |
| **Interviewer** | Opus | 요구사항 인터뷰, 계획 작성 |
| **Plan-Checker** | Sonnet | 계획 분석, 놓친 질문 확인 |
| **Plan-Reviewer** | Sonnet | 계획 검증, TDD 준수 확인 |
| **Architecture** | Opus | 아키텍처 조언, 디버깅 |
| **Searcher** | Sonnet | 외부 문서/API 검색 |
| **Explorer** | Haiku | 내부 코드베이스 검색 |
| **Image-Analyst** | Sonnet | 이미지/스크린샷 분석 |
| **High-Player** | Opus | 복잡한 작업 실행 (3+ 파일) |
| **Low-Player** | Sonnet | 간단한 작업 실행 (1-2 파일) |
| **Code-Reviewer** | Sonnet | 25+ 차원 코드 리뷰 |

---

## 프로젝트 구조

### 플러그인 구조

```
claude-orchestra/               # 플러그인 루트
├── agents/                     # 12개 에이전트
│   ├── maestro.md
│   ├── planner.md
│   ├── interviewer.md
│   └── ...
├── commands/                   # 12개 슬래시 명령어
│   ├── tuning.md
│   ├── start-work.md
│   ├── verify.md
│   └── ...
├── skills/                     # 3개 컨텍스트 스킬
│   ├── context-dev/SKILL.md
│   ├── context-research/SKILL.md
│   └── context-review/SKILL.md
├── hooks/                      # 자동화 훅
│   ├── hooks.json              # 플러그인 hooks 설정
│   ├── tdd-guard.sh
│   ├── test-logger.sh
│   ├── agent-logger.sh
│   ├── user-prompt-submit.sh
│   ├── verification/           # 6단계 검증 스크립트
│   ├── learning/               # 패턴 학습 시스템
│   └── compact/                # 컨텍스트 압축
├── rules/                      # 6개 코드 규칙 (/tuning 시 프로젝트에 복사)
│   ├── security.md
│   ├── testing.md
│   └── ...
├── contexts/                   # (호환용) 컨텍스트 파일
├── .claude/
│   └── settings.json           # 에이전트/권한 설정
└── CLAUDE.md                   # 프로젝트 안내
```

### /tuning 후 프로젝트 구조

```
your-project/
├── .claude/
│   └── rules/                  # Orchestra 규칙 (플러그인에서 복사됨)
│       ├── security.md
│       ├── testing.md
│       └── ...
├── .orchestra/                 # 상태/데이터 디렉토리
│   ├── config.json             # 프로젝트 설정
│   ├── state.json              # 런타임 상태
│   ├── plans/                  # 계획 문서 저장
│   ├── journal/                # 작업 일지 (아래 참조)
│   └── logs/                   # 시스템 로그 (아래 참조)
```

#### logs/ vs journal/ 차이점

| 디렉토리 | 용도 | 생성 주체 | 형식 |
|----------|------|-----------|------|
| `logs/` | 시스템 자동 로그 | Hook/스크립트 | `.log`, `.json` |
| `journal/` | 작업 일지 | 에이전트 | `.md` (마크다운) |

**logs/** - 자동화 스크립트가 생성하는 기계용 로그
- `test-runs.log` - 테스트 실행 기록
- `verification-*.json` - 검증 결과 (build, types, lint, tests, security)
- `tdd-guard.log` - TDD 가드 로그

**journal/** - 에이전트가 작성하는 사람용 작업 일지
- `{session-id}/notes.md` - 진행상황, 결정사항, 이슈, 질문 기록

---


## 제거

### Marketplace 설치 제거

```bash
/plugin uninstall claude-orchestra@claude-orchestra
```

---

## 기여

이슈와 PR을 환영합니다!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 문의

- **Issues**: https://github.com/picpal/claude-orchestra/issues
- **Discussions**: https://github.com/picpal/claude-orchestra/discussions
