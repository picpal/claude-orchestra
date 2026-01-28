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
import sys
from collections import Counter
from datetime import datetime, timezone


# --- Parsing ---

ACTIVITY_RE = re.compile(
    r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s+(\S+)\s+\|\s+(\S+)\s+\|\s+([^|]+?)(?:\s+\|\s+(.+))?$"
)

TEST_RE = re.compile(
    r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s+(.*)"
)


def parse_activity_log(path):
    """Parse activity.log lines into structured entries."""
    entries = []
    if not path or not os.path.isfile(path):
        return entries
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = ACTIVITY_RE.match(line)
            if m:
                entries.append({
                    "ts": m.group(1),
                    "type": m.group(2),
                    "phase": m.group(3),
                    "name": m.group(4).strip(),
                    "detail": (m.group(5) or "").strip(),
                })
    return entries


def parse_test_log(path):
    """Parse test-runs.log into entries."""
    entries = []
    if not path or not os.path.isfile(path):
        return entries
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = TEST_RE.match(line)
            if m:
                entries.append({
                    "ts": m.group(1),
                    "message": m.group(2).strip(),
                })
    return entries


def parse_tdd_guard_log(path):
    """Parse tdd-guard.log into entries (same format as test log)."""
    return parse_test_log(path)


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


def detect_errors(entries, test_entries, triggers):
    """Detect recurring error codes from activity log and test log."""
    patterns = []
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
            patterns.append({
                "category": "error_resolution",
                "title": f"{code} Error Pattern",
                "problem": f"'{code}' error occurred {count} times during session",
                "solution": f"Recurring error detected from logs. Review context: {code_context.get(code, '')}",
                "code_example": "",
                "keywords": [code, "error", "resolution"],
            })

    return patterns


def detect_repeated_edits(entries):
    """Detect files edited 3+ times in EXECUTE phase → user_corrections pattern."""
    patterns = []
    file_counter = Counter()

    for e in entries:
        if e["type"] == "AGENT" and e["phase"] == "EXECUTE" and "[done]" in e.get("detail", ""):
            # Extract file paths from detail
            paths = FILE_PATH_RE.findall(e["detail"])
            for p in paths:
                if "/" in p or p.count(".") <= 1:
                    file_counter[p] += 1

    repeated = [(f, c) for f, c in file_counter.items() if c >= 3]
    if repeated:
        file_list = ", ".join(f"{f} ({c}x)" for f, c in repeated[:5])
        patterns.append({
            "category": "user_corrections",
            "title": "Repeated File Edits",
            "problem": f"Files edited multiple times in execution phase: {file_list}",
            "solution": "These files required repeated modifications. Consider reviewing the approach for these areas.",
            "code_example": "",
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
    """Create a new pattern markdown file. Returns the file path."""
    pattern_id = generate_pattern_id(category)
    fpath = os.path.join(patterns_dir, f"{pattern_id}.md")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    kw_str = ", ".join(keywords) if keywords else ""

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
```
{code_example}
```

## Trigger Keywords
{kw_str}

## Usage Count
1

## Last Used
{now}
"""
    os.makedirs(patterns_dir, exist_ok=True)
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(content)
    return fpath


def update_pattern_file(path):
    """Increment Usage Count and update Last Used in an existing pattern file."""
    if not os.path.isfile(path):
        return
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

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


# --- Main ---

def main():
    parser = argparse.ArgumentParser(description="Analyze session logs for learning patterns")
    parser.add_argument("--activity", default=".orchestra/logs/activity.log", help="Path to activity.log")
    parser.add_argument("--tests", default=".orchestra/logs/test-runs.log", help="Path to test-runs.log")
    parser.add_argument("--tdd-guard", default=".orchestra/logs/tdd-guard.log", help="Path to tdd-guard.log")
    parser.add_argument("--config", default="hooks/learning/config.json", help="Path to config.json")
    parser.add_argument("--patterns-dir", default="hooks/learning/learned-patterns", help="Path to patterns directory")
    parser.add_argument("--max-patterns", type=int, default=5, help="Max patterns per session")
    args = parser.parse_args()

    # Parse logs
    entries = parse_activity_log(args.activity)
    test_entries = parse_test_log(args.tests)
    tdd_guard_entries = parse_tdd_guard_log(args.tdd_guard)

    if not entries and not test_entries and not tdd_guard_entries:
        print(0)
        return

    # Load config triggers and existing patterns
    triggers = load_triggers(args.config)
    existing = load_existing_patterns(args.patterns_dir)

    # Detect patterns
    candidates = []
    candidates.extend(detect_errors(entries, test_entries, triggers))
    candidates.extend(detect_repeated_edits(entries))
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


if __name__ == "__main__":
    main()
