# Agent Call Templates

> Maestro가 에이전트 호출 시 참조하는 템플릿입니다.
> 공통 원칙: `subagent_type: "general-purpose"` 사용, Expected Output 형식 준수.

---

## Research-Team (opus) — Phase 1+2 통합 (단순 케이스)

> **사용 조건**: 기존 코드 존재 + 이미지 없음 + 외부 라이브러리 불필요
> 조건 미충족 시 기존 Phase 1 병렬 → Phase 2 Interviewer 사용

```
Task(
  subagent_type: "general-purpose", model: "opus",
  description: "Research-Team: 코드 분석 + 요구사항 인터뷰",
  prompt: """
  **Research-Team** — 코드베이스 탐색 + 사용자 인터뷰 + 계획 초안
  도구: Glob, Grep, Read, Bash(읽기전용), AskUserQuestion, Write(.orchestra/plans/)
  제약: Task 금지, Edit 금지, 코드 작성 금지

  1단계: 아래 요청 관련 코드베이스를 Glob/Grep/Read로 탐색
  2단계: 탐색 결과를 바탕으로 AskUserQuestion으로 사용자 확인
  3단계: .orchestra/plans/{name}.md에 계획 초안 작성

  ## 사용자 요청
  {요청 내용}

  ## Expected Output
  [Research-Team] 계획 초안 완료: .orchestra/plans/{name}.md
  - Explorer 분석: {관련 파일 요약}
  - TODOs: {N}개
  - Groups: {group-list}
  """
)
```

---

## Interviewer (opus)

> **사용 조건**: 복합 케이스(이미지/외부 라이브러리 포함) 또는 완전 신규 프로젝트
> 단순 케이스(기존 코드만)는 Research-Team 사용

> **필수**: Phase 1(Research) 결과를 Context에 포함하여 전달합니다.
> Interviewer는 소스 코드를 직접 읽지 않습니다 (Hook 차단됨).

```
Task(
  subagent_type: "general-purpose", model: "opus",
  description: "Interviewer: 요구사항 인터뷰",
  prompt: """
**Interviewer** - 요구사항 인터뷰 + 계획 초안 작성
도구: AskUserQuestion, Write(.orchestra/plans/), Read(문서/설정만)
제약: 코드 작성 금지, Task 사용 금지, 소스 코드 Read 금지 (Hook 차단)
---
## Phase 1 Research 결과 (Interviewer가 직접 탐색하지 않음)
{Explorer 결과: 코드 구조, 관련 파일, 기존 패턴}
{Image-Analyst 결과: 이미지 분석 (있는 경우)}
{Searcher 결과: 외부 문서 (있는 경우)}

## 사용자 요청
{요청 내용}

## Request
위 Research 결과를 바탕으로 사용자와 인터뷰하고 계획 초안을 작성하세요.
코드 탐색은 이미 완료되었으므로 직접 코드를 읽지 마세요.

## Expected Output
[Interviewer] 계획 초안 완료: .orchestra/plans/{name}.md
- TODOs: {N}개
- Groups: {group-list}
"""
)
```

---

## Planner (opus) - 분석 전용

> Planner는 분석만 수행. Executor 호출은 Maestro가 직접.

```
Task(
  subagent_type: "general-purpose", model: "opus",
  description: "Planner: TODO 분석",
  prompt: """
**Planner** - TODO 분석 + 6-Section 프롬프트 생성 (분석만)
도구: Read
제약: Task, Edit, Write, Bash 금지 (실행은 Maestro 담당)
---
## Plan File
.orchestra/plans/{name}.md

## Output Format (MANDATORY)

### Part 1: Structured Summary (JSON)
반드시 아래 형식의 JSON 블록을 포함하세요:
```json
{
  "planFile": ".orchestra/plans/{name}.md",
  "totalTodos": 8,
  "levels": [
    {
      "level": 0,
      "todoCount": 3,
      "todos": [
        {"id": "auth-001", "type": "FEATURE", "executor": "high-player"},
        {"id": "signup-001", "type": "FEATURE", "executor": "low-player"},
        {"id": "config-001", "type": "CHORE", "executor": "low-player"}
      ],
      "parallelSafe": true
    },
    {
      "level": 1,
      "todoCount": 2,
      "todos": [
        {"id": "dashboard-001", "type": "FEATURE", "executor": "high-player"},
        {"id": "dashboard-002", "type": "CHORE", "executor": "low-player"}
      ],
      "parallelSafe": true
    }
  ]
}
```

### Part 2: 6-Section Prompts (Markdown)
각 TODO별 상세 프롬프트:
#### TODO: {todo-id}
- Executor: High-Player | Low-Player
- 6-Section Prompt:
  ## 1. TASK
  ## 2. EXPECTED OUTCOME
  ## 3. REQUIRED TOOLS
  ## 4. MUST DO
  ## 5. MUST NOT DO
  ## 6. CONTEXT
"""
)
```

