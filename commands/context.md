# /context - 컨텍스트 모드 전환

작업 컨텍스트 모드를 전환합니다.

## 사용법

```
/context [mode]
```

### 모드

| Mode | 설명 | 주요 도구 |
|------|------|-----------|
| `dev` | 개발 모드 (기본) | Edit, Write, Bash |
| `research` | 연구 모드 | Read, Grep, WebSearch |
| `review` | 리뷰 모드 | Read, Grep |

## 모드별 특징

### 🛠️ dev (Development)

**핵심 원칙**:
1. "Write code first, explain after"
2. "Prefer working solutions over perfect solutions"
3. 코드 변경 후 테스트 실행
4. 원자적 커밋 구조 유지

**우선순위**:
1. 기능성 (Functionality)
2. 정확성 (Correctness)
3. 코드 품질 (Code Quality)

**권장 도구**:
- Edit/Write: 코드 수정
- Bash: 테스트/빌드
- Grep/Glob: 코드 탐색

### 🔬 research (Research)

**핵심 원칙**:
1. "Explore before implementing"
2. "Document findings as you go"
3. 여러 접근 방식 비교
4. 트레이드오프 문서화

**우선순위**:
1. 이해도 (Understanding)
2. 완전성 (Completeness)
3. 정확성 (Accuracy)

**권장 도구**:
- Grep/Glob: 코드 탐색
- Read: 파일 읽기
- WebSearch: 외부 문서 검색

### 👀 review (Review)

**핵심 원칙**:
1. "Quality over speed"
2. "Every issue matters"
3. 보안 이슈 최우선
4. 구체적인 개선안 제시

**우선순위**:
1. 보안 (Security)
2. 정확성 (Correctness)
3. 성능 (Performance)

**권장 도구**:
- Read: 코드 읽기
- Grep: 패턴 검색
- Bash: 린트/테스트 실행

## 전환 예시

```bash
# 개발 모드로 전환
/context dev

# 연구 모드로 전환
/context research

# 리뷰 모드로 전환
/context review

# 현재 모드 확인
/context
```

## 결과 출력

```
╔═══════════════════════════════════════════════════════════════╗
║                   CONTEXT MODE                                 ║
╠═══════════════════════════════════════════════════════════════╣
║  Current Mode:  dev                                            ║
║  Changed At:    2026-01-26 12:00:00                           ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                ║
║  Mode Principles:                                             ║
║  ─────────────────                                            ║
║  1. Write code first, explain after                          ║
║  2. Prefer working solutions over perfect solutions          ║
║  3. Run tests after code changes                             ║
║  4. Maintain atomic commit structure                         ║
║                                                                ║
║  Priority: Functionality > Correctness > Code Quality        ║
║                                                                ║
║  Recommended Tools:                                           ║
║  • Edit/Write - Code modification                            ║
║  • Bash - Test/Build                                         ║
║  • Grep/Glob - Code exploration                              ║
║                                                                ║
╚═══════════════════════════════════════════════════════════════╝
```

## 자동 전환

특정 명령어 실행 시 자동 전환:

| 명령어 | 자동 전환 |
|--------|-----------|
| `/start-work` | `dev` |
| `/code-review` | `review` |
| `/learn` | `research` |

## 컨텍스트 파일

각 모드의 상세 설정:

```
.orchestra/contexts/
├── dev.md      # 개발 모드 설정
├── research.md # 연구 모드 설정
└── review.md   # 리뷰 모드 설정
```

## state.json 업데이트

```json
{
  "currentContext": "dev",
  "contextHistory": [
    {
      "mode": "research",
      "changedAt": "2026-01-26T11:00:00Z"
    },
    {
      "mode": "dev",
      "changedAt": "2026-01-26T12:00:00Z"
    }
  ]
}
```

## 관련 명령어

- `/status` - 현재 컨텍스트 확인
- `/start-work` - 작업 세션 시작
