#!/usr/bin/env python3
"""Validates the App Store metadata in STORE_LISTING.md against ASC limits.

Parses the `**Field** (max N): `value`` lines and the fenced description
blocks, then checks every field against its App Store Connect maximum. Also
applies the keyword rules ASC does not enforce but that waste the field: no
spaces after commas, no duplicates, and no term already carried by the app name
or subtitle (those are indexed too, so repeating them buys nothing).

Exits non-zero when a hard limit is exceeded, so it can gate a release.

Usage: python3 scripts/validate_store_metadata.py
"""
from __future__ import annotations

import re
import sys

PATH = "STORE_LISTING.md"

# ASC maxima that apply regardless of what the document claims.
LIMITS = {
    "app-name": 30,
    "subtitle": 30,
    "promo": 170,
    "keywords": 100,
    "description": 4000,
    "whats-new": 4000,
}

# Maps the German and English headings to a canonical field key.
FIELD_PATTERNS = [
    (re.compile(r"\*\*(?:App-Name|App Name)\*\*[^:]*:\s*`([^`]*)`"), "app-name"),
    (re.compile(r"\*\*(?:Untertitel|Subtitle)\*\*[^:]*:\s*`([^`]*)`"), "subtitle"),
    (re.compile(r"\*\*(?:Werbetext[^*]*|Promotional Text)\*\*[^:]*:\s*`([^`]*)`"), "promo"),
    (re.compile(r"\*\*Keywords\*\*[^:]*:\s*`([^`]*)`"), "keywords"),
]

# Multi-line fields live in fenced blocks or backticked blocks after the heading.
BLOCK_PATTERNS = [
    (re.compile(r"\*\*(?:Beschreibung|Description)\*\*[^:]*:\s*\n```\n(.*?)\n```", re.S), "description"),
    (re.compile(r"\*\*(?:Was ist neu[^*]*|What's New)\*\*[^:]*:\s*\n`(.*?)`\n", re.S), "whats-new"),
]


def locale_sections(text: str) -> list[tuple[str, str]]:
    """Splits the document into its locale sections."""
    parts = re.split(r"\n## (Deutsch[^\n]*|English[^\n]*)\n", text)
    sections = []
    for index in range(1, len(parts) - 1, 2):
        sections.append((parts[index].strip(), parts[index + 1]))
    return sections


def check_keywords(value: str, name: str, subtitle: str) -> list[str]:
    """Keyword-field rules beyond the raw character limit."""
    problems = []
    if ", " in value:
        problems.append("spaces after commas waste characters — use `a,b,c`")

    terms = [t.strip().lower() for t in value.split(",") if t.strip()]
    duplicates = {t for t in terms if terms.count(t) > 1}
    if duplicates:
        problems.append(f"duplicate keywords: {', '.join(sorted(duplicates))}")

    # Apple indexes the app name and subtitle alongside the keyword field.
    indexed = re.findall(r"\w+", f"{name} {subtitle}".lower())
    redundant = [t for t in terms if t in indexed]
    if redundant:
        problems.append(
            "already covered by name/subtitle: " + ", ".join(redundant)
        )
    return problems


def main() -> int:
    text = open(PATH, encoding="utf-8").read()
    failures = 0

    for locale, body in locale_sections(text):
        print(f"\n== {locale} ==")
        found: dict[str, str] = {}

        for pattern, key in FIELD_PATTERNS:
            match = pattern.search(body)
            if match:
                found[key] = match.group(1)
        for pattern, key in BLOCK_PATTERNS:
            match = pattern.search(body)
            if match:
                found[key] = match.group(1)

        for key, limit in LIMITS.items():
            value = found.get(key)
            if value is None:
                print(f"  {key:12} —      (not found)")
                continue
            length = len(value)
            over = length > limit
            flag = "OVER" if over else "ok"
            if over:
                failures += 1
            print(f"  {key:12} {length:>4}/{limit:<5} {flag}")

        if "keywords" in found:
            for problem in check_keywords(
                found["keywords"], found.get("app-name", ""), found.get("subtitle", "")
            ):
                print(f"    ! keywords: {problem}")

    print()
    if failures:
        print(f"FAILED — {failures} field(s) over the limit")
        return 1
    print("All fields within App Store Connect limits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