---

## High-Player (opus)

```
Task(
  subagent_type: "general-purpose", model: "opus",
  description: "High-Player: {작업 요약}",
  prompt: """
**High-Player** - 복잡한 작업 실행 (아키텍처, 다중 파일, 보안/인증)
도구: Read, Edit, Write, Bash, Glob, Grep
제약: 테스트 삭제/스킵 금지, 재위임 금지, 범위 외 수정 금지
TDD: [FEATURE] → RED->GREEN->REFACTOR 필수 (tdd-cycle-gate.sh Hook 강제)
     [CHORE] → TDD 면제
---
{Planner가 생성한 6-Section 프롬프트}
"""
)
```

---

## Low-Player (sonnet)

```
Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Low-Player: {작업 요약}",
  prompt: """
**Low-Player** - 간단한 작업 실행 (단일 파일, 버그 수정, 테스트)
도구: Read, Edit, Write, Bash, Grep
제약: 테스트 삭제/스킵 금지, 재위임 금지, 범위 외 수정 금지
TDD: [FEATURE] → RED->GREEN->REFACTOR 필수 (tdd-cycle-gate.sh Hook 강제)
     [CHORE] → TDD 면제
---
{Planner가 생성한 6-Section 프롬프트}
"""
)
```

---

## Research Group (Phase 1 — 조건부 병렬 호출)

> 해당 에이전트만 선택적으로 병렬 호출합니다. 모두 호출할 필요 없음.

```
Task(
  subagent_type: "Explore", model: "haiku",
  description: "Explorer: 코드베이스 탐색",
  prompt: """
**Explorer** - 내부 코드베이스 탐색
도구: Glob, Grep, Read
제약: 파일 수정 금지 (읽기 전용)
---
## 사용자 요청
{요청 내용}
## Expected Output
[Explorer] 코드베이스 분석 결과
- 관련 파일: [목록]
- 구조 분석: [요약]
"""
)

Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Searcher: 외부 문서 검색",
  prompt: """
**Searcher** - 외부 문서/라이브러리 검색
도구: WebSearch, WebFetch, MCP(Context7)
제약: 파일 수정 금지
---
## 사용자 요청
{요청 내용}
## Expected Output
[Searcher] 외부 문서 검색 결과
- 관련 문서: [목록]
- 베스트 프랙티스: [요약]
"""
)

Task(
  subagent_type: "general-purpose", model: "opus",
  description: "Architecture: 아키텍처 분석",
  prompt: """
**Architecture** - 아키텍처 조언 및 설계 분석
도구: Read, Grep, Glob
제약: 파일 수정 금지 (조언만)
---
## 사용자 요청
{요청 내용}
## Expected Output
[Architecture] 아키텍처 분석 결과
- 설계 권장: [내용]
- 패턴 제안: [목록]
"""
)

Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Image-Analyst: 이미지 분석",
  prompt: """
**Image-Analyst** - UI 스크린샷, 에러 화면, 디자인 목업, 아키텍처 다이어그램 분석
도구: Read (이미지 파일 읽기)
제약: Edit, Write, Bash 금지 (읽기 전용, 분석 결과만 반환)
---
## 분석 대상
{이미지 파일 경로 목록}
## 분석 유형
{UI 분석 | 에러 분석 | 디자인 분석 | 다이어그램 해석}
## Expected Output
[Image-Analyst] 이미지 분석 결과
- 분석 유형: {type}
- 발견 사항: [목록]
- 구조 설명: [요약]
- 관련 컴포넌트: [추정 목록]
"""
)
```

---

## Code-Review Group (Phase 6a-CR 병렬 - 5개 동시 호출)

> Verification 6-Stage 통과 후에만 호출

