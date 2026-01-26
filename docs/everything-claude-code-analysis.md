# Everything Claude Code - 심층 분석 보고서

> **저장소**: https://github.com/affaan-m/everything-claude-code
> **분석일**: 2026-01-25
> **버전**: Anthropic 해커톤 우승자의 10개월+ 실전 검증 설정

---

## 1. 프로젝트 개요

### 1.1 핵심 정보

| 항목 | 내용 |
|------|------|
| **목적** | Claude Code CLI를 위한 프로덕션급 설정 컬렉션 |
| **주요 언어** | JavaScript (66KB), Shell (9KB) |
| **라이선스** | MIT |
| **생성일** | 2026-01-18 |
| **특징** | 토큰 최적화, 메모리 지속성, 연속 학습, 검증 루프, 병렬화, 서브에이전트 오케스트레이션 |

### 1.2 철학적 접근

이 프로젝트는 **"battle-tested"** 설정이라는 점이 핵심입니다. 10개월 이상의 집중적인 일일 사용을 통해 다듬어진 설정들로, 단순한 예제가 아닌 실제 프로덕션 환경에서 검증된 구성을 제공합니다.

---

## 2. 디렉토리 구조 분석

```
everything-claude-code/
├── .claude/                 # Claude 설정
│   └── package-manager.json # 패키지 매니저 자동 감지
├── .claude-plugin/          # 플러그인 배포 설정
│   ├── marketplace.json
│   └── plugin.json
├── agents/                  # 9개 전문 에이전트
├── commands/                # 15개 슬래시 명령어
├── contexts/                # 3개 컨텍스트 모드
├── examples/                # 예제 프로젝트 설정
├── hooks/                   # 이벤트 트리거 자동화
├── mcp-configs/             # MCP 서버 설정
├── plugins/                 # 플러그인 확장
├── rules/                   # 8개 상시 적용 규칙
├── scripts/                 # 크로스 플랫폼 유틸리티
├── skills/                  # 11개 워크플로우 정의
└── tests/                   # 테스트 파일
```

---

## 3. 에이전트 시스템 (Agents)

### 3.1 에이전트 목록

| 에이전트 | 역할 | 주요 기능 |
|----------|------|-----------|
| **planner** | 계획 수립 전문가 | 복잡한 기능 분해, 의존성 파악, 리스크 평가 |
| **architect** | 아키텍처 설계 | 시스템 설계, 트레이드오프 분석, ADR 작성 |
| **code-reviewer** | 코드 리뷰 자동화 | 보안/품질/성능 25+ 차원 평가 |
| **security-reviewer** | 보안 전문가 | OWASP Top 10, 자동화 스캔 (npm audit, semgrep) |
| **tdd-guide** | TDD 가이드 | RED-GREEN-REFACTOR 사이클 강제 |
| **e2e-runner** | E2E 테스트 전문가 | Playwright 기반, 아티팩트 관리 |
| **build-error-resolver** | 빌드 오류 해결 | 컴파일 실패 대응 |
| **refactor-cleaner** | 리팩토링 | 미사용 코드 제거 |
| **doc-updater** | 문서 관리 | 문서 동기화 유지 |

### 3.2 Planner 에이전트 상세

```markdown
## 핵심 책임

**요구사항 단계**
- 산출물 이해
- 모호성 명확화
- 성공 지표 정의

**아키텍처 검토**
- 코드베이스 구조 분석
- 영향 영역 식별
- 재사용 패턴 인식

**상세 분해**
- 단계별 구현 계획
- 파일 위치 명시
- 복잡도 및 리스크 평가
```

### 3.3 Code Reviewer 에이전트 상세

**리뷰 카테고리**:
- 보안 (하드코딩된 자격증명, SQL 인젝션, XSS)
- 코드 품질 (함수 크기, 중첩 깊이, 에러 핸들링)
- 성능 (알고리즘 효율성, React 최적화)
- 베스트 프랙티스 (네이밍 컨벤션, 문서화, 접근성)

**승인 레벨**:
| 상태 | 조건 |
|------|------|
| ✅ Approve | Critical/High 이슈 없음 |
| ⚠️ Warning | Medium 이슈만 존재 |
| ❌ Block | Critical/High 이슈 존재 |

