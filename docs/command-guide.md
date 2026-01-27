# 명령어 활용 가이드

Claude Orchestra의 슬래시 명령어를 작업 흐름별로 정리한 가이드입니다.

---

## 작업 흐름 개요

```
/tuning → /start-work → (개발) → /verify → /code-review → /learn
  ↑          ↑           ↑          ↑           ↑            ↑
최초 1회   세션 시작   TDD 사이클   검증      리뷰        학습
```

---

## 1단계: 프로젝트 셋업 (최초 1회)

### `/tuning`

| 항목 | 내용 |
|------|------|
| **언제** | 플러그인 설치 직후, 프로젝트당 최초 1회 |
| **하는 일** | `rules/`를 프로젝트 `.claude/rules/`에 복사, `.orchestra/` 상태 디렉토리 생성 |

```bash
/tuning
```

---

## 2단계: 작업 시작

### `/start-work`

| 항목 | 내용 |
|------|------|
| **언제** | 새로운 작업 세션을 시작할 때 |
| **하는 일** | `.orchestra/` 없으면 자동 생성, `state.json` IDLE 초기화, 사용자 요청을 Intent로 분류하여 적절한 에이전트 배정 |

```bash
/start-work
```

Intent 분류:
- **TRIVIAL** ("이 함수 설명해줘") → 직접 응답
- **EXPLORATORY** ("인증 로직 어디있어?") → Explorer 호출
- **AMBIGUOUS** ("로그인 고쳐줘") → 명확화 질문
- **OPEN-ENDED** ("OAuth 추가해줘") → Interviewer로 계획 수립

### `/context`

| 항목 | 내용 |
|------|------|
| **언제** | 작업 성격을 전환할 때 |
| **하는 일** | dev/research/review 모드 전환, 모드별 원칙과 권장 도구 적용 |

```bash
/context dev        # 코드 작성 집중 (기본)
/context research   # 탐색/분석 집중
/context review     # 품질 검증 집중
```

스킬 형태로도 사용 가능:
```bash
/claude-orchestra:context-dev
/claude-orchestra:context-research
/claude-orchestra:context-review
```

| 모드 | 우선순위 | 주요 도구 |
|------|----------|-----------|
| **dev** | 기능성 > 정확성 > 품질 | Edit, Write, Bash |
| **research** | 이해도 > 완전성 > 정확성 | Read, Grep, WebSearch |
| **review** | 보안 > 정확성 > 성능 | Read, Grep, Bash |

---

## 3단계: 개발 중

### `/tdd-cycle`

| 항목 | 내용 |
|------|------|
| **언제** | TDD 사이클 진행 방법이 헷갈릴 때, TDD에 익숙하지 않을 때 |
| **하는 일** | RED → GREEN → REFACTOR 3단계 가이드 표시, 각 단계별 체크리스트와 예제 코드 제공 |

```bash
/tdd-cycle
```

```
RED      실패하는 테스트 작성
  ↓
GREEN    테스트 통과하는 최소 구현
  ↓
REFACTOR 코드 개선 (테스트 유지)
  ↓
다음 기능으로 반복
```

### `/status`

| 항목 | 내용 |
|------|------|
| **언제** | 현재 진행 상황을 파악하고 싶을 때 |
| **하는 일** | 현재 mode, 활성 계획, TODO 진행률, TDD 메트릭, 최근 커밋을 표시 |

```bash
/status           # 전체 상태 요약
/status plan      # 현재 계획 상세
/status tdd       # TDD 메트릭 상세
/status commits   # 커밋 히스토리
```

### `/checkpoint`

| 항목 | 내용 |
|------|------|
| **언제** | 리팩토링/실험 전 현재 상태를 저장해두고 싶을 때 |
| **하는 일** | 현재 mode, TODO 목록, TDD 메트릭, 검증 결과 등 상태 스냅샷 저장 (최대 10개) |

```bash
/checkpoint                                    # 자동 이름 생성
/checkpoint before-refactor                    # 이름 지정
/checkpoint auth-complete "인증 기능 구현 완료"  # 이름 + 설명
```

---

## 4단계: 검증

### `/verify`

| 항목 | 내용 |
|------|------|
| **언제** | 코드 품질을 확인하고 싶을 때 (개발 중, 커밋 전, PR 전) |
| **하는 일** | 6단계 검증 루프 실행 (Build → Types → Lint → Tests → Security → Diff) |

```bash
/verify quick     # Build + Types (개발 중 빠른 확인)
/verify standard  # + Lint + Tests (TODO 완료 시, 기본값)
/verify full      # 전체 6단계 (커밋 전)
/verify pre-pr    # 전체 + 보안 강화 (PR 제출 전)
```

