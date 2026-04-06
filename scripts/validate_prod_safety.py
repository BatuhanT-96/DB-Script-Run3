#!/usr/bin/env python3
"""Block destructive SQL commands in Prod environment."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import List


@dataclass(frozen=True)
class SafetyRule:
    name: str
    pattern: re.Pattern[str]


def strip_comments_and_literals(sql_text: str) -> str:
    out: List[str] = []
    i = 0
    n = len(sql_text)

    while i < n:
        ch = sql_text[i]
        nxt = sql_text[i + 1] if i + 1 < n else ""

        if ch == "-" and nxt == "-":
            out.append("  ")
            i += 2
            while i < n and sql_text[i] != "\n":
                out.append(" ")
                i += 1
            continue

        if ch == "/" and nxt == "*":
            out.append("  ")
            i += 2
            while i < n - 1:
                if sql_text[i] == "*" and sql_text[i + 1] == "/":
                    out.append("  ")
                    i += 2
                    break
                out.append("\n" if sql_text[i] == "\n" else " ")
                i += 1
            continue

        if ch == "'":
            out.append(" ")
            i += 1
            while i < n:
                curr = sql_text[i]
                out.append("\n" if curr == "\n" else " ")
                if curr == "'":
                    if i + 1 < n and sql_text[i + 1] == "'":
                        out.append(" ")
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def build_rules() -> List[SafetyRule]:
    specs = [
        ("DELETE", r"\bDELETE\b"),
        ("TRUNCATE", r"\bTRUNCATE\b"),
        ("DROP TABLE", r"\bDROP\s+TABLE\b"),
        ("DROP COLUMN", r"\bDROP\s+COLUMN\b"),
        ("DROP INDEX", r"\bDROP\s+INDEX\b"),
        ("ALTER COLUMN", r"\bALTER\s+COLUMN\b"),
        ("ALTER TABLE ... DROP", r"\bALTER\s+TABLE\b[^;\n]*\bDROP\b"),
        ("ALTER TABLE ... RENAME", r"\bALTER\s+TABLE\b[^;\n]*\bRENAME\b"),
        ("RENAME", r"\bRENAME\b"),
        ("DROP (generic)", r"\bDROP\b"),
    ]
    return [SafetyRule(name=n, pattern=re.compile(p, re.IGNORECASE | re.MULTILINE)) for n, p in specs]


def validate(sql_path: pathlib.Path, environment: str) -> int:
    if environment != "Prod":
        print("[INFO] Prod safety validation skipped for non-Prod environment.")
        return 0

    original = sql_path.read_text(encoding="utf-8")
    cleaned = strip_comments_and_literals(original)

    findings: List[str] = []
    for rule in build_rules():
        for match in rule.pattern.finditer(cleaned):
            ln = line_number(cleaned, match.start())
            snippet = match.group(0).strip().replace("\n", " ")
            findings.append(f"line {ln}: blocked pattern '{rule.name}' detected near '{snippet[:80]}'")

    if findings:
        print("[ERROR] Prod safety validation failed. Destructive statements are not allowed in Prod.", file=sys.stderr)
        for finding in findings:
            print(f"  - {finding}", file=sys.stderr)
        return 1

    print("[INFO] Prod safety validation passed.")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate SQL file for destructive commands in Prod.")
    parser.add_argument("--sql-file", required=True, help="SQL file path")
    parser.add_argument("--environment", required=True, choices=["Test", "Prod"], help="Pipeline environment")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sql_path = pathlib.Path(args.sql_file)
    if not sql_path.exists() or not sql_path.is_file():
        print(f"[ERROR] SQL file not found: {sql_path}", file=sys.stderr)
        return 1
    return validate(sql_path, args.environment)


if __name__ == "__main__":
    sys.exit(main())