### 3.4 Security Reviewer 에이전트 상세

**검사 대상**:
- OWASP Top 10 취약점
- 하드코딩된 시크릿
- 인젝션 공격
- 안전하지 않은 암호화
- 인증 결함

**자동화 도구**:
- `npm audit` - 의존성 보안
- `eslint-plugin-security` - 코드 보안 린트
- `trufflehog` - 시크릿 탐지
- `semgrep` - 정적 분석

**위험 패턴 예시**:
```javascript
// ❌ 위험
const apiKey = 'sk-proj-xxxxx';
const query = `SELECT * FROM users WHERE id = ${userId}`;
element.innerHTML = userInput;

// ✅ 안전
const apiKey = process.env.OPENAI_API_KEY;
const query = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
element.textContent = sanitize(userInput);
```

---

## 4. 명령어 시스템 (Commands)

### 4.1 명령어 목록

| 명령어 | 설명 |
|--------|------|
| `/tdd` | TDD 워크플로우 시작 |
| `/plan` | 구현 계획 수립 |
| `/orchestrate` | 에이전트 순차 실행 |
| `/verify` | 코드베이스 검증 |
| `/code-review` | 코드 리뷰 실행 |
| `/e2e` | E2E 테스트 실행 |
| `/build-fix` | 빌드 오류 해결 |
| `/learn` | 재사용 패턴 추출 |
| `/checkpoint` | 체크포인트 생성 |
| `/eval` | 코드 평가 |
| `/refactor-clean` | 리팩토링/정리 |
| `/setup-pm` | 패키지 매니저 설정 |
| `/test-coverage` | 테스트 커버리지 확인 |
| `/update-codemaps` | 코드맵 업데이트 |
| `/update-docs` | 문서 업데이트 |

### 4.2 /tdd 명령어 상세

```markdown
## 핵심 워크플로우: RED → GREEN → REFACTOR → REPEAT

1. 인터페이스 스캐폴딩
2. 테스트 먼저 생성
3. 최소 코드 구현
4. 리팩토링
5. 커버리지 검증 (80%+)

## 커버리지 기준
- 일반 코드: 80%+
- 금융 계산: 100%
- 인증: 100%
- 보안 관련: 100%
- 핵심 비즈니스 로직: 100%
```

### 4.3 /orchestrate 명령어 상세

**워크플로우 유형**:

| 워크플로우 | 설명 | 에이전트 순서 |
|------------|------|---------------|
| **feature** | 전체 기능 구현 | planner → tdd → code-reviewer → security-reviewer |
| **bugfix** | 버그 수정 | exploration → testing |
| **refactor** | 안전한 리팩토링 | architect → code-reviewer |
| **security** | 보안 중심 리뷰 | security-reviewer (우선) |
| **custom** | 사용자 정의 | 직접 에이전트 지정 |

**핸드오프 문서**:
에이전트 간 전환 시 컨텍스트, 발견사항, 미해결 질문을 포함한 구조화된 문서가 전달됩니다.

### 4.4 /verify 명령어 상세

**5단계 검증 프로세스**:

```
1. 빌드 검증 → 실패시 STOP
2. 타입 체크 → 라인별 에러 보고
3. 린트 → 경고/에러 리포트
4. 테스트 실행 → 패스/실패 메트릭 + 커버리지
5. 보안/클린업 → console.log 감사, git 상태 확인
```

**실행 모드**:
- `quick`: 빌드 + 타입만
- `full`: 전체 검증
- `pre-commit`: 커밋 전 체크
- `pre-pr`: 보안 스캔 포함 전체 체크

### 4.5 /learn 명령어 상세

**추출 대상**:
- 에러 해결 패턴
- 디버깅 기법
- 라이브러리/API 워크어라운드
- 프로젝트별 아키텍처 발견

**제외 대상**:
- 사소한 수정 (오타 등)
- 일회성 이슈 (서비스 장애)
- 복수 개념 혼합

**저장 위치**: `~/.claude/skills/learned/`

---

## 5. 스킬 시스템 (Skills)

### 5.1 스킬 목록

