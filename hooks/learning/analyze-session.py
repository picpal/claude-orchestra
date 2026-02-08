#!/usr/bin/env python3
"""
Session Analysis Engine for Claude Orchestra Learning System.
Parses activity logs, detects patterns, and creates/updates pattern files.
Uses only Python3 standard library.
"""

import argparse
import json
import os
import re
import signal
import sys
import tempfile
from collections import Counter
from datetime import datetime, timezone


# === 설정 상수 ===
MAX_LOG_SIZE_MB = 10
TIMEOUT_SECONDS = 30


# === 타임아웃 보호 ===
class TimeoutError(Exception):
    pass


def timeout_handler(signum, frame):
    raise TimeoutError("Analysis exceeded timeout")


# === 로그 크기 체크 ===
def check_log_size(path, max_mb=MAX_LOG_SIZE_MB):
    """Check if log file is within size limit."""
    if not path or not os.path.exists(path):
        return True
    try:
        size_mb = os.path.getsize(path) / (1024 * 1024)
        if size_mb > max_mb:
            sys.stderr.write(f"Log too large ({size_mb:.1f}MB > {max_mb}MB): {path}\n")
            return False
    except OSError:
        pass
    return True


# --- Parsing ---

# 레거시 텍스트 형식용 정규식 (하위 호환성)
ACTIVITY_RE = re.compile(
    r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s+(\S+)\s+\|\s+(\S+)\s+\|\s+([^|]+?)(?:\s+\|\s+(.+))?$"
)

TEST_RE = re.compile(
    r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s+(.*)"
)


def parse_activity_log(path, max_lines=10000):
    """Parse activity.jsonl (or legacy activity.log) into structured entries.

    Supports both:
    - JSONL format: {"ts":"...", "type":"...", "phase":"...", "name":"...", "detail":"..."}
    - Legacy text format: [timestamp] TYPE | PHASE | NAME | DETAIL

    Args:
        path: Path to activity.jsonl or activity.log
        max_lines: Maximum lines to parse (prevents memory issues)
    """
    entries = []
    if not path or not os.path.isfile(path):
        return entries
    if not check_log_size(path):
        return entries
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                line = line.strip()
                if not line:
                    continue

                # JSONL 형식 시도
                try:
                    entry = json.loads(line)
                    # 필수 필드 확인
                    if "ts" in entry and "type" in entry:
                        entries.append({
                            "ts": entry.get("ts", ""),
                            "type": entry.get("type", ""),
                            "phase": entry.get("phase", "-"),
                            "name": entry.get("name", ""),
                            "detail": entry.get("detail", ""),
                        })
                        continue
                except json.JSONDecodeError:
                    pass

                # 레거시 텍스트 형식 fallback
                m = ACTIVITY_RE.match(line)
                if m:
                    entries.append({
                        "ts": m.group(1),
                        "type": m.group(2),
                        "phase": m.group(3),
                        "name": m.group(4).strip(),
                        "detail": (m.group(5) or "").strip(),
                    })
    except IOError as e:
        sys.stderr.write(f"Error reading activity log: {e}\n")
    return entries


def parse_test_log(path, max_lines=5000):
    """Parse test-runs.log into entries."""
    entries = []
    if not path or not os.path.isfile(path):
        return entries
    if not check_log_size(path):
        return entries
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                line = line.rstrip("\n")
                m = TEST_RE.match(line)
                if m:
                    entries.append({
                        "ts": m.group(1),
                        "message": m.group(2).strip(),
                    })
    except IOError as e:
        sys.stderr.write(f"Error reading test log: {e}\n")
    return entries


def parse_tdd_guard_log(path):
    """Parse tdd-guard.log into entries (same format as test log)."""
    return parse_test_log(path)


