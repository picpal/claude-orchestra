# Security Rules

보안 관련 필수 규칙입니다. 모든 에이전트가 준수해야 합니다.

## 8가지 필수 보안 체크

### 1. 하드코딩된 시크릿 금지
```typescript
// ❌ Bad
const API_KEY = "sk-1234567890abcdef";
const password = "mysecretpassword";

// ✅ Good
const API_KEY = process.env.API_KEY;
const password = process.env.DB_PASSWORD;
```

**탐지 패턴**:
- `API_KEY\s*=\s*["'][^"']+["']`
- `sk-[A-Za-z0-9]{20,}`
- `password\s*=\s*["'][^"']+["']`

### 2. 입력 검증 필수
```typescript
// ❌ Bad
function createUser(data: any) {
  db.insert(data);
}

// ✅ Good
import { z } from 'zod';

const UserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

function createUser(data: unknown) {
  const validated = UserSchema.parse(data);
  db.insert(validated);
}
```

### 3. SQL 인젝션 방지
```typescript
// ❌ Bad
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ Good
const query = "SELECT * FROM users WHERE id = $1";
await db.query(query, [userId]);
```

### 4. XSS 방지
```typescript
// ❌ Bad
element.innerHTML = userInput;
dangerouslySetInnerHTML={{ __html: userInput }}

// ✅ Good
element.textContent = userInput;
// React에서 자동 이스케이프됨
<div>{userInput}</div>
```

### 5. CSRF 방어
```typescript
// 상태 변경 요청에 CSRF 토큰 필수
// ❌ Bad
app.post('/transfer', handleTransfer);

// ✅ Good
app.post('/transfer', csrfProtection, handleTransfer);
```

### 6. 인증 검증
```typescript
// 모든 보호된 라우트에 인증 미들웨어
// ❌ Bad
app.get('/admin/users', getUsers);

// ✅ Good
app.get('/admin/users', authenticate, authorize('admin'), getUsers);
```

### 7. 레이트 리미팅
```typescript
// API 엔드포인트에 rate limit 적용
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100 // 100 요청
});

app.use('/api/', limiter);
```

### 8. 안전한 에러 핸들링
```typescript
// ❌ Bad - 스택 트레이스 노출
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.stack });
});

// ✅ Good - 일반적인 메시지만
app.use((err, req, res, next) => {
  console.error(err); // 서버 로그에만
  res.status(500).json({ error: 'Internal server error' });
});
```

## 민감한 파일

다음 파일은 절대 커밋하지 마세요:
- `.env`, `.env.local`, `.env.production`
- `credentials.json`, `secrets.json`
- `*.pem`, `*.key`, `*_rsa`
- `*.p12`, `*.pfx`

## 인시던트 대응

보안 이슈 발견 시:
1. 작업 즉시 중단
2. Security Scan 재실행 (`/verify pre-pr`)
3. 크리티컬 취약점 우선 해결
4. 자격증명 손상 시 즉시 교체

## 보안 스캔 명령

```bash
# 보안 스캔 실행
.orchestra/hooks/verification/security-scan.sh

# 전체 검증 (보안 포함)
/verify full
```