| 스킬 | 설명 |
|------|------|
| **tdd-workflow** | TDD 워크플로우 정의 |
| **verification-loop** | 검증 루프 시스템 |
| **strategic-compact** | 전략적 컨텍스트 압축 |
| **continuous-learning** | 연속 학습 패턴 추출 |
| **backend-patterns** | 백엔드 패턴 |
| **frontend-patterns** | 프론트엔드 패턴 |
| **coding-standards** | 코딩 표준 |
| **security-review** | 보안 리뷰 |
| **clickhouse-io** | ClickHouse 연동 |
| **eval-harness** | 평가 하네스 |
| **project-guidelines-example** | 프로젝트 가이드라인 예제 |

### 5.2 TDD Workflow 스킬 상세

**7단계 워크플로우**:

```
1. 사용자 여정 작성
2. 테스트 케이스 생성
3. 실패 테스트 실행 (RED)
4. 코드 구현 (GREEN)
5. 테스트 통과 검증
6. 리팩토링
7. 커버리지 메트릭 확인
```

**테스트 유형별 패턴**:
- **Unit**: Jest/Vitest + React Testing Library
- **Integration**: Next.js API 엔드포인트
- **E2E**: Playwright 사용자 워크플로우

**모킹 전략**:
- Supabase
- Redis
- OpenAI

### 5.3 Verification Loop 스킬 상세

**6단계 검증**:

| 단계 | 설명 |
|------|------|
| 1. Build Verification | 프로젝트 컴파일 확인 |
| 2. Type Check | TypeScript/Python 타입 안전성 |
| 3. Lint Check | 코드 스타일 준수 |
| 4. Test Suite | 테스트 + 커버리지 (80%+) |
| 5. Security Scan | 노출된 자격증명, 디버그 문 |
| 6. Diff Review | 의도치 않은 변경 검사 |

**권장 실행 주기**:
- 15분마다
- 주요 코드 변경 후
- 함수/컴포넌트 완료 시

### 5.4 Strategic Compact 스킬 상세

**핵심 개념**:
자동 컴팩션이 아닌 **논리적 경계에서의 의도적 컴팩션**

```
탐색 완료 후 → 실행 전: 연구 컨텍스트 압축, 구현 계획 유지
```

**권장 시점**:
- 계획 확정 후, 구현 시작 전
- 디버깅 및 에러 해결 완료 후
- 작업 단계 전환 전

**주의사항**:
구현 중간에는 컴팩션 금지 (관련 코드 변경 컨텍스트 손실 위험)

### 5.5 Continuous Learning 스킬 상세

**동작 방식**: Stop 훅 (세션 종료 시 실행)

**프로세스**:
1. 세션 길이 검증 (최소 임계값)
2. 대화에서 추출 가능한 패턴 스캔
3. 식별된 패턴을 로컬에 스킬로 저장

**설정 가능 항목** (`config.json`):
- 최소 메시지 수
- 탐지 민감도
- 저장 위치
- 패턴 카테고리 (5가지)
- 제외 규칙

---

## 6. 훅 시스템 (Hooks)

### 6.1 훅 카테고리

| 훅 유형 | 트리거 시점 | 용도 |
|---------|-------------|------|
| **PreToolUse** | 도구 실행 전 | 검증, 파라미터 수정 |
| **PostToolUse** | 도구 실행 후 | 자동 포맷, 체크 |
| **SessionStart** | 세션 시작 | 이전 컨텍스트 로드 |
| **SessionEnd** | 세션 종료 | 상태 저장 |
| **Stop** | 응답 종료 | 최종 검증 |

### 6.2 주요 훅 기능

**PreToolUse 훅**:
```json
{
  "훅": "tmux 강제",
  "설명": "개발 서버는 tmux 세션 내에서만 실행"
},
{
  "훅": "장시간 명령 경고",
  "대상": ["npm install", "cargo build", "pip install"]
},
{
  "훅": "git push 검토",
  "설명": "push 전 변경사항 검토 알림"
},
{
  "훅": "마크다운 차단",
  "설명": "불필요한 .md 파일 생성 방지"
}
```

**PostToolUse 훅**:
```json
{
  "훅": "자동 포맷팅",
  "대상": "JavaScript/TypeScript 파일",
  "도구": "Prettier"
},
{
  "훅": "타입 체크",
  "설명": "TypeScript 컴파일 검사"
},
{
  "훅": "console.log 감지",
  "설명": "디버그 문 경고"
}
```