def parse_changes_log(path, max_entries=1000):
    """Parse changes.jsonl into entries.

    Each entry contains:
    - timestamp: ISO timestamp
    - tool: "Edit" or "Write"
    - file: file path
    - language: inferred language
    - old_string/new_string (Edit) or content_sample (Write)
    """
    entries = []
    if not path or not os.path.isfile(path):
        return entries
    if not check_log_size(path):
        return entries
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= max_entries:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    entries.append(entry)
                except json.JSONDecodeError:
                    continue
    except IOError as e:
        sys.stderr.write(f"Error reading changes log: {e}\n")
    return entries


def get_changes_for_file(changes, file_path):
    """Get all changes for a specific file."""
    return [c for c in changes if c.get("file") == file_path]


def get_changes_by_pattern(changes, pattern_re):
    """Get changes where old_string or new_string matches pattern."""
    matched = []
    for c in changes:
        old = c.get("old_string", "")
        new = c.get("new_string", "")
        if pattern_re.search(old) or pattern_re.search(new):
            matched.append(c)
    return matched


def format_code_example(changes, max_examples=2):
    """Format changes into Before/After code example.

    Returns formatted markdown string with code blocks.
    """
    if not changes:
        return ""

    examples = []
    for change in changes[:max_examples]:
        file_path = change.get("file", "unknown")
        language = change.get("language", "text")

        if change.get("tool") == "Edit":
            old = change.get("old_string", "").strip()
            new = change.get("new_string", "").strip()
            if old and new:
                example = f"### File: `{file_path}`\n\n"
                example += f"**Before:**\n```{language}\n{old}\n```\n\n"
                example += f"**After:**\n```{language}\n{new}\n```"
                examples.append(example)
        elif change.get("tool") == "Write":
            content = change.get("content_sample", "").strip()
            if content:
                example = f"### File: `{file_path}` (created)\n\n"
                example += f"```{language}\n{content}\n```"
                examples.append(example)

    return "\n\n".join(examples)


# --- Config & Existing Patterns ---

def load_triggers(config_path):
    """Load trigger patterns from config.json and compile regexes."""
    triggers = {}
    if not config_path or not os.path.isfile(config_path):
        return triggers
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
        raw = config.get("triggers", {})
        for key, val in raw.items():
            if val.get("enabled", True) and val.get("pattern"):
                try:
                    triggers[key] = re.compile(val["pattern"], re.IGNORECASE)
                except re.error:
                    pass
    except (json.JSONDecodeError, IOError):
        pass
    return triggers


def load_existing_patterns(patterns_dir):
    """Load existing pattern files and extract keywords sets.
    Returns list of {"path": str, "keywords": set}.
    """
    patterns = []
    if not patterns_dir or not os.path.isdir(patterns_dir):
        return patterns
    try:
        for fname in os.listdir(patterns_dir):
            if not fname.endswith(".md"):
                continue
            fpath = os.path.join(patterns_dir, fname)
            keywords = set()
            try:
                with open(fpath, "r", encoding="utf-8") as f:
                    in_keywords = False
                    for line in f:
                        line = line.strip()
                        if line == "## Trigger Keywords":
                            in_keywords = True
                            continue
                        if in_keywords:
                            if line.startswith("##"):
                                break
                            if line:
                                keywords = {k.strip().lower() for k in line.split(",") if k.strip()}
                            break
            except IOError:
                continue
            patterns.append({"path": fpath, "keywords": keywords})
    except OSError:
        pass
    return patterns


def find_duplicate(keywords, existing_patterns):
    """Return path of existing pattern if Jaccard similarity >= 0.5, else None."""
    if not keywords:
        return None
    kw_set = {k.lower() for k in keywords}
    for pat in existing_patterns:
        if not pat["keywords"]:
            continue
        intersection = kw_set & pat["keywords"]
        union = kw_set | pat["keywords"]
        if union and len(intersection) / len(union) >= 0.5:
            return pat["path"]
    return None


# --- Pattern Detection ---

ERROR_CODE_RE = re.compile(r"(TS\d{4}|[A-Z]\w*Error)")
FILE_PATH_RE = re.compile(r"(?:^|[\s\"'])([./\w-]+\.[a-zA-Z]{1,5})(?:[\s\"':,]|$)")