```
Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Security Guardian: 보안 취약점 검사",
  prompt: """
**Security Guardian** - 보안 취약점 탐지 (Auto-Block 권한)
도구: Read, Grep, Glob
제약: Edit, Write, Bash 금지 (읽기 전용)
---
## 리뷰 대상
{변경된 파일 목록}
## 검토 항목 (Critical → Auto-Block)
1. Hardcoded Credentials (Critical)  2. SQL Injection (Critical)
3. XSS Vulnerability (Critical)  4. Auth Bypass (Critical)
5. Input Validation (High)  6. Insecure Crypto (High)  7. CSRF (High)
## Expected Output
[Security Guardian] Report
- Critical: {N} | High: {N}
- Auto-Block: Yes/No
- **Result: ✅/⚠️/❌**
"""
)

Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Quality Inspector: 코드 품질 검사",
  prompt: """
**Quality Inspector** - 코드 품질 평가
도구: Read, Grep, Glob
제약: Edit, Write, Bash 금지 (읽기 전용)
---
## 리뷰 대상
{변경된 파일 목록}
## 검토 항목
1. Function Size >50줄 (Medium)  2. File Size >800줄 (Medium)
3. Nesting Depth >3 (Medium)  4. Error Handling 누락 (High)
5. Magic Numbers (Low)  6. Dead Code (Low)
7. Duplicate Code (Medium)  8. Naming 불명확 (Low)
## Expected Output
[Quality Inspector] Report
- High: {N} | Medium: {N} | Low: {N}
- **Result: ✅/⚠️/❌**
"""
)

Task(
  subagent_type: "general-purpose", model: "haiku",
  description: "Performance Analyst: 성능 이슈 분석",
  prompt: """
**Performance Analyst** - 성능 이슈 탐지
도구: Read, Grep, Glob
제약: Edit, Write, Bash 금지 (읽기 전용)
---
## 리뷰 대상
{변경된 파일 목록}
## 검토 항목
1. Algorithm Complexity O(n2)+ (Medium)  2. Unnecessary Re-render (Medium)
3. N+1 Query (High)  4. Memory Leak (High)
5. Large Bundle (Low)  6. Missing Memoization (Low)
## Expected Output
[Performance Analyst] Report
- High: {N} | Medium: {N} | Low: {N}
- **Result: ✅/⚠️/❌**
"""
)

Task(
  subagent_type: "general-purpose", model: "haiku",
  description: "Standards Keeper: 표준 준수 검사",
  prompt: """
**Standards Keeper** - 표준 및 컨벤션 검증
도구: Read, Grep, Glob
제약: Edit, Write, Bash 금지 (읽기 전용)
---
## 리뷰 대상
{변경된 파일 목록}
## 검토 항목
1. Naming Convention (Low)  2. Documentation 누락 (Low)
3. Accessibility (Medium)  4. Test Coverage (Medium)  5. TypeScript any 사용 (Low)
## Expected Output
[Standards Keeper] Report
- Medium: {N} | Low: {N}
- **Result: ✅/⚠️/❌**
"""
)

Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "TDD Enforcer: TDD 순서 검증",
  prompt: """
**TDD Enforcer** - TDD 순서 및 테스트 품질 검증 (Auto-Block 권한)
도구: Read, Grep, Glob
제약: Edit, Write, Bash 금지 (읽기 전용)
---
## 리뷰 대상
{변경된 파일 목록}
## 검토 항목 (Deleted Test → Auto-Block)
1. Missing Test (High)  2. Test-After-Impl (High)
3. Deleted Test (Critical - Auto-Block)  4. Skipped Test (High)
5. Test-less Refactor (Medium)  6. Insufficient Assertion (Medium)  7. Mock Overuse (Low)
## Expected Output
[TDD Enforcer] Report
- TDD Compliance: {source → test 매칭표}
- Critical: {N} | High: {N}
- Auto-Block: Yes/No
- **Result: ✅/⚠️/❌**
"""
)
```

### Code-Review 결과 통합 (Weighted Scoring)

```
score_map = {"Approved": 1.0, "Warning": 0.5, "Block": 0.0}
weighted_score = (4*Security + 3*Quality + 2*Performance + 2*Standards + 4*TDD) / 15

Auto-Block 조건:
- Security Guardian: Critical 이슈 발견
- TDD Enforcer: 테스트 삭제 감지

판정:
- Auto-Block → ❌ Block
- >= 0.80 → ✅ Approved
- 0.50-0.79 → ⚠️ Warning
- < 0.50 → ❌ Block

에이전트 응답 실패 시:
- 3명 이상 응답 → 유효 (응답한 에이전트 가중치로 계산)
- 2명 이하 → 재시도 1회, 이후 사용자 에스컬레이션
```

