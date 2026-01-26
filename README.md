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

### 🚀 Plugin Marketplace (권장)

```bash
# Claude Code에서 실행
/plugin marketplace add picpal/claude-orchestra
/plugin install claude-orchestra@claude-orchestra
```

### 📦 Clone + Install

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
/plugin marketplace add picpal/claude-orchestra
/plugin install claude-orchestra@claude-orchestra
```

**설치 Scope 선택:**

`/plugin install` 실행 시 설치 범위를 선택합니다:

| Scope | 설명 | 저장 위치 | 적용 범위 |
|-------|------|----------|----------|
| **User scope** | 사용자 전체에 설치 | `~/.claude/` | 이 PC의 모든 프로젝트 |
| **Project scope** | 프로젝트에 설치 (Git 커밋 가능) | `프로젝트/.claude/` | 팀원과 공유됨 |
| **Local scope** | 프로젝트 로컬 설치 (Git 제외) | `프로젝트/.claude/` | 이 PC, 이 프로젝트만 |

> **추천:** 혼자 사용 → User scope / 팀 프로젝트 → Project scope

또는 `~/.claude/settings.json`에 직접 추가:

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

# .claude 컴포넌트 복사
mkdir -p /path/to/your/project/.claude
cp -r agents commands rules contexts hooks /path/to/your/project/.claude/
cp .claude/settings.json /path/to/your/project/.claude/

# .orchestra 상태 파일 복사
mkdir -p /path/to/your/project/.orchestra/{plans,notepads,logs}
cp orchestra-init/*.json /path/to/your/project/.orchestra/
```

---

## 설치되는 컴포넌트

| 카테고리 | 개수 | 경로 | 설명 |
|----------|------|------|------|
| **Agents** | 12 | `.claude/agents/` | AI 에이전트 정의 |
| **Commands** | 11 | `.claude/commands/` | 슬래시 명령어 |
| **Rules** | 6 | `.claude/rules/` | 코드 규칙 |
| **Contexts** | 3 | `.claude/contexts/` | 작업 컨텍스트 |
| **Hooks** | 15 | `.claude/hooks/` | 자동화 훅 스크립트 |
| **Settings** | 1 | `.claude/settings.json` | 에이전트 설정 |
| **Orchestra** | 2+ | `.orchestra/` | 상태 관리 파일 |

---

## 사용법

### 기본 명령어

| 명령어 | 설명 |
|--------|------|
| `/start-work` | 작업 세션 시작, 상태 초기화 |
| `/status` | 현재 상태, 진행 중인 작업 확인 |
| `/tdd-cycle` | TDD 사이클 가이드 표시 |
| `/verify` | 검증 루프 실행 |
| `/code-review` | 코드 리뷰 실행 |
| `/learn` | 세션에서 패턴 학습 |
| `/checkpoint` | 현재 상태 체크포인트 저장 |

### 검증 모드

```bash
/verify quick     # 빌드 + 타입 (빠른 확인)
/verify standard  # 빌드 + 타입 + 린트 + 테스트
/verify full      # 전체 6단계
/verify pre-pr    # PR 제출 전 (보안 강화)
```

### 컨텍스트 모드

```bash
/context dev      # 개발 모드 - 코드 작성 집중
/context research # 연구 모드 - 탐색/분석 집중
/context review   # 리뷰 모드 - 품질 검증 집중
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

### 설치 후 프로젝트 구조

```
your-project/
├── .claude/                    # Claude Code 인식 디렉토리
│   ├── agents/                 # 12개 에이전트
│   │   ├── maestro.md
│   │   ├── planner.md
│   │   ├── interviewer.md
│   │   └── ...
│   ├── commands/               # 11개 슬래시 명령어
│   │   ├── start-work.md
│   │   ├── verify.md
│   │   └── ...
│   ├── rules/                  # 6개 코드 규칙
│   │   ├── security.md
│   │   ├── testing.md
│   │   └── ...
│   ├── contexts/               # 3개 컨텍스트
│   │   ├── dev.md
│   │   ├── research.md
│   │   └── review.md
│   ├── hooks/                  # 15개 자동화 훅
│   │   ├── tdd-guard.sh
│   │   ├── test-logger.sh
│   │   ├── verification/       # 6단계 검증 스크립트
│   │   ├── learning/           # 패턴 학습 시스템
│   │   └── compact/            # 컨텍스트 압축
│   └── settings.json           # 에이전트/권한 설정
│
├── .orchestra/                 # 상태/데이터 디렉토리
│   ├── config.json             # 프로젝트 설정
│   ├── state.json              # 런타임 상태
│   ├── plans/                  # 계획 문서 저장
│   ├── notepads/               # 작업 노트
│   └── logs/                   # 세션 로그
```

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
