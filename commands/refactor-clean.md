# /refactor-clean - 리팩토링 모드

코드 리팩토링을 안전하게 수행합니다.

## 사용법

```
/refactor-clean [target]
```

### Target 옵션

| Target | 설명 |
|--------|------|
| (없음) | 전체 코드베이스 분석 |
| `{file}` | 특정 파일 리팩토링 |
| `{directory}` | 특정 디렉토리 리팩토링 |

## 리팩토링 모드 특징

### 1. 안전 장치
- 테스트 통과 필수 (리팩토링 전/후)
- 기능 변경 금지
- 자동 롤백 지원

### 2. 리팩토링 유형

| 유형 | 설명 |
|------|------|
| Extract Function | 함수 추출 |
| Inline Function | 함수 인라인 |
| Rename | 이름 변경 |
| Move | 위치 이동 |
| Extract Variable | 변수 추출 |
| Remove Dead Code | 미사용 코드 제거 |

## 워크플로우

```
/refactor-clean
    │
    ▼
[1. 테스트 실행]
    │ 모든 테스트 통과 확인
    │
    ▼
[2. 코드 분석]
    │ 리팩토링 대상 식별
    │ - 긴 함수
    │ - 중복 코드
    │ - 복잡한 조건문
    │
    ▼
[3. 리팩토링 계획]
    │ 변경 사항 미리보기
    │
    ▼
[4. 리팩토링 실행]
    │ 단계별 진행
    │ 각 단계 후 테스트
    │
    ▼
[5. 검증]
    │ 전체 테스트 재실행
    │ 동작 변경 없음 확인
    │
    ▼
✅ 완료
```

## 분석 결과 예시

```
╔═══════════════════════════════════════════════════════════════╗
║                   REFACTORING ANALYSIS                         ║
╠═══════════════════════════════════════════════════════════════╣
║  Files Analyzed:  25                                           ║
║  Issues Found:    8                                            ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                ║
║  🔴 High Priority (3)                                         ║
║  ────────────────────                                         ║
║  1. src/auth/login.ts:45                                      ║
║     → Function too long (67 lines)                            ║
║     Suggestion: Extract to 3 functions                        ║
║                                                                ║
║  2. src/utils/helpers.ts                                      ║
║     → Duplicate code with src/utils/format.ts                 ║
║     Suggestion: Extract shared utility                        ║
║                                                                ║
║  3. src/api/client.ts:120-180                                 ║
║     → Complex nested conditions                               ║
║     Suggestion: Use early returns                             ║
║                                                                ║
║  🟡 Medium Priority (3)                                       ║
║  ─────────────────────                                        ║
║  4-6. See details below...                                    ║
║                                                                ║
║  🟢 Low Priority (2)                                          ║
║  ──────────────────                                           ║
║  7-8. See details below...                                    ║
╚═══════════════════════════════════════════════════════════════╝

Proceed with refactoring? (y/n)
```

## 리팩토링 규칙

### DO
- ✅ 테스트 먼저 확인
- ✅ 작은 단위로 진행
- ✅ 각 단계 후 테스트
- ✅ 의미 있는 커밋

### DON'T
- ❌ 기능 변경
- ❌ 테스트 없이 리팩토링
- ❌ 여러 리팩토링 동시 진행
- ❌ 테스트 삭제

## 자동 탐지 패턴

### 긴 함수
```typescript
// 50줄 이상 함수 감지
function handleSubmit() {
  // ... 67 lines
}
```

### 중복 코드
```typescript
// 유사 코드 블록 감지
// File A
const result = data.map(x => x.value).filter(x => x > 0);

// File B (중복)
const filtered = items.map(i => i.value).filter(i => i > 0);
```

### 복잡한 조건
```typescript
// 깊은 중첩 감지
if (a) {
  if (b) {
    if (c) {
      // ...
    }
  }
}
```

## 관련 명령어

- `/verify` - 리팩토링 후 검증
- `/code-review` - 변경사항 리뷰
- `/tdd-cycle` - TDD 사이클 안내
