# /code-review - 코드 리뷰 실행

변경된 코드에 대한 Code-Review Team (5명 병렬) 리뷰를 수행합니다.

## 사용법

```
/code-review [target]
```

### Target 옵션

| Target | 설명 |
|--------|------|
| (없음) | 현재 스테이징된 변경사항 |
| `staged` | 스테이징된 변경사항 |
| `unstaged` | 스테이징 안 된 변경사항 |
| `all` | 모든 변경사항 |
| `{file}` | 특정 파일 |

---

## Execution (Maestro가 반드시 실행)

### Step 1: 변경 파일 수집

```bash
git diff --name-only
```

### Step 2: 5명 병렬 호출 (한 메시지에 5개 Task)

호출 패턴은 `rules/call-templates.md`의 "Code-Review Team" 섹션 참조.

```
Task(Security Guardian) + Task(Quality Inspector)
+ Task(Performance Analyst) + Task(Standards Keeper) + Task(TDD Enforcer)
```

### Step 3: 결과 종합 → 가중치 점수 계산

```
weighted_score = (4*Security + 3*Quality + 2*Performance + 2*Standards + 4*TDD) / 15

score_map: Approved=1.0, Warning=0.5, Block=0.0
```

### Step 4: 판정

| 조건 | 판정 | 조치 |
|------|------|------|
| Auto-Block (Security Critical / 테스트 삭제) | Block | Rework Loop |
| >= 0.80 | Approved | 커밋 진행 |
| 0.50-0.79 | Warning | 경고 기록, 진행 가능 |
| < 0.50 | Block | Rework Loop (최대 3회) |

---

## Code-Review Team 구성

| 팀원 | 모델 | 가중치 | 담당 영역 | 항목 수 |
|------|------|--------|----------|--------|
| Security Guardian | sonnet | 4 | 보안 취약점 | 7 |
| Quality Inspector | sonnet | 3 | 코드 품질 | 8 |
| Performance Analyst | haiku | 2 | 성능 이슈 | 6 |
| Standards Keeper | haiku | 2 | 표준 준수 | 5 |
| TDD Enforcer | sonnet | 4 | TDD 검증 | 7 |

---

## 리뷰 범위 (레퍼런스)

### Security (Critical)
- 하드코딩된 자격증명, SQL 인젝션, XSS, 입력 검증 누락, CSRF, 인증/인가 우회

### Code Quality (High)
- 함수 크기 (50줄 초과), 파일 크기 (800줄 초과), 중첩 깊이, 에러 핸들링

### Performance (Medium)
- 알고리즘 복잡도, 불필요 리렌더링, N+1 쿼리, 메모리 누수

### Standards (Low)
- 네이밍 컨벤션, 문서화, 접근성, 테스트 커버리지

### TDD Compliance (High)
- 테스트 없는 구현, 테스트 삭제 (Critical), 테스트 스킵, TDD 순서 위반

---

## 관련 명령어

- `/verify` - 검증 루프 실행 (Verification 통과 후 자동 Code-Review)
- `/status` - 마지막 리뷰 결과 확인
