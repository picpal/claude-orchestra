# /update-docs - 문서 동기화

코드 변경에 따라 문서를 업데이트합니다.

## 사용법

```
/update-docs [scope]
```

### Scope 옵션

| Scope | 설명 |
|-------|------|
| (없음) | 전체 문서 검사 |
| `api` | API 문서만 |
| `readme` | README만 |
| `comments` | 코드 주석만 |
| `{file}` | 특정 파일 |

## 검사 항목

### 1. README.md
- 설치 방법
- 사용 예시
- API 레퍼런스
- 환경 변수

### 2. API 문서
- 엔드포인트 목록
- 요청/응답 형식
- 에러 코드

### 3. 코드 주석
- JSDoc/TSDoc
- 함수 설명
- 파라미터 타입

### 4. CHANGELOG
- 버전 변경사항
- Breaking changes

## 워크플로우

```
/update-docs
    │
    ▼
[1. 변경 파일 분석]
    │ git diff로 변경사항 확인
    │
    ▼
[2. 문서 매핑]
    │ 변경된 코드 ↔ 관련 문서
    │
    ▼
[3. 불일치 감지]
    │ 문서와 코드 비교
    │
    ▼
[4. 업데이트 제안]
    │ 필요한 변경 목록
    │
    ▼
[5. 자동/수동 업데이트]
    │
    ▼
✅ 완료
```

## 결과 예시

```
╔═══════════════════════════════════════════════════════════════╗
║                   DOCUMENTATION CHECK                          ║
╠═══════════════════════════════════════════════════════════════╣
║  Files Changed:  5                                             ║
║  Docs Affected:  3                                             ║
║  Updates Needed: 4                                             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                ║
║  📝 Updates Required                                          ║
║  ───────────────────                                          ║
║                                                                ║
║  1. README.md                                                  ║
║     ├─ Section: Installation                                  ║
║     └─ Change: New environment variable API_KEY               ║
║                                                                ║
║  2. docs/api.md                                               ║
║     ├─ Endpoint: POST /users                                  ║
║     └─ Change: New field 'role' in request body              ║
║                                                                ║
║  3. src/auth/login.ts                                         ║
║     ├─ Function: handleLogin                                  ║
║     └─ Change: JSDoc outdated (new param)                    ║
║                                                                ║
║  4. CHANGELOG.md                                              ║
║     └─ Add entry for new feature                             ║
║                                                                ║
╚═══════════════════════════════════════════════════════════════╝

Apply updates? (y/n/select)
```

## 자동 업데이트

### JSDoc 생성
```typescript
// Before (no docs)
function calculateTotal(items, discount) {
  return items.reduce((sum, i) => sum + i.price, 0) * (1 - discount);
}

// After (auto-generated)
/**
 * Calculates the total price with discount
 * @param {Array<{price: number}>} items - List of items
 * @param {number} discount - Discount rate (0-1)
 * @returns {number} Total price after discount
 */
function calculateTotal(items, discount) {
  return items.reduce((sum, i) => sum + i.price, 0) * (1 - discount);
}
```

### API 문서 동기화
```markdown
## POST /users

### Request Body
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| email | string | Yes | User email |
| password | string | Yes | User password |
| role | string | No | User role (NEW) |  <!-- Auto-added -->
```

## 설정

`.orchestra/config.json`:

```json
{
  "documentation": {
    "autoUpdate": true,
    "requireJSDoc": true,
    "readmeSections": ["installation", "usage", "api"],
    "changelogFormat": "keepachangelog"
  }
}
```

## 모범 사례

### DO
- ✅ 코드 변경과 함께 문서 업데이트
- ✅ 예시 코드 실제 동작 확인
- ✅ API 변경 시 버전 업데이트

### DON'T
- ❌ 오래된 문서 방치
- ❌ 예시 없이 API 문서화
- ❌ Breaking change 미고지

## 관련 명령어

- `/verify` - 문서 포함 검증
- `/code-review` - 문서 리뷰 포함