### 6.3 권장 사항

- `dangerously-skip-permissions` 플래그 사용 금지
- `allowedTools` 설정 파일로 관리
- auto-accept는 잘 정의된 작업에만 적용

---

## 7. 규칙 시스템 (Rules)

### 7.1 규칙 목록

| 규칙 | 설명 |
|------|------|
| **security.md** | 보안 가이드라인 |
| **testing.md** | 테스팅 요구사항 |
| **patterns.md** | 공통 패턴 |
| **agents.md** | 에이전트 오케스트레이션 |
| **hooks.md** | 훅 시스템 가이드 |
| **git-workflow.md** | Git 워크플로우 |
| **coding-style.md** | 코딩 스타일 |
| **performance.md** | 성능 가이드라인 |

### 7.2 Security Rules 상세

**8가지 필수 체크**:
1. 하드코딩된 시크릿 방지
2. 입력 검증
3. SQL 인젝션 완화
4. XSS 보호
5. CSRF 방어
6. 인증 검증
7. 레이트 리미팅
8. 안전한 에러 핸들링

**인시던트 대응 프로토콜**:
```
1. 작업 즉시 중단
2. security-reviewer 에이전트 호출
3. 크리티컬 취약점 해결
4. 자격증명 손상 시 교체
5. 유사 패턴 코드베이스 전체 검토
```

### 7.3 Testing Rules 상세

**커버리지 요구사항**: **80% 최소**

**테스트 유형**:
- Unit: 격리된 함수/컴포넌트
- Integration: API/DB 작업
- E2E: Playwright 기반 사용자 플로우

**TDD 워크플로우**:
```
1. 테스트 작성 (RED)
2. 실패 확인
3. 최소 코드 구현
4. 성공 검증
5. 리팩토링
6. 커버리지 확인 (80%+)
```

### 7.4 Git Workflow Rules 상세

**커밋 메시지 형식**:
```
<type>: <description>

[optional body]
```

**허용 타입**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

**기능 개발 프로세스**:
```
1. Planning: planner 에이전트로 로드맵 수립
2. Testing: TDD 원칙 적용, 80%+ 커버리지
3. Review: code-reviewer 에이전트 호출
4. Finalization: 상세 커밋 메시지, -u 플래그로 push
```

### 7.5 Agent Orchestration Rules 상세

**즉시 에이전트 배포 시나리오**:

| 상황 | 에이전트 |
|------|----------|
| 복잡한 기능 구현 | planner |
| 새 코드/수정 코드 | code-reviewer |
| 버그 수정/새 기능 | tdd-guide |
| 설계 결정 | architect |

**실행 전략**:
- **병렬 처리**: 독립적인 작업은 항상 병렬 Task 실행
- **다중 관점 리뷰**: 복잡한 이슈는 전문화된 서브에이전트 배포
  - 사실 검토자
  - 시니어 엔지니어
  - 보안 전문가
  - 일관성 검토자
  - 중복 검사자

---

## 8. MCP 설정 (Model Context Protocol)

### 8.1 지원 서버

**명령어 기반 서버**:
| 서버 | 기능 |
|------|------|
| GitHub | PR, 이슈, 저장소 관리 |
| Firecrawl | 웹 스크래핑/크롤링 |
| Supabase | 데이터베이스 작업 |
| Memory | 세션 간 메모리 지속 |
| Sequential-thinking | 논리적 추론 |
| Railway | 배포 관리 |
| Context7 | 실시간 문서 조회 |
| Magic | UI 컴포넌트 |

**HTTP 기반 서버**:
| 서버 | 기능 |
|------|------|
| Vercel | 배포/프로젝트 관리 |
| Cloudflare | 문서, Workers, 바인딩, 관찰성 |
| ClickHouse | 분석 쿼리 |

**파일시스템**:
- 로컬 프로젝트 디렉토리 접근

### 8.2 중요 권장사항

