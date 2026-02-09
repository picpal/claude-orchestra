# /status - 현재 상태 확인

Orchestra 시스템의 현재 상태를 표시합니다.

## 실행

상태 파일을 읽고 형식화된 출력을 생성합니다.

```bash
cat .orchestra/state.json
```

## 출력 형식

```
╔═══════════════════════════════════════════════════════════════╗
║                    ORCHESTRA STATUS                            ║
╠═══════════════════════════════════════════════════════════════╣
║  Mode:          {IDLE|PLAN|EXECUTE|REVIEW}                    ║
║  Session:       {session-id}                                   ║
║  Started:       {ISO-8601}                                     ║
╠═══════════════════════════════════════════════════════════════╣
║  CURRENT PLAN                                                  ║
║  ─────────────                                                 ║
║  Name:          {plan-name || "None"}                         ║
║  Path:          {plan-path || "-"}                            ║
║  Progress:      {completed}/{total} TODOs                     ║
╠═══════════════════════════════════════════════════════════════╣
║  TDD METRICS                                                   ║
║  ───────────                                                   ║
║  Tests Written:      {testCount}                              ║
║  RED→GREEN Cycles:   {redGreenCycles}                         ║
║  Deletion Attempts:  {testDeletionAttempts}                   ║
╠═══════════════════════════════════════════════════════════════╣
║  TODO LIST                                                     ║
║  ─────────                                                     ║
║  ✅ [TEST] 로그인 실패 테스트                                  ║
║  ✅ [TEST] 로그인 성공 테스트                                  ║
║  🔄 [IMPL] 로그인 API 구현                    ← Current       ║
║  ⏳ [REFACTOR] 인증 로직 모듈화                               ║
╠═══════════════════════════════════════════════════════════════╣
║  RECENT COMMITS                                                ║
║  ──────────────                                                ║
║  abc1234  [TEST] 로그인 실패 테스트           2min ago        ║
║  def5678  [TEST] 로그인 성공 테스트           5min ago        ║
╚═══════════════════════════════════════════════════════════════╝
```

## 상태별 설명

### Mode

| Mode | 설명 | 색상 |
|------|------|------|
| IDLE | 대기 중, 새 작업 가능 | 🔵 Blue |
| PLAN | 계획 수립 중 | 🟡 Yellow |
| EXECUTE | 작업 실행 중 | 🟢 Green |
| REVIEW | 검토 중 | 🟣 Purple |

### TODO Status

| 아이콘 | 상태 | 설명 |
|--------|------|------|
| ⏳ | pending | 대기 중 |
| 🔄 | in_progress | 진행 중 |
| ✅ | completed | 완료 |
| ❌ | failed | 실패 |
| ⏸️ | blocked | 차단됨 |

## 상세 정보

### 계획 상세
```
/status plan
```

현재 계획의 전체 TODO 목록과 상세 정보 표시

### TDD 상세
```
/status tdd
```

TDD 메트릭 상세:
- 각 테스트 파일별 통계
- RED→GREEN 사이클 히스토리
- 커버리지 현황

### 커밋 히스토리
```
/status commits
```

Orchestra를 통한 커밋 히스토리:
- TODO별 커밋
- TDD Phase
- 변경 파일

## 경고 표시

### TDD 위반 경고
```
⚠️ WARNING: Test deletion attempted 2 times
```

### 커버리지 경고
```
⚠️ WARNING: Coverage below 80% (72.5%)
```

### 오래된 세션 경고
```
⚠️ WARNING: Session active for 4+ hours
Consider /compact for context optimization
```

## Logging Health 진단

시스템 로깅 상태를 확인합니다:

```
╔═══════════════════════════════════════╗
║  LOGGING HEALTH                       ║
║  ✅ Directory: .orchestra/logs        ║
║  ✅ Writable: Yes                     ║
║  ✅ Python3: /usr/bin/python3         ║
║  ⚠️ Recent errors: 2                  ║
║     → /tmp/orchestra-errors-$USER.log ║
╚═══════════════════════════════════════╝
```

### 확인 항목

| 항목 | 확인 방법 | 해결책 |
|------|----------|--------|
| Directory | `.orchestra/logs` 존재 확인 | `/tuning` 실행 |
| Writable | 쓰기 권한 확인 | `chmod -R u+w .orchestra` |
| Python3 | `python3` 명령 확인 | Python 3 설치 |
| Errors | `/tmp/orchestra-errors-$USER.log` | 에러 로그 확인 |

### 진단 명령어

```bash
# 로그 디렉토리 상태
ls -la .orchestra/logs/

# 최근 에러 확인
cat /tmp/orchestra-errors-$USER.log | tail -20

# Python3 경로 확인
which python3
```

## 관련 명령어

- `/start-work` - 새 세션 시작
- `/tdd-cycle` - TDD 사이클 안내
- `/verify` - 검증 루프 실행
