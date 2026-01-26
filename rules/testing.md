# Testing Rules

테스트 관련 규칙입니다. TDD 원칙을 준수합니다.

## 커버리지 요구사항

| 코드 유형 | 최소 커버리지 |
|-----------|---------------|
| 일반 코드 | 80% |
| 금융/결제 로직 | 100% |
| 인증/보안 로직 | 100% |
| 핵심 비즈니스 로직 | 100% |

## TDD 워크플로우

```
1. RED   - 실패하는 테스트 작성
     ↓
2. GREEN - 테스트 통과하는 최소 구현
     ↓
3. REFACTOR - 코드 개선 (테스트 유지)
     ↓
   다음 기능으로 반복
```

## 테스트 유형

### Unit Tests
- 격리된 함수/컴포넌트
- 외부 의존성 모킹
- 빠른 실행 (< 1초)

```typescript
describe('calculateTotal', () => {
  it('should calculate sum correctly', () => {
    expect(calculateTotal([10, 20, 30])).toBe(60);
  });

  it('should return 0 for empty array', () => {
    expect(calculateTotal([])).toBe(0);
  });
});
```

### Integration Tests
- API/DB 작업
- 여러 모듈 상호작용
- 테스트 DB 사용

```typescript
describe('UserService', () => {
  beforeAll(async () => {
    await db.connect();
  });

  afterAll(async () => {
    await db.disconnect();
  });

  it('should create and retrieve user', async () => {
    const user = await userService.create({ email: 'test@example.com' });
    const found = await userService.findById(user.id);
    expect(found.email).toBe('test@example.com');
  });
});
```

### E2E Tests
- 사용자 플로우
- Playwright/Cypress 사용
- 실제 브라우저 환경

```typescript
test('login flow', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'user@example.com');
  await page.fill('[data-testid="password"]', 'password123');
  await page.click('[data-testid="submit"]');
  await expect(page).toHaveURL('/dashboard');
});
```

## 테스트 작성 규칙

### 명명 규칙
```typescript
// describe: 테스트 대상
describe('UserService', () => {
  // it/test: should + expected behavior + when + condition
  it('should return null when user not found', () => {});
  it('should throw error when email is invalid', () => {});
});
```

### AAA 패턴
```typescript
it('should calculate discount correctly', () => {
  // Arrange - 준비
  const price = 100;
  const discountRate = 0.2;

  // Act - 실행
  const result = calculateDiscount(price, discountRate);

  // Assert - 검증
  expect(result).toBe(80);
});
```

### 엣지 케이스 필수
```typescript
describe('divide', () => {
  it('should divide two numbers', () => {
    expect(divide(10, 2)).toBe(5);
  });

  // 엣지 케이스
  it('should throw error when dividing by zero', () => {
    expect(() => divide(10, 0)).toThrow('Division by zero');
  });

  it('should handle negative numbers', () => {
    expect(divide(-10, 2)).toBe(-5);
  });

  it('should handle decimal results', () => {
    expect(divide(10, 3)).toBeCloseTo(3.33, 2);
  });
});
```

## 금지 사항

### 테스트 삭제 금지
```typescript
// ❌ 금지
// describe.skip('...')
// it.skip('...')
// test.skip('...')
```

### 빈 테스트 금지
```typescript
// ❌ 금지
it('should work', () => {});
it.todo('implement later');
```

### 비결정적 테스트 금지
```typescript
// ❌ 금지 - 시간 의존
it('should expire after 1 hour', async () => {
  await new Promise(r => setTimeout(r, 3600000));
});

// ✅ 좋음 - 시간 모킹
it('should expire after 1 hour', () => {
  jest.useFakeTimers();
  // ...
  jest.advanceTimersByTime(3600000);
  // ...
});
```

## 테스트 실행

```bash
# 전체 테스트
npm test

# 커버리지 포함
npm test -- --coverage

# 특정 파일
npm test -- auth.test.ts

# Watch 모드
npm test -- --watch
```