```
⚠️ 최대 10개 MCP 활성화 권장
   - 너무 많이 활성화 시 컨텍스트 윈도우 200k → 70k로 감소
   - 20-30개 설정, 10개 미만 활성화 권장
   - 프로젝트별 disabledMcpServers 배열로 선택적 비활성화
```

---

## 9. 컨텍스트 시스템 (Contexts)

### 9.1 컨텍스트 목록

| 컨텍스트 | 설명 |
|----------|------|
| **dev.md** | 개발 모드 - 구현 중심 |
| **research.md** | 연구 모드 |
| **review.md** | 리뷰 모드 |

### 9.2 Development Context 상세

**핵심 동작 원칙**:
```
1. "Write code first, explain after"
2. "Prefer working solutions over perfect solutions"
3. 코드 변경 후 테스트 실행
4. 원자적 커밋 구조 유지
```

**우선순위**:
```
1위: 기능성 (Functionality)
2위: 정확성 (Correctness)
3위: 코드 품질 (Code Quality)
```

**권장 도구**:
- Edit/Write: 코드 수정
- Bash: 테스트/빌드
- Grep/Glob: 코드 탐색

---

## 10. 설치 및 사용법

### 10.1 설치 방법

**방법 1: 플러그인 마켓플레이스 (권장)**
```bash
/plugin marketplace add affaan-m/everything-claude-code
/plugin install everything-claude-code@everything-claude-code
```

**방법 2: 수동 설치**
```bash
# 특정 컴포넌트를 ~/.claude/ 디렉토리에 복사
cp -r agents ~/.claude/
cp -r commands ~/.claude/
cp -r skills ~/.claude/
cp -r rules ~/.claude/
cp -r hooks ~/.claude/
```

### 10.2 크로스 플랫폼 지원

- **Windows, macOS, Linux** 지원
- 자동 패키지 매니저 감지 (npm, pnpm, yarn, bun)

---

## 11. 예제 프로젝트 구조

### 11.1 CLAUDE.md 예제

**코드 조직**:
- 많은 작은 파일 > 적은 큰 파일
- 일반적: 200-400 라인
- 최대: 800 라인
- 타입별이 아닌 기능별 조직

**코드 스타일**:
- 불변성 강조
- try/catch 에러 핸들링
- Zod로 입력 검증
- 프로덕션에서 console.log 금지

**디렉토리 구조**:
```
src/
├── app/
├── components/
├── hooks/
├── lib/
└── types/
```

**표준 API 응답**:
```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
  };
}
```

---

## 12. 주요 패턴

### 12.1 API 응답 형식

```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  pagination?: PaginationMeta;
}
```

### 12.2 Custom Hooks 패턴

