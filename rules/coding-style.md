# Coding Style Rules

코드 스타일 규칙입니다.

## 일반 원칙

### 1. 명확성 우선
```typescript
// ❌ Bad - 불명확
const d = new Date();
const x = arr.filter(i => i.a > 0);

// ✅ Good - 명확
const currentDate = new Date();
const activeUsers = users.filter(user => user.isActive);
```

### 2. 단순성
```typescript
// ❌ Bad - 과도한 추상화
class UserFactoryBuilderManager {
  createUserBuilder() {
    return new UserBuilder(new UserFactory());
  }
}

// ✅ Good - 필요한 만큼만
function createUser(data: UserInput): User {
  return { ...data, id: generateId() };
}
```

### 3. 일관성
프로젝트 전체에서 동일한 패턴 사용

## 명명 규칙

### 변수/함수
```typescript
// camelCase
const userName = "John";
const isActive = true;

function getUserById(id: string) {}
function calculateTotal(items: Item[]) {}
```

### 상수
```typescript
// UPPER_SNAKE_CASE
const MAX_RETRY_COUNT = 3;
const API_BASE_URL = "https://api.example.com";
const DEFAULT_PAGE_SIZE = 20;
```

### 클래스/인터페이스/타입
```typescript
// PascalCase
class UserService {}
interface UserRepository {}
type UserRole = "admin" | "user";

// 인터페이스에 I 접두사 사용 안 함
interface User {} // ✅
interface IUser {} // ❌
```

### Boolean 변수
```typescript
// is, has, can, should 접두사
const isLoading = true;
const hasPermission = false;
const canEdit = true;
const shouldRefresh = false;
```

### 이벤트 핸들러
```typescript
// handle 접두사
function handleClick() {}
function handleSubmit() {}
function handleInputChange() {}
```

## 파일 구조

### 파일 크기
- 최대 800줄
- 이상적으로 300줄 이내

### 함수 크기
- 최대 50줄
- 이상적으로 20줄 이내

### 함수 파라미터
```typescript
// ❌ Bad - 너무 많은 파라미터
function createUser(name, email, age, role, department, manager) {}

// ✅ Good - 객체 사용
interface CreateUserInput {
  name: string;
  email: string;
  age: number;
  role: string;
  department?: string;
  manager?: string;
}

function createUser(input: CreateUserInput) {}
```

## 중첩 제한

### 최대 3단계
```typescript
// ❌ Bad - 깊은 중첩
if (a) {
  if (b) {
    if (c) {
      if (d) {
        // code
      }
    }
  }
}

// ✅ Good - Early return
if (!a) return;
if (!b) return;
if (!c) return;
if (!d) return;
// code
```

## 에러 핸들링

### try-catch 범위
```typescript
// ❌ Bad - 너무 넓은 범위
try {
  // 100줄의 코드
} catch (e) {
  console.error(e);
}

// ✅ Good - 좁은 범위
const data = await fetchData(); // 별도 처리

try {
  await processData(data);
} catch (e) {
  handleProcessError(e);
}
```

### 에러 타입
```typescript
// Custom Error 사용
class ValidationError extends Error {
  constructor(message: string, public field: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

// 사용
throw new ValidationError('Invalid email', 'email');
```

## 주석

### 좋은 주석
```typescript
// 왜 이렇게 했는지 설명
// Chrome 버그 우회를 위해 setTimeout 사용 (issue #123)
setTimeout(callback, 0);

// 복잡한 알고리즘 설명
// Fisher-Yates 셔플 알고리즘으로 배열 무작위 정렬
```

### 나쁜 주석
```typescript
// ❌ 코드를 반복하는 주석
// 사용자 이름을 가져옴
const userName = user.name;

// ❌ 주석 처리된 코드
// const oldLogic = ...
```

## TypeScript 특화

### any 사용 금지
```typescript
// ❌ Bad
function process(data: any) {}

// ✅ Good
function process(data: unknown) {
  if (isValidData(data)) {
    // type narrowing 후 사용
  }
}
```

### 타입 추론 활용
```typescript
// ❌ 불필요한 타입 명시
const name: string = "John";
const numbers: number[] = [1, 2, 3];

// ✅ 추론 가능하면 생략
const name = "John";
const numbers = [1, 2, 3];
```

### 유니온 타입 활용
```typescript
// ❌ Bad
type Status = string;

// ✅ Good
type Status = 'pending' | 'approved' | 'rejected';
```
