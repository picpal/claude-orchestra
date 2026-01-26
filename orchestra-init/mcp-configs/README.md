# MCP Configurations

Model Context Protocol (MCP) 서버 설정입니다.

## 개요

MCP는 Claude Code가 외부 서비스와 통합하여 실시간 정보를 제공받을 수 있게 합니다.

## 설정된 MCP 서버

### Context7

최신 라이브러리 문서를 실시간으로 조회합니다.

**설정 파일**: `context7.json`

**환경 변수**:
```bash
export CONTEXT7_API_KEY="your-api-key"
```

**사용 예시**:
- "React 19 새로운 훅 문서 조회"
- "Next.js 15 App Router 변경사항"
- "TypeScript 5.x 새 기능"

## 활성화 방법

### 1. 환경 변수 설정
```bash
# .bashrc 또는 .zshrc에 추가
export CONTEXT7_API_KEY="your-api-key"
```

### 2. Claude Code 설정에 추가
```json
// settings.json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@anthropic/context7-mcp"],
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    }
  }
}
```

## 사용 시 주의사항

### 컨텍스트 윈도우
- MCP 서버가 많이 활성화되면 사용 가능한 컨텍스트 윈도우가 줄어들 수 있습니다
- 기본 200k → MCP 과다 시 약 70k

### 권장 사용 패턴
1. 필요한 MCP만 활성화
2. 사용 후 비활성화 고려
3. 대용량 응답 주의

## Searcher 에이전트 연동

Searcher 에이전트는 Context7 MCP를 통해:
1. 최신 라이브러리 문서 실시간 조회
2. API 변경사항 확인
3. 베스트 프랙티스 검색
4. 코드 예제 수집

## 추가 MCP 서버

다른 MCP 서버를 추가하려면:

1. 새 JSON 파일 생성
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/mcp-server"],
      "env": {}
    }
  }
}
```

2. settings.json에 병합

## 문제 해결

### MCP 연결 실패
```bash
# 패키지 설치 확인
npx -y @anthropic/context7-mcp --version

# 환경 변수 확인
echo $CONTEXT7_API_KEY
```

### 응답 없음
- API 키 유효성 확인
- 네트워크 연결 확인
- 서버 상태 확인

## 참고 자료

- [MCP 공식 문서](https://docs.anthropic.com/mcp)
- [Context7 문서](https://context7.io/docs)