def detect_errors(entries, test_entries, triggers, changes=None):
    """Detect recurring error codes from activity log and test log.

    Args:
        entries: Activity log entries
        test_entries: Test log entries
        triggers: Compiled trigger patterns
        changes: Parsed changes.jsonl entries (optional)
    """
    patterns = []
    changes = changes or []
    error_trigger = triggers.get("errorResolved")

    error_lines = []
    for e in entries:
        text = f"{e['name']} {e['detail']}"
        if error_trigger and error_trigger.search(text):
            error_lines.append(text)
    for te in test_entries:
        if error_trigger and error_trigger.search(te["message"]):
            error_lines.append(te["message"])

    # Count error codes
    code_counter = Counter()
    code_context = {}
    for line in error_lines:
        codes = ERROR_CODE_RE.findall(line)
        for code in codes:
            code_counter[code] += 1
            if code not in code_context:
                code_context[code] = line

    # Patterns for codes appearing 2+ times
    for code, count in code_counter.items():
        if count >= 2:
            # Find related changes containing the error code
            code_re = re.compile(re.escape(code), re.IGNORECASE)
            related_changes = get_changes_by_pattern(changes, code_re)
            code_example = format_code_example(related_changes)

            # Generate more specific solution if we have code examples
            solution = f"Recurring error detected from logs. Review context: {code_context.get(code, '')}"
            if related_changes:
                files = list(set(c.get("file", "") for c in related_changes[:3]))
                solution = f"Error '{code}' was resolved by modifying: {', '.join(files)}. See code examples below."

            patterns.append({
                "category": "error_resolution",
                "title": f"{code} Error Pattern",
                "problem": f"'{code}' error occurred {count} times during session",
                "solution": solution,
                "code_example": code_example,
                "keywords": [code, "error", "resolution"],
            })

    return patterns


def detect_repeated_edits(entries, changes=None):
    """Detect files edited 3+ times in EXECUTE phase → user_corrections pattern.

    Args:
        entries: Activity log entries
        changes: Parsed changes.jsonl entries (optional)
    """
    patterns = []
    changes = changes or []
    file_counter = Counter()

    # Count from activity log
    for e in entries:
        if e["type"] == "AGENT" and e["phase"] == "EXECUTE" and "[done]" in e.get("detail", ""):
            paths = FILE_PATH_RE.findall(e["detail"])
            for p in paths:
                if "/" in p or p.count(".") <= 1:
                    file_counter[p] += 1

    # Also count from changes.jsonl for more accuracy
    for c in changes:
        file_path = c.get("file", "")
        if file_path:
            file_counter[file_path] += 1

    repeated = [(f, c) for f, c in file_counter.items() if c >= 3]
    if repeated:
        file_list = ", ".join(f"{f} ({c}x)" for f, c in repeated[:5])

        # Get code examples from changes for the most repeated files
        all_related_changes = []
        for file_path, _ in repeated[:2]:
            file_changes = get_changes_for_file(changes, file_path)
            all_related_changes.extend(file_changes[-2:])  # Last 2 changes per file

        code_example = format_code_example(all_related_changes)

        # Generate specific solution based on changes
        solution = "These files required repeated modifications. Consider reviewing the approach for these areas."
        if all_related_changes:
            solution = "Multiple iterations were needed. Review the final changes to understand the solution pattern."

        patterns.append({
            "category": "user_corrections",
            "title": "Repeated File Edits",
            "problem": f"Files edited multiple times in execution phase: {file_list}",
            "solution": solution,
            "code_example": code_example,
            "keywords": ["repeated edit", "correction"] + [f.split("/")[-1] for f, _ in repeated[:3]],
        })

    return patterns


def detect_workarounds(entries, triggers):
    """Detect workaround patterns using trigger regex."""
    patterns = []
    workaround_trigger = triggers.get("workaround")
    if not workaround_trigger:
        return patterns

    workaround_lines = []
    for e in entries:
        text = f"{e['name']} {e['detail']}"
        if workaround_trigger.search(text):
            workaround_lines.append(text)

    if len(workaround_lines) >= 2:
        sample = workaround_lines[0][:200]
        patterns.append({
            "category": "workarounds",
            "title": "Workaround Pattern Detected",
            "problem": f"Workaround applied {len(workaround_lines)} times. Sample: {sample}",
            "solution": "Consider finding a proper solution to replace the workaround.",
            "code_example": "",
            "keywords": ["workaround", "temporary", "alternative"],
        })

    return patterns