| 모드 | 실행 단계 | 사용 시점 |
|------|-----------|-----------|
| `quick` | Build, Types | 코드 수정 후 빠른 확인 |
| `standard` | Build, Types, Lint, Tests | TODO 완료 시 |
| `full` | 전체 6단계 | 커밋 전 |
| `pre-pr` | 전체 + 보안 강화 | PR 제출 전 |

### `/code-review`

| 항목 | 내용 |
|------|------|
| **언제** | 변경된 코드의 품질을 심층 검토하고 싶을 때 |
| **하는 일** | Security → Quality → Performance → Best Practices 순서로 25+ 차원 분석, Block/Warning/Approve 판정 |

```bash
/code-review            # 스테이징된 변경사항
/code-review staged     # 스테이징된 변경사항
/code-review unstaged   # 스테이징 안 된 변경사항
/code-review all        # 모든 변경사항
/code-review src/auth.ts  # 특정 파일
```

승인 레벨:
- **Approve** — Critical/High 없음, 커밋 가능
- **Warning** — Medium만 존재, 수정 권장
- **Block** — Critical/High 존재, 수정 필수

### `/e2e`

| 항목 | 내용 |
|------|------|
| **언제** | End-to-End 테스트를 실행하고 싶을 때 |
| **하는 일** | Playwright 또는 Cypress 기반 E2E 테스트 실행 |

```bash
/e2e                        # 전체 E2E 테스트
/e2e --headed               # 브라우저 UI 표시
/e2e tests/auth.spec.ts     # 특정 테스트
/e2e --debug                # 디버그 모드
```

---

## 5단계: 리팩토링 / 정리

### `/refactor-clean`

| 항목 | 내용 |
|------|------|
| **언제** | 기능 변경 없이 코드 구조를 개선하고 싶을 때 |
| **하는 일** | 테스트 확인 → 리팩토링 대상 식별 (긴 함수, 중복, 깊은 중첩) → 계획 → 단계별 실행 (매 단계 테스트) |

```bash
/refactor-clean             # 전체 코드베이스 분석
/refactor-clean src/auth/   # 특정 디렉토리
/refactor-clean src/api.ts  # 특정 파일
```

탐지 패턴:
- 50줄 초과 함수 → 함수 추출 제안
- 중복 코드 블록 → 공유 유틸리티 제안
- 3단계 초과 중첩 → early return 제안

### `/update-docs`

| 항목 | 내용 |
|------|------|
| **언제** | 코드 변경 후 문서가 코드와 일치하는지 확인하고 싶을 때 |
| **하는 일** | git diff 기반으로 README, API 문서, JSDoc, CHANGELOG의 불일치 감지 및 업데이트 제안 |

```bash
/update-docs            # 전체 문서 검사
/update-docs api        # API 문서만
/update-docs readme     # README만
/update-docs comments   # 코드 주석만
```

---

## 6단계: 학습

### `/learn`

| 항목 | 내용 |
|------|------|
| **언제** | 세션에서 반복된 패턴을 저장하고 다음 세션에 활용하고 싶을 때 |
| **하는 일** | 에러 해결, 사용자 수정 요청 등에서 재사용 가능한 패턴 추출/저장 |

```bash
/learn list       # 저장된 패턴 목록
/learn evaluate   # 현재 세션 수동 평가
/learn add        # 패턴 직접 추가
/learn clear      # 모든 패턴 삭제
```

패턴 카테고리:
| 카테고리 | 설명 | 우선순위 |
|----------|------|----------|
| `error_resolution` | 에러 해결 패턴 | High |
| `user_corrections` | 사용자 수정 요청 패턴 | High |
| `project_specific` | 프로젝트 특화 패턴 | High |
| `workarounds` | 우회 해결책 | Medium |
| `debugging_techniques` | 디버깅 기법 | Medium |
| `best_practices` | 모범 사례 | Low |

---

## 실전 시나리오

### 새 기능 개발

```
/start-work
  ↓
(코딩 — /tdd-cycle 참고)
  ↓
/status          # 진행 확인
  ↓
/verify standard # 검증
  ↓
/code-review     # 리뷰
  ↓
/checkpoint feature-done
```

### PR 제출 전

```
/verify pre-pr   # 전체 검증 + 보안
  ↓
/code-review all # 전체 리뷰
  ↓
/update-docs     # 문서 동기화
  ↓
/e2e             # E2E 테스트
```

### 대규모 리팩토링

```
/checkpoint before-refactor  # 상태 백업
  ↓
/refactor-clean src/auth/    # 리팩토링
  ↓
/verify full                 # 전체 검증
  ↓
/code-review                 # 리뷰
```

### 조사/분석 작업

```
/context research    # 탐색 모드 전환
  ↓
(탐색/분석)
  ↓
/learn evaluate      # 발견 패턴 저장
  ↓
/context dev         # 개발 모드 복귀
```
