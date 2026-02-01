# /learn - 연속 학습 시스템

세션에서 재사용 가능한 패턴을 추출하고 관리합니다.

## 개요

Continuous Learning 시스템은 개발 세션에서 발생하는 패턴을 자동으로 감지하고 저장하여, 이후 세션에서 동일한 문제를 더 빠르게 해결할 수 있도록 합니다.

## 사용법

```
/learn [command]
```

### Commands

| Command | 설명 |
|---------|------|
| `list` | 저장된 패턴 목록 보기 (Usage Count 포함) |
| `evaluate` | 현재 세션 평가 (수동) |
| `add` | 수동으로 패턴 추가 (카테고리, 제목, 문제, 해결책, 키워드 지정 가능) |
| `clear` | 모든 패턴 삭제 |

## 실행

```bash
# 플러그인에서 실행
${CLAUDE_PLUGIN_ROOT}/hooks/learning/evaluate-session.sh list
${CLAUDE_PLUGIN_ROOT}/hooks/learning/evaluate-session.sh evaluate

# 수동 패턴 추가 (전체 인자)
${CLAUDE_PLUGIN_ROOT}/hooks/learning/evaluate-session.sh add project_specific "Custom Pattern" "문제 설명" "해결 방법" "keyword1, keyword2"

# 패턴 초기화
${CLAUDE_PLUGIN_ROOT}/hooks/learning/evaluate-session.sh clear
```

## 자동 분석 대상 로그

| 로그 파일 | 용도 |
|-----------|------|
| `.orchestra/logs/activity.log` | 에이전트 활동, 에러, 반복 편집 감지 |
| `.orchestra/logs/test-runs.log` | 테스트 실행 결과, 연속 실패 감지 |
| `.orchestra/logs/tdd-guard.log` | TDD 규칙 위반 감지 |

## 패턴 카테고리

| Category | 설명 | 감지 방법 |
|----------|------|-----------|
| `error_resolution` | 에러 해결 패턴 | config.json `errorResolved` trigger로 에러 라인 필터 → 에러 코드 2회+ 등장 시 생성 |
| `user_corrections` | 사용자 수정 요청 패턴 | EXECUTE phase에서 같은 파일 3회+ 편집 감지 |
| `workarounds` | 우회 해결책 | config.json `workaround` trigger 매칭 2회+ |
| `debugging_techniques` | 디버깅 기법 | 연속 3회+ 테스트 실패 감지 |
| `best_practices` | 모범 사례 | TDD guard 위반 2회+ 감지 |
| `project_specific` | 프로젝트 특화 패턴 | 수동 추가 (`add` 명령) |

## 중복 검사

패턴 생성 시 기존 패턴의 Trigger Keywords와 **Jaccard similarity**를 계산합니다.

- **유사도 ≥ 0.5**: 기존 패턴의 Usage Count를 증가시키고 Last Used를 갱신 (새 파일 생성하지 않음)
- **유사도 < 0.5**: 새 패턴 파일 생성

이를 통해 동일한 패턴이 반복 생성되는 문제를 방지합니다.

## 패턴 파일 형식

```markdown
# Pattern: TypeScript Null Check

## ID
error_resolution-20260126120000-a1b2c3d4

## Category
error_resolution

## Created
2026-01-26T12:00:00Z

## Problem
'Object is possibly undefined' 에러 발생

## Solution
Optional chaining (?.) 또는 nullish coalescing (??) 연산자 사용

## Code Example
```typescript
// Before
const name = user.profile.name;

// After
const name = user?.profile?.name ?? 'Unknown';
```

## Trigger Keywords
TS2532, Object is possibly, undefined, null check

## Usage Count
3

## Last Used
2026-01-26T15:30:00Z
```

## 설정

`${CLAUDE_PLUGIN_ROOT}/hooks/learning/config.json`:

```json
{
  "enabled": true,
  "minSessionLength": 10,
  "autoApprove": false,
  "extractionRules": {
    "minOccurrences": 2,
    "confidenceThreshold": 0.7,
    "maxPatternsPerSession": 5
  },
  "triggers": {
    "errorResolved": {
      "enabled": true,
      "pattern": "에러|error|fail|exception"
    },
    "workaround": {
      "enabled": true,
      "pattern": "대신|우회|임시|workaround"
    }
  }
}
```

### 설정 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `enabled` | 학습 활성화 | `true` |
| `minSessionLength` | 최소 세션 길이 (메시지 수) | `10` |
| `autoApprove` | 자동 패턴 승인 | `false` |
| `maxPatternsPerSession` | 세션당 최대 패턴 수 | `5` |
| `triggers.*.enabled` | 개별 trigger 활성화 | `true` |
| `triggers.*.pattern` | 감지용 정규식 | (카테고리별 상이) |

## Plan-Reviewer 연동

Plan-Reviewer는 저장된 패턴을 참조하여:
- 이전에 발생한 이슈 경고
- 반복되는 실수 패턴 식별
- 프로젝트 특화 규칙 적용

## 저장 위치

```
# 사용자 프로젝트 (.orchestra/learning이 있으면 우선 사용)
.orchestra/
├── learning/
│   └── learned-patterns/      # 프로젝트별 패턴 저장
└── logs/
    └── learning.log           # 실행 로그

# 플러그인 (fallback)
${CLAUDE_PLUGIN_ROOT}/hooks/learning/
├── config.json            # 학습 설정 (trigger 정규식 포함)
├── evaluate-session.sh    # 평가 스크립트 (Python 분석기 호출)
├── analyze-session.py     # Python 분석 엔진
└── learned-patterns/      # 패턴 저장소 (fallback)
    ├── error_resolution-*.md
    ├── user_corrections-*.md
    ├── workarounds-*.md
    ├── debugging_techniques-*.md
    ├── best_practices-*.md
    └── project_specific-*.md
```

## 메트릭

`state.json`에서 확인:

```json
{
  "learningMetrics": {
    "totalSessions": 15,
    "patternsExtracted": 23,
    "lastLearningRun": "2026-01-26T12:00:00Z",
    "activePatterns": ["pattern-id-1", "pattern-id-2"],
    "recentPatterns": [...]
  }
}
```

## 제외 항목

다음은 패턴으로 추출하지 않음:
- 단순 오타 수정
- 일회성 수정
- 외부 API 이슈
- 임시 우회책
- 개인 취향 관련

## 관련 명령어

- `/status` - 학습 메트릭 확인
- `/verify` - 검증 루프 실행
