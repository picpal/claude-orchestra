# Git Workflow Rules

Git 사용 규칙입니다.

## 브랜치 전략

### 브랜치 명명
```
feature/{ticket}-{description}
bugfix/{ticket}-{description}
hotfix/{ticket}-{description}
refactor/{description}
```

**예시**:
- `feature/AUTH-123-oauth-login`
- `bugfix/API-456-null-pointer`
- `hotfix/PROD-789-memory-leak`

### 보호된 브랜치
- `main` / `master`: 프로덕션 코드
- `develop`: 개발 통합 브랜치

**규칙**:
- 직접 push 금지
- PR 필수
- 리뷰 승인 필수
- CI 통과 필수

## 커밋 규칙

### 커밋 메시지 형식
```
[TYPE] 간결한 설명 (50자 이내)

- 상세 설명 (optional)
- 변경 사항 목록

TODO: {todo-id}
Plan: {plan-name}
```

### TYPE 종류
| Type | 설명 |
|------|------|
| `[TEST]` | 테스트 추가/수정 |
| `[IMPL]` | 기능 구현 |
| `[REFACTOR]` | 리팩토링 |
| `[FIX]` | 버그 수정 |
| `[DOCS]` | 문서 수정 |
| `[STYLE]` | 포맷팅, 세미콜론 등 |
| `[CHORE]` | 빌드, 설정 변경 |

### 좋은 커밋 메시지
```
[IMPL] Add OAuth login with Google

- Implement Google OAuth provider
- Add callback endpoint
- Store tokens securely

TODO: todo-003
Plan: auth-feature
```

### 나쁜 커밋 메시지
```
fix bug
update code
WIP
asdf
```

## 원자적 커밋

### DO
- 하나의 논리적 변경 = 하나의 커밋
- TODO 단위로 커밋
- 빌드/테스트 통과 상태에서만 커밋

### DON'T
- 여러 기능을 하나의 커밋에
- 빌드 실패 상태로 커밋
- "WIP" 커밋을 main에 push

## PR 규칙

### PR 제목
```
[TYPE] {간결한 설명}
```

### PR 본문
```markdown
## Summary
- 변경 사항 요약

## Test Plan
- [ ] 테스트 1
- [ ] 테스트 2

## Screenshots (if UI changes)
```

### PR 체크리스트
- [ ] 코드 리뷰 요청
- [ ] CI 통과
- [ ] 커버리지 유지/향상
- [ ] 문서 업데이트

## 금지 사항

### Force Push
```bash
# ❌ 금지 (특히 main/master)
git push --force
git push -f

# ✅ 허용 (개인 브랜치에서만)
git push --force-with-lease
```

### 민감 정보 커밋
```bash
# ❌ 금지
git add .env
git add credentials.json
git add *.pem

# .gitignore에 추가
.env*
credentials.json
*.pem
*.key
```

### 대규모 바이너리
```bash
# ❌ 금지
git add video.mp4
git add database.sql

# Git LFS 사용
git lfs track "*.mp4"
```

## 유용한 명령어

```bash
# 커밋 전 확인
git status
git diff --staged

# 브랜치 정리
git branch -d feature/old-branch

# 리베이스 (개인 브랜치)
git rebase main

# 커밋 수정 (push 전)
git commit --amend

# 변경사항 임시 저장
git stash
git stash pop
```