```typescript
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

### 12.3 Repository 패턴

```typescript
interface Repository<T> {
  findAll(): Promise<T[]>;
  findById(id: string): Promise<T | null>;
  create(data: Partial<T>): Promise<T>;
  update(id: string, data: Partial<T>): Promise<T>;
  delete(id: string): Promise<void>;
}
```

### 12.4 스켈레톤 프로젝트 전략

```
1. 확립된 스타터 프로젝트 탐색
2. 병렬 에이전트로 평가 (보안, 확장성, 관련성)
3. 최적 매치를 기반으로 사용
4. 해당 프레임워크 내에서 반복 개발
```

---

## 13. Claude Orchestra와의 비교

### 13.1 공통점

| 항목 | Everything Claude Code | Claude Orchestra |
|------|------------------------|------------------|
| TDD 강제 | ✅ 80%+ 커버리지 | ✅ TDD Guard 훅 |
| 에이전트 시스템 | ✅ 9개 전문 에이전트 | ✅ 11개 전문 에이전트 |
| 계획 수립 | ✅ planner 에이전트 | ✅ Planner + Interviewer |
| 보안 리뷰 | ✅ security-reviewer | ✅ 코드 리뷰에 통합 |
| 상태 관리 | ✅ 훅 기반 | ✅ state.json 기반 |

### 13.2 차이점

| 항목 | Everything Claude Code | Claude Orchestra |
|------|------------------------|------------------|
| **구조** | 모듈형 플러그인 | 통합 오케스트레이션 |
| **Intent 분류** | 없음 (수동) | ✅ Maestro의 Intent Gate |
| **계획 검증** | 없음 | ✅ Plan-Checker, Plan-Reviewer |
| **TODO 태그** | 없음 | ✅ [TEST], [IMPL], [REFACTOR] |
| **6-Section 프롬프트** | 없음 | ✅ Executor 위임용 |
| **자동 커밋** | 수동 | ✅ TODO 완료 시 자동 |
| **컨텍스트 관리** | Strategic Compact | 자동 요약 |
| **학습 기능** | ✅ Continuous Learning | 없음 |
| **MCP 통합** | ✅ 다양한 서버 | 제한적 |

### 13.3 통합 가능성

Everything Claude Code의 여러 기능을 Claude Orchestra에 통합하면 더 강력한 시스템 구축 가능:

1. **Continuous Learning 스킬**: 세션 패턴 자동 학습
2. **Strategic Compact**: 컨텍스트 효율적 관리
3. **MCP 설정**: 외부 서비스 통합 확장
4. **Verification Loop**: 더 체계적인 검증 단계

---

## 14. 권장 사항

### 14.1 도입 우선순위

**High Priority**:
1. TDD Workflow 스킬
2. Verification Loop 스킬
3. Security Rules
4. Code Reviewer 에이전트

**Medium Priority**:
5. Strategic Compact 스킬
6. Continuous Learning 스킬
7. Git Workflow Rules
8. Hooks 시스템

**Low Priority**:
9. MCP 설정 (필요시)
10. 기타 컨텍스트

### 14.2 주의사항

1. **MCP 과다 활성화 금지**: 컨텍스트 윈도우 급감
2. **Strategic Compact 시점 준수**: 구현 중 컴팩션 금지
3. **보안 규칙 최우선**: 커밋 전 반드시 검증
4. **TDD 순서 준수**: 테스트 먼저, 구현 후

---

## 15. 핵심 기능 심층 분석

### 15.1 Continuous Learning (연속 학습)

#### 핵심 개념
세션 종료 시 대화에서 **재사용 가능한 패턴을 자동으로 추출**하여 스킬 파일로 저장하는 시스템입니다.

#### 작동 방식

```
┌─────────────────────────────────────────────────────────────┐
│                    세션 진행 중                              │
│  사용자 ↔ Claude 대화 (에러 해결, 디버깅, 워크어라운드 등)   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    세션 종료 (Stop Hook)                     │
│  1. 세션 길이 검증 (min_session_length: 10 메시지 이상)      │
│  2. CLAUDE_TRANSCRIPT_PATH에서 대화 내용 로드               │
│  3. 패턴 감지 및 추출                                        │
│  4. ~/.claude/skills/learned/ 에 스킬 파일 저장             │
└─────────────────────────────────────────────────────────────┘
```

#### 설정 (config.json)

```json
{
  "min_session_length": 10,        // 최소 10개 메시지 필요
  "extraction_threshold": "medium", // 감지 민감도
  "auto_approve": false,           // 수동 승인 필요
  "learned_skills_path": "~/.claude/skills/learned/",

  "pattern_categories": [
    "error_resolution",     // 에러 해결 패턴
    "user_corrections",     // 사용자 수정 피드백
    "workarounds",          // 라이브러리/API 우회
    "debugging_techniques", // 디버깅 기법
    "project_specific"      // 프로젝트 고유 패턴
  ],

  "exclusions": [
    "simple_typos",         // 단순 오타 제외
    "one_time_fixes",       // 일회성 수정 제외
    "external_api_issues"   // 외부 API 장애 제외
  ]
}
```

#### Stop Hook을 선택한 이유

| 방식 | 실행 시점 | 단점 |
|------|-----------|------|
| UserPromptSubmit | 매 메시지마다 | 무거움, 지연 발생 |
| **Stop (선택됨)** | 세션 종료 시 1회 | 가벼움, 전체 컨텍스트 접근 가능 |

#### 저장되는 스킬 파일 예시

```markdown
# Error: TypeScript strict null checks

## Problem
`Object is possibly 'undefined'` 에러가 자주 발생

## Solution
Optional chaining과 nullish coalescing 사용

