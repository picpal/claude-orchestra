# Performance Rules

성능 관련 가이드라인입니다.

## 알고리즘 복잡도

### 주의 필요 복잡도
| 복잡도 | 주의 수준 | 예시 |
|--------|-----------|------|
| O(1) | ✅ 좋음 | 해시맵 조회 |
| O(log n) | ✅ 좋음 | 이진 검색 |
| O(n) | ✅ 좋음 | 단일 루프 |
| O(n log n) | ⚠️ 주의 | 정렬 |
| O(n²) | ⚠️ 경고 | 중첩 루프 |
| O(2^n) | ❌ 위험 | 재귀 (메모이제이션 없이) |

### 중첩 루프 피하기
```typescript
// ❌ Bad - O(n²)
items.forEach(item => {
  const category = categories.find(c => c.id === item.categoryId);
});

// ✅ Good - O(n)
const categoryMap = new Map(categories.map(c => [c.id, c]));
items.forEach(item => {
  const category = categoryMap.get(item.categoryId);
});
```

## React 최적화

### 불필요한 리렌더링 방지
```typescript
// ❌ Bad - 매번 새 객체 생성
<Component style={{ color: 'red' }} />
<Component onClick={() => handleClick(id)} />

// ✅ Good - 메모이제이션
const style = useMemo(() => ({ color: 'red' }), []);
const handleClickMemo = useCallback(() => handleClick(id), [id]);

<Component style={style} />
<Component onClick={handleClickMemo} />
```

### 컴포넌트 메모이제이션
```typescript
// 무거운 컴포넌트는 memo 사용
const HeavyComponent = memo(({ data }) => {
  // 복잡한 렌더링
});

// 비교 함수 커스텀 (필요시)
const areEqual = (prev, next) => prev.id === next.id;
const MemoizedComponent = memo(Component, areEqual);
```

### 리스트 렌더링
```typescript
// ❌ Bad - index를 key로 사용
{items.map((item, index) => (
  <Item key={index} {...item} />
))}

// ✅ Good - 고유 ID 사용
{items.map(item => (
  <Item key={item.id} {...item} />
))}
```

## 데이터베이스

### N+1 쿼리 방지
```typescript
// ❌ Bad - N+1 쿼리
const posts = await Post.findAll();
for (const post of posts) {
  post.author = await User.findById(post.authorId); // N번 추가 쿼리
}

// ✅ Good - JOIN 또는 배치
const posts = await Post.findAll({
  include: [{ model: User, as: 'author' }]
});

// 또는 배치 조회
const authorIds = posts.map(p => p.authorId);
const authors = await User.findAll({ where: { id: authorIds } });
const authorMap = new Map(authors.map(a => [a.id, a]));
posts.forEach(p => p.author = authorMap.get(p.authorId));
```

### 인덱스 활용
```sql
-- 자주 조회되는 컬럼에 인덱스
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_posts_author_id ON posts(author_id);

-- 복합 인덱스 (순서 중요)
CREATE INDEX idx_posts_status_created ON posts(status, created_at);
```

### 페이지네이션
```typescript
// ❌ Bad - 모든 데이터 로드
const allUsers = await User.findAll();

// ✅ Good - 페이지네이션
const users = await User.findAll({
  limit: 20,
  offset: (page - 1) * 20,
  order: [['createdAt', 'DESC']]
});
```

## 번들 최적화

### 코드 스플리팅
```typescript
// 동적 import
const HeavyComponent = lazy(() => import('./HeavyComponent'));

// 라우트 기반 스플리팅
const routes = [
  {
    path: '/dashboard',
    component: lazy(() => import('./Dashboard'))
  }
];
```

### Tree Shaking
```typescript
// ❌ Bad - 전체 라이브러리 import
import _ from 'lodash';
_.debounce(fn, 300);

// ✅ Good - 필요한 것만 import
import debounce from 'lodash/debounce';
debounce(fn, 300);
```

## 캐싱

### API 응답 캐싱
```typescript
// React Query / SWR 사용
const { data } = useQuery({
  queryKey: ['users', userId],
  queryFn: () => fetchUser(userId),
  staleTime: 5 * 60 * 1000, // 5분
  cacheTime: 30 * 60 * 1000, // 30분
});
```

### 계산 결과 캐싱
```typescript
// useMemo로 비용 큰 계산 캐싱
const sortedItems = useMemo(() => {
  return [...items].sort((a, b) => a.name.localeCompare(b.name));
}, [items]);
```

## 모니터링

### 성능 측정
```typescript
// Performance API
const start = performance.now();
// 작업 실행
const duration = performance.now() - start;
console.log(`Operation took ${duration}ms`);

// React Profiler
<Profiler id="MyComponent" onRender={onRenderCallback}>
  <MyComponent />
</Profiler>
```
