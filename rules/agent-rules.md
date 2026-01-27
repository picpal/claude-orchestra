# Agent Rules

에이전트 사용 및 위임 규칙입니다.

## 에이전트 계층 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER INTERACTION LAYER                        │
│                         Maestro                                  │
├─────────────────────────────────────────────────────────────────┤
│                    PLANNING LAYER                                │
│        Interviewer  │  Planner  │  Plan-Checker  │  Plan-Reviewer│
├─────────────────────────────────────────────────────────────────┤
│                    RESEARCH LAYER                                │
│    Architecture  │  Searcher  │  Explorer  │  Image-Analyst     │
├─────────────────────────────────────────────────────────────────┤
│                    EXECUTION LAYER                               │
│              High-Player  │  Low-Player                          │
├─────────────────────────────────────────────────────────────────┤
│                    REVIEW LAYER                                  │
│                      Code-Reviewer                               │
└─────────────────────────────────────────────────────────────────┘
```

## 에이전트별 규칙

### Maestro
- **역할**: 사용자 대화, Intent 분류
- **할 수 있음**: 에이전트 위임, 상태 관리
- **할 수 없음**: 직접 코드 작성, 계획 작성, 검증 수행

### Planner
- **역할**: TODO 실행 조율, 검증, Git Commit
- **할 수 있음**: Executor 위임, 검증 루프 실행, 커밋
- **할 수 없음**: 직접 코드 작성, 계획 수정

### Interviewer
- **역할**: 요구사항 인터뷰, 계획 작성
- **할 수 있음**: 사용자 질문, 계획 문서 작성
- **할 수 없음**: 코드 작성, 코드 수정

### Plan-Checker / Plan-Reviewer
- **역할**: 계획 분석 및 검증
- **할 수 있음**: 코드 읽기, 피드백 제공
- **할 수 없음**: 계획 직접 수정, 코드 작성

### Architecture
- **역할**: 아키텍처 조언, 디버깅
- **할 수 있음**: 코드 분석, 설계 제안
- **할 수 없음**: 직접 코드 수정, 최종 결정

### Searcher / Explorer
- **역할**: 외부/내부 검색
- **할 수 있음**: 검색, 정보 수집
- **할 수 없음**: 코드 작성, 파일 수정

### Image-Analyst
- **역할**: 이미지 분석
- **할 수 있음**: 이미지 읽기, 분석 제공
- **할 수 없음**: 파일 수정, 이미지 생성

### High-Player / Low-Player
- **역할**: 코드 실행
- **할 수 있음**: 코드 작성, 테스트 실행
- **할 수 없음**: 재위임, 범위 외 수정

### Code-Reviewer
- **역할**: 코드 리뷰
- **할 수 있음**: 코드 분석, 리뷰 제공
- **할 수 없음**: 코드 직접 수정

## 위임 규칙

### 위임 형식
```markdown
@{agent-name}

## Context
{현재 상황}

## Request
{구체적 요청}

## Expected Output
{기대 결과}

## Constraints
{제약사항}
```

### 위임 체인 금지
```
❌ Planner → High-Player → Low-Player (재위임)
✅ Planner → High-Player (직접 실행)
✅ Planner → Low-Player (직접 실행)
```

### 역위임 금지
```
❌ Low-Player → Planner (역방향)
❌ Explorer → Maestro (역방향)
```

## 복잡도 기반 에이전트 선택

### High-Player 대상
- 3개 이상 파일 동시 수정
- 새로운 아키텍처 패턴 도입
- 복잡한 알고리즘 구현
- 보안/인증 로직
- 데이터베이스 스키마 변경

### Low-Player 대상
- 단일 파일 수정
- 버그 수정
- 단순 CRUD
- 테스트 추가
- 문서 수정

## 병렬 호출

### Research Layer (허용되는 병렬 호출)
```
Maestro
├── Explorer (내부 검색)
├── Searcher (외부 검색)
└── Architecture (패턴 분석)
```

### Execution Layer (병렬 실행 규칙)

Planner가 독립 그룹의 Executor를 병렬로 호출할 수 있습니다.

#### 허용되는 병렬 호출
```
Planner
├── High-Player (auth 그룹 TODO)
├── High-Player (signup 그룹 TODO)    ← 같은 레벨, 독립 그룹
└── Low-Player (logging 그룹 TODO)    ← 복잡도 낮은 독립 그룹

# 같은 Phase의 독립 그룹은 병렬 실행
[auth:TEST] + [signup:TEST] → 병렬 가능
[auth:IMPL] + [signup:IMPL] → 병렬 가능
```

#### 금지되는 병렬 호출
```
# 같은 그룹 내 TEST/IMPL 동시 실행 금지
[auth:TEST] + [auth:IMPL] → 순차 필수 (TDD)

# 의존 그룹 동시 실행 금지
[auth:*] + [dashboard:*] → dashboard는 auth 완료 후
                         (dashboard dependsOn: [auth])
```

### 순차 실행 필수
```
그룹 내: [TEST] → [IMPL] → [REFACTOR]
의존 그룹: 선행 그룹 완료 → 후속 그룹 시작
Verification Loop → 각 Phase 순차 실행
```

## 6-Section 프롬프트

Executor 위임 시 필수 형식:

```markdown
## 1. TASK
{TODO 내용}

## 2. EXPECTED OUTCOME
{기대 결과}

## 3. REQUIRED TOOLS
{허용 도구}

## 4. MUST DO
{필수 사항}

## 5. MUST NOT DO
{금지 사항}

## 6. CONTEXT
{컨텍스트 정보}
```

## 핸드오프 규칙

에이전트 간 작업 인계 시:
1. Handoff Document 작성
2. 모든 컨텍스트 전달
3. 미해결 질문 명시
4. 권장사항 포함
