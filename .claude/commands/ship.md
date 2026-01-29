# /ship - Commit & Push

변경사항을 커밋하고 원격에 푸시합니다.

## 실행 절차

아래 단계를 순서대로 수행하세요:

### 1. 변경사항 확인

```bash
git status
git diff --stat
```

변경된 파일 목록을 사용자에게 보여주세요.

### 2. 커밋 메시지 작성

변경사항을 분석하여 **한글로** 커밋 메시지를 자동 생성합니다:

- **커밋 타입 분류**: feat / fix / refactor / test / docs / chore
- **변경 요약**: 한 줄 제목 (50자 이내, **한글 필수**)
- **상세 본문**: 필요시 what & why 설명 (**한글**)

**커밋 메시지 형식 예시:**
```
fix: 에이전트별 도구 제한을 allowed_tools로 강제

- Planner: Edit/Write 물리적 차단
- Executor: 코드 실행 허용

프롬프트 지시만으로는 무시될 수 있어서 런타임에서 도구 제한을 강제함
```

커밋 메시지 초안을 사용자에게 보여주고 확인을 받으세요.

### 3. Stage & Commit

```bash
git add <변경된 파일들>
git commit -m "<커밋 메시지>"
```

주의사항:
- `.env`, `credentials`, `*.key` 등 민감 파일은 절대 stage하지 마세요
- `.orchestra/logs/` 하위 파일은 제외하세요
- 커밋 메시지는 HEREDOC 형식으로 전달하세요

### 4. Push

```bash
git push
```

- 원격 브랜치가 없으면 `git push -u origin <branch>` 사용
- push 실패 시 원인을 분석하여 안내하세요 (rebase 필요 등)

### 5. 결과 보고

```
Ship complete:
  Branch: <branch>
  Commit: <short-hash> <message>
  Remote: <remote-url>
```

## 규칙

- `--force` push는 사용자가 명시적으로 요청하지 않는 한 금지
- `--no-verify` 사용 금지
- main/master 브랜치에 직접 push 시 경고
- 커밋 전 `git diff --cached`로 최종 확인