\`\`\`typescript
// Before
const name = user.profile.name;

// After
const name = user?.profile?.name ?? 'Unknown';
\`\`\`

## When to Use
- TypeScript strict 모드에서 중첩 객체 접근 시
- API 응답 데이터 처리 시

## Trigger
`TS2532`, `Object is possibly`, `undefined` 에러 메시지
```

---

### 15.2 Strategic Compact (전략적 컴팩션)

#### 핵심 개념
**자동 컴팩션의 문제점을 해결**하기 위해 논리적 경계에서 의도적으로 컨텍스트를 압축하는 전략입니다.

#### 자동 vs 전략적 컴팩션

| 자동 컴팩션 | 전략적 컴팩션 |
|-------------|---------------|
| 임의의 시점에 발생 | 논리적 경계에서 발생 |
| 작업 중간에 끊길 수 있음 | 단계 전환 시점에 실행 |
| 컨텍스트 손실 위험 | 컨텍스트 보존 |

#### 작동 방식

```
┌─────────────────────────────────────────────────────────────┐
│              suggest-compact.sh (PreToolUse Hook)           │
├─────────────────────────────────────────────────────────────┤
│  1. /tmp/claude_tool_count 파일로 도구 호출 횟수 추적        │
│  2. Edit/Write 도구 사용 시 카운터 증가                     │
│  3. 50회 도달 시 첫 번째 컴팩션 제안                        │
│  4. 이후 25회마다 리마인더 제공                             │
└─────────────────────────────────────────────────────────────┘
```

#### 권장 컴팩션 시점

```
✅ 좋은 시점                        ❌ 나쁜 시점
─────────────────────────────────────────────────────
탐색 완료 → 구현 시작 전            구현 중간
계획 확정 후                        테스트 작성 중
디버깅 완료 후                      에러 해결 중
작업 단계 전환 전                   관련 파일 수정 중
```

#### 설정 방법

```json
// ~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "~/.claude/skills/strategic-compact/suggest-compact.sh"
      }
    ]
  }
}
```

#### 실제 사용 시나리오

```
세션 시작
    │
    ▼
[탐색 단계] - 30회 도구 호출
코드베이스 분석, 패턴 파악
    │
    ▼
[50회 도달] → "컴팩션 권장: 탐색 완료, 구현 시작 전 압축하세요"
    │
    ▼
사용자: /compact  ← 연구 컨텍스트 압축, 구현 계획 유지
    │
    ▼
[구현 단계] - 25회 추가 도구 호출
    │
    ▼
[75회 도달] → 리마인더 제공
```

---

### 15.3 Verification Loop (검증 루프)

#### 핵심 개념
**6단계 순차 검증**으로 코드 품질을 보장하는 체계적인 시스템입니다.

#### 6단계 검증 프로세스

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: BUILD VERIFICATION                                │
│  ─────────────────────────────                              │
│  프로젝트 빌드 실행                                          │
│  실패 시 → STOP (이후 단계 진행 불가)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓ 성공
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: TYPE CHECK                                        │
│  ─────────────────                                          │
│  TypeScript/Python 타입 안전성 검증                         │
│  라인별 에러 리포트 생성                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: LINT CHECK                                        │
│  ───────────────────                                        │
│  ESLint/Prettier 코드 스타일 검사                           │
│  경고/에러 목록 생성                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: TEST SUITE                                        │
│  ─────────────────                                          │
│  전체 테스트 실행                                            │
│  커버리지 메트릭 수집 (목표: 80%+)                           │
│  패스/실패 카운트                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 5: SECURITY SCAN                                     │
│  ──────────────────────                                     │
│  하드코딩된 시크릿 탐지                                      │
│  console.log/디버그 문 검색                                  │
│  노출된 자격증명 확인                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 6: DIFF REVIEW                                       │
│  ─────────────────────                                      │
│  변경 파일 목록 확인                                         │
│  의도치 않은 수정 탐지                                       │
│  git status 확인                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  VERIFICATION REPORT                                        │
│  ════════════════════                                       │
│  Build:    ✅ PASS                                          │
│  Types:    ✅ PASS                                          │
│  Lint:     ⚠️  3 warnings                                   │
│  Tests:    ✅ 47/47 passed (Coverage: 84%)                  │
│  Security: ✅ No issues                                     │
│  Diff:     ✅ 5 files changed                               │
│  ──────────────────────────────────────────────             │
│  PR Ready: ✅ YES                                           │
└─────────────────────────────────────────────────────────────┘
```

#### 실행 모드

| 모드 | 실행 단계 | 사용 시점 |
|------|-----------|-----------|
| `quick` | Build + Types | 빠른 확인 |
| `full` | 전체 6단계 | 일반 검증 |
| `pre-commit` | Build + Types + Lint + Tests | 커밋 전 |
| `pre-pr` | 전체 + 보안 스캔 강화 | PR 제출 전 |

#### 권장 실행 주기

```
개발 세션 중:
├── 15분마다 quick 검증
├── 주요 코드 변경 후 full 검증
├── 함수/컴포넌트 완료 시 pre-commit 검증
└── PR 제출 전 pre-pr 검증
```

#### Hooks와의 차이점

| Hooks | Verification Loop |
|-------|-------------------|
| 즉각적인 에러 탐지 | 심층적인 분석 |
| 개별 도구 사용 후 | 작업 완료 후 |
| 실시간 피드백 | 종합 리포트 |
| 단일 체크 | 6단계 순차 검증 |

---

### 15.4 Claude Orchestra 통합 활용 방안

#### Continuous Learning → Plan-Reviewer 강화

```
세션 종료 시 학습된 패턴을 Plan-Reviewer가 참조
→ 이전에 해결한 문제 패턴을 계획 검증에 활용
```

**구현 예시**:
```
.orchestra/
└── learned-patterns/
    ├── error-resolutions/
    ├── debugging-techniques/
    └── project-specific/
