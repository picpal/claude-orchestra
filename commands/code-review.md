# /code-review - 코드 리뷰 실행

변경된 코드에 대한 심층 리뷰를 수행합니다.

## 사용법

```
/code-review [target]
```

### Target 옵션

| Target | 설명 |
|--------|------|
| (없음) | 현재 스테이징된 변경사항 |
| `staged` | 스테이징된 변경사항 |
| `unstaged` | 스테이징 안 된 변경사항 |
| `all` | 모든 변경사항 |
| `{file}` | 특정 파일 |
| `{commit}` | 특정 커밋 |

## 리뷰 범위

### 1. Security (Critical)
- 하드코딩된 자격증명
- SQL 인젝션
- XSS 취약점
- 입력 검증 누락
- 안전하지 않은 암호화
- CSRF 방어 누락
- 인증/인가 우회

### 2. Code Quality (High)
- 함수 크기 (50줄 초과)
- 파일 크기 (800줄 초과)
- 중첩 깊이 (3단계 초과)
- 에러 핸들링 누락
- 매직 넘버/스트링
- 미사용 코드
- 중복 코드

### 3. Performance (Medium)
- 알고리즘 복잡도 (O(n²) 이상)
- React 불필요 리렌더링
- N+1 쿼리 패턴
- 메모리 누수 패턴

### 4. Best Practices (Low)
- 네이밍 컨벤션
- 문서화 누락
- 접근성 (a11y)
- 테스트 커버리지

### 5. TDD Compliance (High)
- 테스트 없는 구현 코드 (Missing Test)
- 테스트 삭제 (Deleted Test) - Critical
- 테스트 스킵 (`.skip()`, `xit`)
- 구현 후 테스트 작성 (TDD 순서 위반)
- 리팩토링 후 테스트 미검증

## 결과 예시

```
╔═══════════════════════════════════════════════════════════════╗
║                   CODE REVIEW REPORT                           ║
╠═══════════════════════════════════════════════════════════════╣
║  Files Reviewed:  5                                            ║
║  Lines Changed:   +120 / -45                                   ║
║  Result:          ⚠️ Warning                                   ║
║  Issues:          0 Critical, 0 High, 3 Medium, 2 Low         ║
╚═══════════════════════════════════════════════════════════════╝

## Issues

### 🟡 Medium

#### [M1] Function Too Long
- File: src/auth/login.ts:45
- Pattern: 67 lines (max: 50)
- Suggestion: Split into smaller functions

#### [M2] Missing Error Handling
- File: src/api/client.ts:23
- Pattern: Unhandled promise rejection
- Suggestion: Add try-catch block

### 🟢 Low

#### [L1] Magic Number
- File: src/utils/pagination.ts:15
- Pattern: Hardcoded `10`
- Suggestion: Extract to constant

### 🔵 TDD Compliance

#### [T1] Missing Test
- File: src/services/userService.ts
- Pattern: 구현 변경, 테스트 없음
- Suggestion: TDD 순서에 따라 테스트 먼저 작성

## Approval Decision
⚠️ Warning - May proceed, but fixes recommended
```

## 승인 레벨

| Status | 조건 | 설명 |
|--------|------|------|
| ✅ Approve | Critical/High 없음 | 커밋 진행 가능 |
| ⚠️ Warning | Medium만 존재 | 수정 권장, 진행 가능 |
| ❌ Block | Critical/High 존재 | 수정 필수 |

## 자동 리뷰

Maestro가 다음 시점에 자동으로 Code-Review Team (5명 병렬) 호출:

1. **TODO 완료 후** (IMPL/REFACTOR 타입)
2. **Verification Loop 통과 후**
3. **PR 제출 전** (`/verify pre-pr`)

## 리뷰 건너뛰기

테스트 파일이나 문서 파일은 일부 검사 제외:

```
# 테스트 파일
- Security: 일부 검사 완화
- Quality: 파일 크기 제한 완화

# 문서 파일 (.md)
- 리뷰 제외
```

## Code-Review Team (5명 병렬)

리뷰는 5명 전문팀이 병렬 수행:
- Security Guardian (Sonnet, w=4) - 보안 취약점
- Quality Inspector (Sonnet, w=3) - 코드 품질
- Performance Analyst (Haiku, w=2) - 성능 이슈
- Standards Keeper (Haiku, w=2) - 표준 준수
- TDD Enforcer (Sonnet, w=4) - TDD 검증

## 관련 명령어

- `/verify` - 검증 루프 실행
- `/status` - 마지막 리뷰 결과 확인
