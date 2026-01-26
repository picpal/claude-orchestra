# Handoff Document Template

에이전트 간 작업 인계 시 사용하는 문서 템플릿입니다.

---

## HANDOFF DOCUMENT

### Meta
| Field | Value |
|-------|-------|
| From | `{source-agent}` |
| To | `{target-agent}` |
| Timestamp | `{ISO-8601}` |
| Session | `{session-id}` |
| Plan | `{plan-name}` |
| TODO | `{todo-id}` |

---

## 1. SUMMARY

{이전 에이전트가 수행한 작업 1-2문장 요약}

**Status**: ✅ Completed | 🔄 In Progress | ⚠️ Blocked | ❌ Failed

---

## 2. FINDINGS

### Key Discoveries
- {발견사항 1}
- {발견사항 2}
- {발견사항 3}

### Technical Insights
- {기술적 인사이트 1}
- {기술적 인사이트 2}

---

## 3. CONTEXT FILES

| File | Role | Status |
|------|------|--------|
| `{path/to/file1}` | {역할} | Read/Modified/Created |
| `{path/to/file2}` | {역할} | Read/Modified/Created |
| `{path/to/file3}` | {역할} | Read/Modified/Created |

### File Dependencies
```
{file1}
├── imports {file2}
└── used-by {file3}
```

---

## 4. DECISIONS MADE

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| {결정 1} | {이유} | {대안들} |
| {결정 2} | {이유} | {대안들} |

### Trade-offs
- **Chose**: {선택한 것}
- **Over**: {포기한 것}
- **Because**: {이유}

---

## 5. WORK COMPLETED

### Code Changes
```diff
+ {추가된 내용 요약}
- {삭제된 내용 요약}
~ {수정된 내용 요약}
```

### Tests
| Test | Status |
|------|--------|
| {테스트 1} | ✅ Pass |
| {테스트 2} | ✅ Pass |

### Verification
- Build: ✅ Pass
- Types: ✅ Pass
- Lint: ✅ Pass
- Tests: ✅ Pass

---

## 6. OPEN QUESTIONS

- [ ] {미해결 질문 1}
- [ ] {미해결 질문 2}
- [ ] {미해결 질문 3}

### Clarifications Needed
- {명확화 필요 항목}

---

## 7. BLOCKERS

| Blocker | Impact | Suggested Resolution |
|---------|--------|---------------------|
| {blocker} | High/Medium/Low | {해결 방안} |

---

## 8. RECOMMENDATIONS

### For Next Agent
1. {권장사항 1}
2. {권장사항 2}
3. {권장사항 3}

### Suggested Approach
```
{접근 방식 설명}
```

### Warnings
⚠️ {주의사항}

---

## 9. ARTIFACTS

### Generated Files
- `.orchestra/journal/{session-id}/notes.md`
- `.orchestra/plans/{plan-name}.md`

### Logs
- `.orchestra/logs/{relevant-log}.log`

### References
- {외부 문서 링크}
- {관련 이슈 링크}

---

## 10. NEXT STEPS

| Priority | Task | Assigned To |
|----------|------|-------------|
| 1 | {다음 작업 1} | {agent} |
| 2 | {다음 작업 2} | {agent} |
| 3 | {다음 작업 3} | {agent} |

---

*Generated at: {timestamp}*
*Handoff ID: {handoff-id}*
