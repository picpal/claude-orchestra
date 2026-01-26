# /init - Orchestra 초기화

플러그인으로 설치한 경우, Orchestra 컴포넌트를 현재 프로젝트에 복사합니다.

## 왜 필요한가?

Claude Code의 에이전트 로딩 우선순위:
1. CLI 플래그 (`--agents`)
2. **프로젝트 레벨** (`.claude/agents/`) ← 여기에 있어야 작동
3. 사용자 레벨 (`~/.claude/agents/`)
4. 플러그인 레벨 ← 가장 낮은 우선순위, 서브에이전트 호출 불가

플러그인으로 설치하면 플러그인 캐시에만 저장되어 서브에이전트 기능이 작동하지 않습니다.
`/init`을 실행하면 프로젝트 레벨로 컴포넌트를 복사하여 모든 기능을 사용할 수 있습니다.

## 실행 절차

### 1. 플러그인 캐시 확인

플러그인 캐시에서 claude-orchestra 경로를 찾습니다:

| OS | 플러그인 캐시 경로 |
|----|--------------------|
| macOS/Linux | `~/.claude/plugins/cache/` |
| Windows | `%USERPROFILE%\.claude\plugins\cache\` |

캐시 내 Orchestra 경로 패턴:
```
~/.claude/plugins/cache/claude-orchestra/
└── claude-orchestra@*/     # 버전별 디렉토리
    ├── agents/
    ├── commands/
    ├── rules/
    ├── contexts/
    ├── hooks/
    └── .claude/settings.json
```

### 2. 중복 확인

프로젝트에 이미 `.claude/agents/`가 있는지 확인합니다.

**이미 존재하는 경우:**
```
⚠️ 이미 .claude/agents/ 폴더가 존재합니다.

현재 에이전트: {기존 에이전트 수}개
Orchestra 에이전트: 12개

기존 설정을 덮어쓰시겠습니까?
[Yes] - 기존 파일 덮어쓰기
[No] - 취소
[Merge] - 충돌 없는 파일만 복사
```

사용자 선택에 따라 진행합니다.

### 3. 컴포넌트 복사

다음 항목들을 프로젝트로 복사:

| 소스 (플러그인 캐시) | 대상 (프로젝트) | 설명 |
|---------------------|----------------|------|
| `agents/` | `.claude/agents/` | 12개 에이전트 |
| `commands/` | `.claude/commands/` | 12개 슬래시 명령어 |
| `rules/` | `.claude/rules/` | 6개 코드 규칙 |
| `contexts/` | `.claude/contexts/` | 3개 컨텍스트 |
| `hooks/` | `.claude/hooks/` | 15개 자동화 훅 |
| `.claude/settings.json` | `.claude/settings.json` | 에이전트 설정 |

```bash
# 대상 디렉토리 생성
mkdir -p .claude

# 컴포넌트 복사
cp -r {cache}/agents .claude/
cp -r {cache}/commands .claude/
cp -r {cache}/rules .claude/
cp -r {cache}/contexts .claude/
cp -r {cache}/hooks .claude/
cp {cache}/.claude/settings.json .claude/
```

### 4. .orchestra 디렉토리 생성

`.orchestra/` 상태 디렉토리 구조 생성:

```bash
mkdir -p .orchestra/plans
mkdir -p .orchestra/journal
mkdir -p .orchestra/logs
mkdir -p .orchestra/mcp-configs
mkdir -p .orchestra/templates
```

**config.json 생성:**
```json
{
  "projectName": "",
  "language": "auto-detect",
  "testFramework": "auto-detect",
  "coverageThreshold": 80,
  "autoCommit": false,
  "verificationMode": "standard"
}
```

**state.json 생성:**
```json
{
  "mode": "IDLE",
  "currentContext": "dev",
  "currentPlan": null,
  "todos": [],
  "tddMetrics": {
    "testCount": 0,
    "redGreenCycles": 0,
    "testDeletionAttempts": 0
  },
  "commitHistory": [],
  "verificationMetrics": {
    "lastRun": null,
    "mode": null,
    "results": {},
    "prReady": false,
    "blockers": []
  },
  "learningMetrics": {
    "totalSessions": 0,
    "patternsExtracted": 0,
    "lastLearningRun": null
  }
}
```

### 5. Hook 실행 권한 부여

```bash
chmod +x .claude/hooks/*.sh
chmod +x .claude/hooks/**/*.sh
```

### 6. 완료 메시지

```
✅ Orchestra 초기화 완료!

설치된 컴포넌트:
┌──────────────┬──────┬────────────────────────┐
│ 카테고리     │ 개수 │ 경로                   │
├──────────────┼──────┼────────────────────────┤
│ Agents       │ 12   │ .claude/agents/        │
│ Commands     │ 12   │ .claude/commands/      │
│ Rules        │ 6    │ .claude/rules/         │
│ Contexts     │ 3    │ .claude/contexts/      │
│ Hooks        │ 15   │ .claude/hooks/         │
│ Settings     │ 1    │ .claude/settings.json  │
│ Orchestra    │ 2    │ .orchestra/            │
└──────────────┴──────┴────────────────────────┘

다음 단계: /start-work 실행
```

## 에러 처리

### 플러그인 캐시를 찾을 수 없음

```
❌ Orchestra 플러그인을 찾을 수 없습니다.

다음을 확인하세요:
1. 플러그인이 설치되어 있는지 확인
   /plugin list

2. 플러그인 설치
   /plugin marketplace add picpal/claude-orchestra
   /plugin install claude-orchestra@claude-orchestra

3. 다시 /init 실행
```

### 권한 오류

```
❌ 파일 복사 권한이 없습니다.

프로젝트 디렉토리 쓰기 권한을 확인하세요:
ls -la .
```

## 대안: 직접 설치

플러그인 없이 직접 설치하려면:

```bash
git clone https://github.com/picpal/claude-orchestra.git
cd claude-orchestra
./install.sh /path/to/your/project
```

## 관련 명령어

- `/start-work` - 작업 세션 시작
- `/status` - 현재 상태 확인
- `/agents` - 설치된 에이전트 확인