def detect_tdd_issues(test_entries, tdd_guard_entries):
    """Detect TDD issues: consecutive test failures, TDD guard violations."""
    patterns = []

    # Consecutive test failures
    fail_re = re.compile(r"FAIL|failed|failure", re.IGNORECASE)
    consecutive_fails = 0
    max_consecutive = 0
    for te in test_entries:
        if fail_re.search(te["message"]):
            consecutive_fails += 1
            max_consecutive = max(max_consecutive, consecutive_fails)
        else:
            consecutive_fails = 0

    if max_consecutive >= 3:
        patterns.append({
            "category": "debugging_techniques",
            "title": "Consecutive Test Failures",
            "problem": f"Tests failed {max_consecutive} times consecutively during session",
            "solution": "Consider breaking down the problem into smaller steps when tests fail repeatedly.",
            "code_example": "",
            "keywords": ["test failure", "consecutive", "debugging"],
        })

    # TDD guard violations
    violation_re = re.compile(r"violation|blocked|rejected", re.IGNORECASE)
    violations = [e for e in tdd_guard_entries if violation_re.search(e["message"])]
    if len(violations) >= 2:
        patterns.append({
            "category": "best_practices",
            "title": "TDD Guard Violations",
            "problem": f"TDD guard triggered {len(violations)} times — code was modified without tests",
            "solution": "Always write tests before implementation (RED → GREEN → REFACTOR).",
            "code_example": "",
            "keywords": ["tdd", "violation", "test first", "best practice"],
        })

    return patterns


# --- Pattern File I/O ---

def generate_pattern_id(category):
    """Generate unique pattern ID."""
    ts = datetime.now().strftime("%Y%m%d%H%M%S")
    random_hex = os.urandom(4).hex()
    return f"{category}-{ts}-{random_hex}"


