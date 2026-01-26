# /verify - 6단계 검증 루프 실행

코드 품질을 보장하기 위한 6단계 검증을 실행합니다.

## 사용법

```
/verify [mode]
```

### 모드

| Mode | 실행 단계 | 설명 |
|------|-----------|------|
| `quick` | Build + Types | 빠른 확인 (개발 중) |
| `standard` | Build + Types + Lint + Tests | TODO 완료 시 (기본값) |
| `full` | 전체 6단계 | 커밋 전 |
| `pre-pr` | 전체 + 보안 강화 | PR 제출 전 |

## 실행

```bash
# 기본 (standard)
.orchestra/hooks/verification/verification-loop.sh

# 모드 지정
.orchestra/hooks/verification/verification-loop.sh quick
.orchestra/hooks/verification/verification-loop.sh full
.orchestra/hooks/verification/verification-loop.sh pre-pr
```

## 6단계 검증

### Phase 1: Build Verification
- 프로젝트 빌드 성공 확인
- 컴파일 에러 감지
- **실패 시 즉시 중단**

### Phase 2: Type Check
- TypeScript: `tsc --noEmit`
- Python: `mypy`
- Go: `go vet`
- 타입 안전성 검증

### Phase 3: Lint Check
- ESLint / Biome
- Ruff / Flake8 (Python)
- golangci-lint (Go)
- 코드 스타일 검사

### Phase 4: Test Suite + Coverage
- 전체 테스트 실행
- 커버리지 측정
- **80% 미만 시 실패**

### Phase 5: Security Scan
검사 항목:
- 하드코딩된 API 키/시크릿
- OpenAI/Anthropic 키 패턴 (`sk-*`)
- 비밀번호 하드코딩
- `console.log` / `debugger` 문
- 민감한 파일 스테이징
- Private key 파일

### Phase 6: Diff Review
- 변경 파일 목록 확인
- 예상 범위 외 수정 경고
- 대규모 변경 경고

## 결과 예시

```
╔═══════════════════════════════════════════════════════════════╗
║                   VERIFICATION REPORT                          ║
║                   Mode: full | 2026-01-26 10:30:00            ║
╠═══════════════════════════════════════════════════════════════╣
║  Phase 1: Build         ✅ PASS                               ║
║  Phase 2: Type Check    ✅ PASS                               ║
║  Phase 3: Lint          ⚠️ WARN  (0 err, 5 warn)             ║
║  Phase 4: Tests         ✅ PASS  (47/47 passed)              ║
║           Coverage      ✅ 84.5%                              ║
║  Phase 5: Security      ✅ PASS                               ║
║  Phase 6: Diff Review   ✅ PASS  (5 files)                   ║
╠═══════════════════════════════════════════════════════════════╣
║  Total Duration: 16.7s                                        ║
║  PR Ready: ✅ YES                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

## PR Ready 조건

| 조건 | 필수 |
|------|------|
| Build 통과 | ✅ |
| Type Check 통과 | ✅ |
| Lint 에러 없음 | ✅ |
| 테스트 통과 | ✅ |
| 커버리지 80%+ | ✅ |
| 보안 이슈 없음 (critical) | ✅ |

## 자동 실행

Planner가 TODO 완료 시 자동으로 `standard` 모드 실행:

```
TODO 완료 → Verification Loop → PR Ready → Git Commit
```

## 로그 위치

각 Phase의 상세 결과:
```
.orchestra/logs/
├── verification-build.json
├── verification-types.json
├── verification-lint.json
├── verification-tests.json
├── verification-security.json
├── verification-diff.json
└── verification-summary.json
```

## 관련 명령어

- `/status` - 마지막 검증 결과 확인
- `/tdd-cycle` - TDD 사이클 안내