---

## Conflict-Checker (sonnet)

> Level에 2개 이상 TODO가 병렬 실행된 경우에만 호출

```
Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Conflict-Checker: 병렬 실행 충돌 검사",
  prompt: """
**Conflict-Checker** - 병렬 실행 충돌 감지
도구: Read, Grep, Glob, Bash (git diff, npm test, tsc, eslint)
제약: Edit, Write, Task 금지 (분석만)
---
## 병렬 실행된 TODOs
{completedTodos 목록 - ID, 변경 파일, 요약}
## Expected Output
충돌 없음: [Conflict-Checker] No conflicts detected
충돌 있음: [Conflict-Checker] Conflict Report
- Conflicts: {N}
- Primary: {id} (유지), Secondary: {id} (재작업)
"""
)
```

---

## Journal-Reporter (haiku) — Phase 7

> Commit 이후 Journal 리포트 작성

```
Task(
  subagent_type: "general-purpose", model: "haiku",
  description: "Journal-Reporter: Journal 리포트 작성",
  prompt: """
**Journal-Reporter** - 구조화된 Journal 리포트 작성
도구: Read, Write(.orchestra/journal/), Glob, Grep
제약: Edit, Bash, Task 금지 (리포트 작성만)
---
## Journal Type
{open-ended | session}

## Context
- Plan: {planName}
- Summary: {작업 요약}
- TODOs: {완료된 TODO 목록과 결과}
- Changed Files: {변경 파일 목록}
- Verification: {mode, PR Ready, blockers}
- Code-Review: {점수, 판정}
- Decisions: {주요 결정 사항}
- Issues: {발견된 이슈}
- Next Steps: {후속 작업}

## Expected Output
[Journal-Reporter] Journal 작성 완료
- Type: {open-ended|session}
- Path: .orchestra/journal/{filename}.md
- Sections: {N}/{total}
"""
)
```

---

## Explorer (EXPLORATORY Intent)

```
Task(
  subagent_type: "Explore",
  description: "코드베이스 탐색: {검색 대상}",
  prompt: "{검색 요청}"
)
```

---

## Log-Analyst (sonnet)

```
Task(
  subagent_type: "general-purpose", model: "sonnet",
  description: "Log-Analyst: 로그 분석",
  prompt: """
**Log-Analyst** - 로그 분석, 오류 진단, 통계 생성
도구: Read, Glob, Grep, Bash (ls, wc, tail, head)
제약: 파일 수정 금지, Task/Edit/Write 금지
---
## Context
{로그 경로/상황}
## Expected Output
[Log-Analyst] Analysis Report
- Summary: {요약}
- Findings: {발견 사항}
"""
)
```

---

## Rework Prompt Template

```
Task(
  subagent_type: "general-purpose",
  model: "{original executor model}",
  description: "{Executor}: {todo-id} 재작업 (Rework {N}/3)",
  prompt: """
**{Executor}** - Rework Context

### 이슈 정보
- Type: {conflict/review issue type}
- Severity: {Critical | High}
- File: {affected files}

### 원래 작업
{원래 6-Section 프롬프트}

### 수정 제약사항
1. 기존 변경사항과 충돌하지 않도록 구현
2. {구체적 제약사항}

### 권장 해결 방법
{Conflict-Checker/Code-Review Group 제안}
---
위 제약사항을 준수하며 원래 작업 목표를 달성하세요.
"""
)
```

---

## 위임 규칙 (agent-rules 통합)

### 에이전트 계층
```
USER INTERACTION: Maestro (= Claude Code)
PLANNING: Research-Team | Interviewer | Planner
RESEARCH: Architecture | Searcher | Explorer | Image-Analyst | Log-Analyst
EXECUTION: High-Player | Low-Player
VERIFICATION: Conflict-Checker
REVIEW: Code-Review Group (5명)
JOURNAL: Journal-Reporter (Phase 7)
```

### 위임 형식 (6-Section 프롬프트)
```markdown
## 1. TASK       - TODO 내용
## 2. EXPECTED OUTCOME - 기대 결과
## 3. REQUIRED TOOLS   - 허용 도구
## 4. MUST DO          - 필수 사항
## 5. MUST NOT DO      - 금지 사항
## 6. CONTEXT          - 컨텍스트 정보
```

### 금지 패턴
- 위임 체인: Planner → High-Player → Low-Player (재위임 금지)
- 역위임: Low-Player → Planner (역방향 금지)
