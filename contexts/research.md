# Research Context

탐색과 조사에 집중하는 컨텍스트입니다.

## 핵심 원칙

### 1. "Explore before implementing"
- 구현 전 충분한 탐색
- 기존 코드 패턴 이해
- 유사 구현 참조

### 2. "Document findings as you go"
- 발견 사항 즉시 기록
- 노트패드 활용
- 나중에 참조할 수 있게

### 3. 여러 접근 방식 비교
- 단일 솔루션에 고정 X
- 대안 검토
- 장단점 분석

### 4. 트레이드오프 문서화
- 각 선택의 이유
- 포기한 대안과 이유
- 향후 고려사항

## 우선순위

```
1위: 이해도 (Understanding)
     "무엇이 어떻게 동작하는지"

2위: 완전성 (Completeness)
     "빠뜨린 것이 없는지"

3위: 정확성 (Accuracy)
     "정보가 정확한지"
```

## 권장 도구

### 코드 탐색
- **Grep**: 패턴/키워드 검색
- **Glob**: 파일 구조 탐색
- **Read**: 파일 내용 읽기

### 외부 검색
- **WebSearch**: 문서, 튜토리얼 검색
- **WebFetch**: 웹 페이지 내용 가져오기

### 기록
- **Write**: 노트 작성 (노트패드)

## 워크플로우

```
1. 목표 정의
    ↓
2. 내부 코드 탐색 (Explorer)
    │
    ├── 파일 구조 파악
    ├── 관련 코드 찾기
    └── 패턴 식별
    ↓
3. 외부 정보 검색 (Searcher)
    │
    ├── 공식 문서
    ├── 베스트 프랙티스
    └── 유사 구현
    ↓
4. 아키텍처 분석 (Architecture)
    │
    ├── 설계 패턴
    ├── 의존성 분석
    └── 영향 범위
    ↓
5. 발견 사항 정리
    ↓
6. 결론/권장사항 도출
```

## 탐색 전략

### 코드베이스 구조 파악
```bash
# 디렉토리 구조
ls -la src/

# 파일 타입별
Glob: "src/**/*.ts"
Glob: "src/**/*.test.ts"

# 설정 파일
Glob: "**/config.*"
```

### 특정 기능 찾기
```bash
# 함수/클래스
Grep: "function handleLogin"
Grep: "class UserService"

# 패턴
Grep: "import.*from.*@auth"
Grep: "TODO|FIXME"
```

### 외부 문서 검색
```
# 공식 문서
"{library} documentation"
"{framework} official guide"

# 특정 문제
"{error message} solution"
"{library} {feature} example"
```

## 출력 형식

### 탐색 결과
```markdown
## Research: {주제}

### 목표
{탐색 목적}

### 내부 코드 분석
- 위치: `src/...`
- 패턴: {발견된 패턴}
- 관련 파일: {파일 목록}

### 외부 참조
- {출처}: {요약}
- {출처}: {요약}

### 발견 사항
1. {발견 1}
2. {발견 2}

### 권장사항
{결론 및 권장}
```

## 금지 사항

### DO NOT
- ❌ 탐색 없이 구현 시작
- ❌ 코드 수정 (research 모드에서)
- ❌ 단일 출처만 참조
- ❌ 발견 사항 미기록

### AVOID
- ⚠️ 너무 깊은 토끼굴
- ⚠️ 불필요한 세부사항
- ⚠️ 오래된 정보 참조

## 모드 전환

다른 컨텍스트로 전환:
```
/context dev     # 개발 모드 (탐색 완료 후)
/context review  # 리뷰 모드
```
