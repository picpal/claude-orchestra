#!/usr/bin/env python3
"""
Sanitize content by redacting sensitive information.
Usage: echo "content" | python3 sanitize-content.py
"""

import sys
import re


def sanitize(content: str) -> str:
    """Remove or mask sensitive information from content."""

    patterns = [
        # OpenAI/Anthropic API 키
        (r"sk-[a-zA-Z0-9]{20,}", "[REDACTED-API-KEY]"),
        # GitHub 토큰
        (r"ghp_[a-zA-Z0-9]{36}", "[REDACTED-GITHUB-TOKEN]"),
        (r"gho_[a-zA-Z0-9]{36}", "[REDACTED-GITHUB-TOKEN]"),
        (r"github_pat_[a-zA-Z0-9_]{22,}", "[REDACTED-GITHUB-TOKEN]"),
        # AWS 키
        (r"AKIA[0-9A-Z]{16}", "[REDACTED-AWS-KEY]"),
        # Bearer 토큰
        (r"Bearer\s+[a-zA-Z0-9._-]+", "Bearer [REDACTED]"),
        # Private Key 블록
        (r"-----BEGIN[^-]*PRIVATE KEY-----[\s\S]*?-----END[^-]*PRIVATE KEY-----", "[REDACTED-PRIVATE-KEY]"),
        # 비밀번호, 시크릿, API 키 (= 또는 : 뒤의 값)
        (r"(password|passwd|pwd|secret|api_key|api-key|auth_token|access_token)\s*[:=]\s*[\"']?[^\"'\s]{4,}", r"\1=[REDACTED]"),
        # 일반적인 시크릿 패턴 (따옴표 안의 긴 base64 문자열)
        (r"[\"'][a-zA-Z0-9+/]{32,}[=]?[\"']", "[REDACTED-SECRET]"),
    ]

    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)

    return content


if __name__ == "__main__":
    content = sys.stdin.read()
    print(sanitize(content), end="")
