# /e2e - E2E 테스트 실행

End-to-End 테스트를 실행합니다.

## 사용법

```
/e2e [options]
```

### 옵션

| 옵션 | 설명 |
|------|------|
| (없음) | 전체 E2E 테스트 실행 |
| `--headed` | 브라우저 UI 표시 |
| `--debug` | 디버그 모드 |
| `{spec}` | 특정 스펙 파일 실행 |

## 지원 프레임워크

### Playwright (권장)
```bash
npx playwright test
npx playwright test --headed
npx playwright test tests/auth.spec.ts
```

### Cypress
```bash
npx cypress run
npx cypress open
npx cypress run --spec "cypress/e2e/auth.cy.ts"
```

## 실행 예시

```bash
# 전체 E2E 테스트
/e2e

# 브라우저 표시
/e2e --headed

# 특정 테스트
/e2e tests/auth.spec.ts

# 디버그 모드
/e2e --debug
```

## 결과 출력

```
╔═══════════════════════════════════════════════════════════════╗
║                   E2E TEST RESULTS                             ║
╠═══════════════════════════════════════════════════════════════╣
║  Framework:  Playwright                                        ║
║  Duration:   45.2s                                             ║
║  Tests:      12 passed, 0 failed, 1 skipped                   ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ auth.spec.ts                              (8.2s)          ║
║     ✅ should login with valid credentials                    ║
║     ✅ should show error for invalid password                 ║
║     ✅ should logout successfully                             ║
║  ✅ dashboard.spec.ts                         (12.5s)         ║
║     ✅ should load dashboard                                  ║
║     ✅ should display user stats                              ║
║  ✅ checkout.spec.ts                          (24.5s)         ║
║     ✅ should complete purchase flow                          ║
╚═══════════════════════════════════════════════════════════════╝
```

## 실패 시

```
❌ E2E Test Failed

Failed Test: checkout.spec.ts
  ✗ should complete purchase flow
    Error: Timeout waiting for element '.submit-button'
    at tests/checkout.spec.ts:45:12

Screenshot: test-results/checkout-failed.png
Trace: test-results/checkout-trace.zip

Suggestions:
1. 요소 셀렉터 확인
2. 네트워크 지연 고려
3. --debug 모드로 재실행
```

## 설정

`playwright.config.ts` 또는 `cypress.config.ts`에서 설정

### Playwright 예시
```typescript
export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 2,
  use: {
    baseURL: 'http://localhost:3000',
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },
});
```

## 모범 사례

1. **선택자**: data-testid 사용
```html
<button data-testid="submit-btn">Submit</button>
```

2. **대기**: 명시적 대기 사용
```typescript
await page.waitForSelector('[data-testid="result"]');
```

3. **격리**: 테스트 간 독립성 유지
```typescript
test.beforeEach(async ({ page }) => {
  await page.goto('/');
});
```

## 관련 명령어

- `/verify` - 검증 루프 (E2E 포함 가능)
- `/status` - 테스트 결과 확인
