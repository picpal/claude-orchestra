# Review Context

코드 리뷰에 집중하는 컨텍스트입니다.

## 핵심 원칙

### 1. "Quality over speed"
- 속도보다 품질
- 꼼꼼한 검토
- 놓치는 이슈 없이

### 2. "Every issue matters"
- 작은 이슈도 기록
- 심각도 분류
- 개선안 제시

### 3. 보안 이슈 최우선
- 보안 취약점 먼저
- Critical 이슈 우선
- 즉시 보고

### 4. 구체적인 개선안 제시
- "이건 별로" 대신 "이렇게 고치면"
- 코드 예시 포함
- 이유 설명

## 우선순위

```
1위: 보안 (Security)
     "취약점이 없는가"

2위: 정확성 (Correctness)
     "올바르게 동작하는가"

3위: 성능 (Performance)
     "효율적인가"
```

## 권장 도구

### 코드 읽기
- **Read**: 파일 전체 읽기
- **Grep**: 패턴 검색

### 검증
- **Bash**: 린트, 테스트 실행

## 리뷰 체크리스트

### Security (Critical)
- [ ] 하드코딩된 자격증명
- [ ] SQL 인젝션
- [ ] XSS 취약점
- [ ] 입력 검증 누락
- [ ] 인증/인가 우회

### Code Quality (High)
- [ ] 함수 크기 (50줄 이하)
- [ ] 파일 크기 (800줄 이하)
- [ ] 중첩 깊이 (3단계 이하)
- [ ] 에러 핸들링
- [ ] 매직 넘버/스트링

### Performance (Medium)
- [ ] 알고리즘 복잡도
- [ ] 불필요한 리렌더링
- [ ] N+1 쿼리
- [ ] 메모리 누수

### Best Practices (Low)
- [ ] 네이밍 컨벤션
- [ ] 문서화
- [ ] 테스트 커버리지
- [ ] 접근성

## 리뷰 워크플로우

```
1. 변경 파일 목록 확인
    ↓
2. 변경 범위 이해
    │
    ├── 어떤 기능?
    ├── 어떤 모듈?
    └── 영향 범위?
    ↓
3. Security 검사 (최우선)
    ↓
4. Code Quality 검사
    ↓
5. Performance 검사
    ↓
6. Best Practices 검사
    ↓
7. 이슈 정리
    ↓
8. 승인 결정
```

## 출력 형식

### 리뷰 리포트
```markdown
## Code Review Report

### Summary
| Files | Lines | Result | Issues |
|-------|-------|--------|--------|
| 5 | +120/-45 | ⚠️ Warning | 0C, 0H, 3M, 2L |

### Issues

#### 🔴 Critical
(없음)

#### 🟠 High
(없음)

#### 🟡 Medium

##### [M1] {이슈 제목}
- **File**: `path/to/file.ts:45`
- **Pattern**: {어떤 문제}
- **Suggestion**: {개선안}
```code
{수정 예시}
```

### Approval Decision
⚠️ Warning - 진행 가능, 수정 권장
```

## 심각도 기준

| 심각도 | 기준 | 액션 |
|--------|------|------|
| 🔴 Critical | 보안 취약점, 데이터 손실 | 즉시 수정 필수 |
| 🟠 High | 버그, 중요 기능 오류 | 머지 전 수정 |
| 🟡 Medium | 코드 품질, 성능 | 수정 권장 |
| 🟢 Low | 스타일, 문서화 | 선택적 수정 |

## 승인 레벨

| 상태 | 조건 |
|------|------|
| ✅ Approve | Critical/High 없음 |
| ⚠️ Warning | Medium만 존재 |
| ❌ Block | Critical/High 존재 |

## 금지 사항

### DO NOT
- ❌ 주관적 취향 강요
- ❌ 설명 없는 거부
- ❌ 사소한 이슈로 Block
- ❌ 직접 코드 수정 (리뷰 모드에서)

### AVOID
- ⚠️ 너무 많은 Low 이슈
- ⚠️ 모호한 피드백
- ⚠️ 컨텍스트 없는 코멘트

## 좋은 리뷰 코멘트

### ✅ Good
```
이 함수는 67줄로 50줄 제한을 초과합니다.
validateInput(), authenticate(), createSession() 세 함수로 분리하는 것을 권장합니다.
```

### ❌ Bad
```
함수가 너무 깁니다.
```

## 모드 전환

다른 컨텍스트로 전환:
```
/context dev      # 개발 모드
/context research # 탐색 모드
```
