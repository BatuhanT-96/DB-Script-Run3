#!/usr/bin/env python3
"""Validate schema-qualified object references for PostgreSQL SQL files."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Iterable, List

OBJ = r'(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)(?:\s*\.\s*(?:"[^"]+"|[A-Za-z_][A-Za-z0-9_$]*))?'


@dataclass(frozen=True)
class Rule:
    name: str
    pattern: re.Pattern[str]
    object_group: str


def strip_comments_and_literals(sql_text: str) -> str:
    """Return text where comments/literals are masked but line positions are preserved."""
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

        if ch == '"':
            # Preserve quoted identifiers for object parsing.
            out.append(ch)
            i += 1
            while i < n:
                curr = sql_text[i]
                out.append(curr)
                if curr == '"':
                    i += 1
                    break
                i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def is_schema_qualified(identifier: str) -> bool:
    token = identifier.strip()
    in_quotes = False
    for ch in token:
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == "." and not in_quotes:
            return True
    return False


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def build_rules() -> Iterable[Rule]:
    specs = [
        ("UPDATE", rf"\bUPDATE\s+(?:ONLY\s+)?(?P<object>{OBJ})"),
        ("INSERT INTO", rf"\bINSERT\s+INTO\s+(?P<object>{OBJ})"),
        ("DELETE FROM", rf"\bDELETE\s+FROM\s+(?:ONLY\s+)?(?P<object>{OBJ})"),
        ("TRUNCATE", rf"\bTRUNCATE(?:\s+TABLE)?\s+(?P<object>{OBJ})"),
        ("ALTER TABLE", rf"\bALTER\s+TABLE\s+(?:ONLY\s+)?(?P<object>{OBJ})"),
        ("DROP TABLE", rf"\bDROP\s+TABLE(?:\s+IF\s+EXISTS)?\s+(?P<object>{OBJ})"),
        ("CREATE TABLE", rf"\bCREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+(?P<object>{OBJ})"),
        ("DROP INDEX", rf"\bDROP\s+INDEX(?:\s+IF\s+EXISTS)?\s+(?P<object>{OBJ})"),
        ("LOCK TABLE", rf"\bLOCK\s+TABLE\s+(?P<object>{OBJ})"),
        ("RENAME TABLE", rf"\bRENAME\s+TABLE\s+(?P<object>{OBJ})"),
    ]
    for name, pattern in specs:
        yield Rule(name=name, pattern=re.compile(pattern, re.IGNORECASE | re.MULTILINE), object_group="object")


def validate(sql_path: pathlib.Path) -> int:
    original = sql_path.read_text(encoding="utf-8")
    cleaned = strip_comments_and_literals(original)

    violations: List[str] = []

    for rule in build_rules():
        for match in rule.pattern.finditer(cleaned):
            obj = match.group(rule.object_group)
            if not is_schema_qualified(obj):
                ln = line_number(cleaned, match.start())
                violations.append(f"line {ln}: {rule.name} uses non-schema-qualified object '{obj.strip()}'")

    create_index_re = re.compile(
        rf"\bCREATE\s+(?:UNIQUE\s+)?INDEX\s+(?P<idx>{OBJ})\s+ON\s+(?P<table>{OBJ})",
        re.IGNORECASE | re.MULTILINE,
    )
    for match in create_index_re.finditer(cleaned):
        idx = match.group("idx")
        table = match.group("table")
        ln = line_number(cleaned, match.start())
        if not is_schema_qualified(idx):
            violations.append(f"line {ln}: CREATE INDEX uses non-schema-qualified index name '{idx.strip()}'")
        if not is_schema_qualified(table):
            violations.append(f"line {ln}: CREATE INDEX references non-schema-qualified table '{table.strip()}'")

    if violations:
        print("[ERROR] Postgre schema validation failed:", file=sys.stderr)
        for issue in violations:
            print(f"  - {issue}", file=sys.stderr)
        return 1

    print("[INFO] Postgre schema validation passed.")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate schema-qualified object references for PostgreSQL scripts.")
    parser.add_argument("--sql-file", required=True, help="Absolute or relative path of SQL file to validate")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sql_path = pathlib.Path(args.sql_file)
    if not sql_path.exists() or not sql_path.is_file():
        print(f"[ERROR] SQL file not found: {sql_path}", file=sys.stderr)
        return 1
    return validate(sql_path)


if __name__ == "__main__":
    sys.exit(main())