def create_pattern_file(patterns_dir, category, title, problem, solution, code_example, keywords):
    """Create a new pattern markdown file atomically. Returns the file path.

    Args:
        patterns_dir: Directory to store pattern files
        category: Pattern category (e.g., error_resolution, user_corrections)
        title: Pattern title
        problem: Description of the problem
        solution: How the problem was solved
        code_example: Formatted code example (may include Before/After sections)
        keywords: List of trigger keywords
    """
    pattern_id = generate_pattern_id(category)
    fpath = os.path.join(patterns_dir, f"{pattern_id}.md")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    kw_str = ", ".join(keywords) if keywords else ""

    # Handle code example formatting
    # If code_example already contains markdown (### headers), use it directly
    # Otherwise wrap in a simple code block
    if code_example and code_example.strip():
        if "```" in code_example or code_example.startswith("###"):
            code_section = code_example
        else:
            code_section = f"```\n{code_example}\n```"
    else:
        code_section = "_No code example captured for this session._"

    content = f"""# Pattern: {title}

## ID
{pattern_id}

## Category
{category}

## Created
{now}

## Problem
{problem}

## Solution
{solution}

## Code Example
{code_section}

## Trigger Keywords
{kw_str}

## Usage Count
1

## Last Used
{now}
"""
    os.makedirs(patterns_dir, exist_ok=True)

    # 원자적 쓰기 (임시 파일 → 이동)
    try:
        fd, tmp_path = tempfile.mkstemp(dir=patterns_dir, suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(content)
            os.rename(tmp_path, fpath)
        except Exception:
            os.unlink(tmp_path)
            raise
    except Exception as e:
        # Fallback: 직접 쓰기
        sys.stderr.write(f"Atomic write failed, using direct write: {e}\n")
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(content)

    return fpath


def update_pattern_file(path):
    """Increment Usage Count and update Last Used in an existing pattern file atomically."""
    if not os.path.isfile(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        # Update Usage Count
        usage_match = re.search(r"(## Usage Count\n)(\d+)", content)
        if usage_match:
            old_count = int(usage_match.group(2))
            content = content[:usage_match.start(2)] + str(old_count + 1) + content[usage_match.end(2):]

        # Update Last Used
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        content = re.sub(r"(## Last Used\n).*", rf"\g<1>{now}", content)

        # 원자적 쓰기
        dir_path = os.path.dirname(path)
        fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(content)
            os.rename(tmp_path, path)
        except Exception:
            os.unlink(tmp_path)
            raise
    except Exception as e:
        sys.stderr.write(f"Error updating pattern file: {e}\n")


# --- Main ---

def main():
    parser = argparse.ArgumentParser(description="Analyze session logs for learning patterns")
    parser.add_argument("--activity", default=".orchestra/logs/activity.jsonl", help="Path to activity.jsonl (or legacy activity.log)")
    parser.add_argument("--tests", default=".orchestra/logs/test-runs.log", help="Path to test-runs.log")
    parser.add_argument("--tdd-guard", default=".orchestra/logs/tdd-guard.log", help="Path to tdd-guard.log")
    parser.add_argument("--changes", default=".orchestra/logs/changes.jsonl", help="Path to changes.jsonl")
    parser.add_argument("--config", default="hooks/learning/config.json", help="Path to config.json")
    parser.add_argument("--patterns-dir", default="hooks/learning/learned-patterns", help="Path to patterns directory")
    parser.add_argument("--max-patterns", type=int, default=5, help="Max patterns per session")
    args = parser.parse_args()

    # 타임아웃 설정 (SIGALRM - Unix only)
    if hasattr(signal, 'SIGALRM'):
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(TIMEOUT_SECONDS)

    try:
        # 모든 로그가 없으면 조기 종료
        if not any([
            os.path.isfile(args.activity),
            os.path.isfile(args.tests),
            os.path.isfile(args.tdd_guard),
            os.path.isfile(args.changes)
        ]):
            print(0)
            return

        # Parse logs
        entries = parse_activity_log(args.activity)
        test_entries = parse_test_log(args.tests)
        tdd_guard_entries = parse_tdd_guard_log(args.tdd_guard)
        changes = parse_changes_log(args.changes)

        if not entries and not test_entries and not tdd_guard_entries and not changes:
            print(0)
            return

        # Load config triggers and existing patterns
        triggers = load_triggers(args.config)
        existing = load_existing_patterns(args.patterns_dir)

        # Detect patterns (pass changes for code example extraction)
        candidates = []
        candidates.extend(detect_errors(entries, test_entries, triggers, changes))
        candidates.extend(detect_repeated_edits(entries, changes))
        candidates.extend(detect_workarounds(entries, triggers))
        candidates.extend(detect_tdd_issues(test_entries, tdd_guard_entries))

        # Deduplicate & create/update
        created_count = 0
        updated_count = 0

        for candidate in candidates:
            if created_count + updated_count >= args.max_patterns:
                break

            kw = candidate.get("keywords", [])
            dup_path = find_duplicate(kw, existing)

            if dup_path:
                update_pattern_file(dup_path)
                updated_count += 1
            else:
                fpath = create_pattern_file(
                    args.patterns_dir,
                    candidate["category"],
                    candidate["title"],
                    candidate["problem"],
                    candidate["solution"],
                    candidate.get("code_example", ""),
                    kw,
                )
                # Add to existing so subsequent candidates can dedup against it
                existing.append({"path": fpath, "keywords": {k.lower() for k in kw}})
                created_count += 1

        total = created_count + updated_count
        print(total)

    except TimeoutError:
        sys.stderr.write(f"Analysis timed out after {TIMEOUT_SECONDS} seconds\n")
        print(0)
    finally:
        # 타임아웃 해제
        if hasattr(signal, 'SIGALRM'):
            signal.alarm(0)


if __name__ == "__main__":
    main()
