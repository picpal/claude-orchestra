# /checkpoint - 상태 스냅샷

현재 Orchestra 상태의 스냅샷을 저장합니다.

## 사용법

```
/checkpoint [name] [description]
```

### 인자

| 인자 | 설명 | 기본값 |
|------|------|--------|
| `name` | 체크포인트 이름 | `checkpoint-{timestamp}` |
| `description` | 설명 | 빈 문자열 |

## 기능

### 저장 항목
- 현재 모드 (IDLE, PLAN, EXECUTE, REVIEW)
- 활성 계획 정보
- TODO 목록 및 상태
- TDD 메트릭
- 커밋 히스토리
- 검증 결과

### 예시

```bash
# 기본 체크포인트 생성
/checkpoint

# 이름 지정
/checkpoint before-refactor

# 이름과 설명 지정
/checkpoint auth-complete "인증 기능 구현 완료"
```

## 체크포인트 구조

```json
{
  "id": "cp-20260126-120000",
  "name": "before-refactor",
  "createdAt": "2026-01-26T12:00:00Z",
  "description": "리팩토링 전 상태",
  "stateSnapshot": {
    "mode": "EXECUTE",
    "currentPlan": {...},
    "todos": [...],
    "tddMetrics": {...},
    "verificationMetrics": {...}
  }
}
```

## 저장 위치

```
.orchestra/state.json → checkpoints[]
```

## 사용 시나리오

### 1. 리팩토링 전
```
/checkpoint before-refactor "대규모 리팩토링 전 백업"
```

### 2. 기능 완료 시
```
/checkpoint auth-complete "인증 기능 구현 완료"
```

### 3. 실험 전
```
/checkpoint experiment-baseline "새로운 접근 방식 시도 전"
```

## 체크포인트 목록 보기

```
/status checkpoints
```

## 제한사항

- 최대 10개 체크포인트 저장
- 오래된 체크포인트 자동 삭제
- 파일 내용은 저장하지 않음 (Git 사용)

## 관련 명령어

- `/status` - 현재 상태 확인
- `/verify` - 검증 루프 실행
