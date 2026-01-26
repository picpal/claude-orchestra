# /tdd-cycle - TDD 사이클 안내

TDD (Test-Driven Development) 사이클을 안내합니다.

## TDD 3단계 사이클

```
     ┌─────────────┐
     │   START     │
     └──────┬──────┘
            │
            ▼
     ┌─────────────┐
     │    RED      │ ← 1. 실패하는 테스트 작성
     │   (TEST)    │    - 원하는 기능의 테스트 먼저
     └──────┬──────┘    - 아직 구현 없음 → 실패
            │
            ▼
     ┌─────────────┐
     │   GREEN     │ ← 2. 테스트 통과하는 최소 구현
     │   (IMPL)    │    - 테스트만 통과하면 됨
     └──────┬──────┘    - 완벽할 필요 없음
            │
            ▼
     ┌─────────────┐
     │  REFACTOR   │ ← 3. 코드 개선 (테스트 유지)
     │             │    - 중복 제거, 명명 개선
     └──────┬──────┘    - 테스트는 계속 통과해야 함
            │
            └──────────────► 다음 기능으로 반복
```

## 각 단계 상세

### 🔴 RED Phase (테스트 작성)

**목적**: 원하는 기능을 테스트로 정의

```typescript
// 예: 이메일 검증 기능
describe("validateEmail", () => {
  it("should return true for valid email", () => {
    expect(validateEmail("user@example.com")).toBe(true);
  });

  it("should return false for invalid email", () => {
    expect(validateEmail("invalid-email")).toBe(false);
  });
});
```

**체크리스트**:
- [ ] 테스트가 구체적인가?
- [ ] 하나의 동작만 테스트하는가?
- [ ] 테스트 실행 시 실패하는가? (아직 구현 없음)

### 🟢 GREEN Phase (구현)

**목적**: 테스트를 통과하는 최소한의 코드 작성

```typescript
// 최소 구현
function validateEmail(email: string): boolean {
  return email.includes("@") && email.includes(".");
}
```

**체크리스트**:
- [ ] 테스트가 통과하는가?
- [ ] 필요 이상으로 구현하지 않았는가?
- [ ] 하드코딩으로 통과시키지 않았는가?

### 🔵 REFACTOR Phase (개선)

**목적**: 코드 품질 개선 (테스트 유지)

```typescript
// 개선된 구현
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateEmail(email: string): boolean {
  return EMAIL_REGEX.test(email);
}
```

**체크리스트**:
- [ ] 테스트가 여전히 통과하는가?
- [ ] 중복이 제거되었는가?
- [ ] 명명이 명확한가?
- [ ] 불필요한 복잡도가 없는가?

## Orchestra에서의 TDD

### TODO 태그 규칙

```markdown
## TODO List

- [ ] [TEST] 로그인 실패 테스트 (잘못된 비밀번호)
- [ ] [TEST] 로그인 성공 테스트
- [ ] [IMPL] 로그인 API 구현
- [ ] [REFACTOR] 인증 로직 모듈화
```

### 순서 강제

1. `[IMPL]`은 반드시 관련 `[TEST]` 완료 후
2. `[REFACTOR]`는 `[IMPL]` 완료 후
3. 테스트 삭제/스킵 금지

### TDD Guard Hook

테스트 삭제 시도 시 차단:

```
❌ TDD Violation Detected!
테스트 삭제/스킵이 감지되었습니다.

삭제 시도된 테스트:
- tests/auth/login.test.ts: describe("login")

테스트를 삭제하는 대신:
1. 테스트를 수정하세요
2. 구현을 수정하세요
3. 정말 불필요하다면 Planner에게 요청하세요
```

## 자주 묻는 질문

### Q: 테스트를 먼저 작성하기 어려워요
A: 원하는 동작을 "어떻게 확인할 것인가"부터 생각하세요.
   - "이 함수가 뭘 반환해야 하지?"
   - "어떤 입력에 어떤 출력이 나와야 하지?"

### Q: 최소 구현이 뭔가요?
A: 테스트만 통과하면 되는 가장 간단한 코드입니다.
   - 완벽할 필요 없음
   - 나중에 리팩토링

### Q: 언제 리팩토링하나요?
A: GREEN 단계 후, 테스트가 통과하는 상태에서:
   - 중복 코드 발견 시
   - 더 나은 명명이 떠오를 때
   - 코드가 복잡해졌을 때

## 관련 명령어

- `/status` - 현재 TDD 메트릭 확인
- `/verify` - 검증 루프 실행