```

#### Strategic Compact → Planner/Executor 전환 시

```
┌─────────────────────────────────────────────────────────────┐
│  [Phase 1: Interview]                                       │
│  Interviewer가 요구사항 수집                                 │
│  컨텍스트: 사용자 대화, 요구사항 분석                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    🗜️ COMPACT
           (인터뷰 컨텍스트 압축, 요구사항 요약 유지)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  [Phase 2: Planning]                                        │
│  Planner가 TODO 생성                                        │
│  컨텍스트: 요구사항 요약, 코드베이스 탐색                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    🗜️ COMPACT
           (탐색 컨텍스트 압축, TODO 계획 유지)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  [Phase 3: Execution]                                       │
│  High/Low Player가 TODO 실행                                │
│  컨텍스트: TODO 계획, 구현 세부사항                          │
└─────────────────────────────────────────────────────────────┘
```

#### Verification Loop → Phase 3 검증 강화

**현재 Claude Orchestra 검증**:
```
TODO 완료 → lint → build → test → 커밋
```

**Verification Loop 통합 후**:
```
TODO 완료
    ↓
┌─────────────────────────────────────────┐
│  6단계 검증 루프                         │
│  1. Build Verification                  │
│  2. Type Check                          │
│  3. Lint Check                          │
│  4. Test Suite (80%+ 커버리지)          │
│  5. Security Scan                       │
│  6. Diff Review                         │
└─────────────────────────────────────────┘
    ↓
PR Ready 평가 → 커밋
```

**state.json 확장 제안**:
```json
{
  "verificationMetrics": {
    "lastRun": "2026-01-25T10:30:00Z",
    "results": {
      "build": "pass",
      "types": "pass",
      "lint": { "errors": 0, "warnings": 3 },
      "tests": { "passed": 47, "failed": 0, "coverage": 84 },
      "security": "pass",
      "diff": { "filesChanged": 5 }
    },
    "prReady": true
  }
}
```

---

## 16. 결론

Everything Claude Code는 10개월 이상의 실전 경험에서 추출된 검증된 설정 컬렉션입니다. 특히 다음 측면에서 강점을 보입니다:

1. **토큰 효율성**: Strategic Compact로 컨텍스트 최적화
2. **품질 보증**: 다층 검증 루프와 TDD 강제
3. **보안**: OWASP 기반 자동화된 보안 리뷰
4. **학습**: Continuous Learning으로 패턴 자동 추출
5. **확장성**: MCP 통합으로 외부 서비스 연동

Claude Orchestra와 함께 사용하면 더욱 강력한 개발 워크플로우를 구축할 수 있습니다.
