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
| `list` | 저장된 패턴 목록 보기 |
| `evaluate` | 현재 세션 평가 (수동) |
| `add` | 수동으로 패턴 추가 |
| `clear` | 모든 패턴 삭제 |

## 실행

```bash
# 패턴 목록 보기
.orchestra/hooks/learning/evaluate-session.sh list

# 세션 평가 (자동으로 Stop 훅에서 실행됨)
.orchestra/hooks/learning/evaluate-session.sh evaluate

# 수동 패턴 추가
.orchestra/hooks/learning/evaluate-session.sh add project_specific "Custom Pattern"

# 패턴 초기화
.orchestra/hooks/learning/evaluate-session.sh clear
```

## 패턴 카테고리

| Category | 설명 | 우선순위 |
|----------|------|----------|
| `error_resolution` | 에러 해결 패턴 | High |
| `user_corrections` | 사용자 수정 요청 패턴 | High |
| `project_specific` | 프로젝트 특화 패턴 | High |
| `workarounds` | 우회 해결책 | Medium |
| `debugging_techniques` | 디버깅 기법 | Medium |
| `best_practices` | 모범 사례 | Low |

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

## 자동 추출

세션 종료 시 다음 패턴을 자동으로 감지:

### 에러 해결 패턴
- TypeScript 에러 (TS2532, TS2339 등)
- React Hook 경고
- 빌드/컴파일 에러

### 사용자 수정 패턴
- "아니", "다시", "수정해" 등의 키워드 감지
- 반복적인 수정 요청

### 우회 해결책
- "대신", "우회", "임시" 등의 키워드 감지

## 설정

`.orchestra/hooks/learning/config.json`:

```json
{
  "enabled": true,
  "minSessionLength": 10,
  "autoApprove": false,
  "extractionRules": {
    "minOccurrences": 2,
    "confidenceThreshold": 0.7,
    "maxPatternsPerSession": 5
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

## Plan-Reviewer 연동

Plan-Reviewer는 저장된 패턴을 참조하여:
- 이전에 발생한 이슈 경고
- 반복되는 실수 패턴 식별
- 프로젝트 특화 규칙 적용

## 저장 위치

```
.orchestra/hooks/learning/
├── config.json           # 학습 설정
├── evaluate-session.sh   # 평가 스크립트
└── learned-patterns/     # 패턴 저장소
    ├── error_resolution-*.md
    ├── user_corrections-*.md
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
