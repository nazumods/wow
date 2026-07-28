#!/usr/bin/env python3
"""Diff each addon's .toc metadata against the header line of its CONTEXT.md.

Three batches of metadata drift have been found by hand, months after the fact
(nazumods/wow#749 and its predecessors). Most of it was mechanically detectable: a
`.toc` field disagreeing with the matching `CONTEXT.md` header field. This is that
check, wired as a PR gate in `.github/workflows/test.yml`.

Rules, all scoped to `<addon>/CONTEXT.md`'s header line (the `**Deps:** ... ` line):

  1. DB VERSION      `X-NUI-DB-VERSION: N` in the .toc must match the `(vN)` in the
                     header's `**SavedVars:**` / `**DB:**` field. A .toc with no such
                     field must pair with a header declaring `none`.
  2. OPTIONALDEPS    `OptionalDeps:` in the .toc must name the same addons as the
                     header's `**OptionalDeps:**` field. Parenthetical notes are
                     ignored, so "Warbandeer_Bars (`bars` view)" compares as
                     "Warbandeer_Bars". A header with no field is only OK when the
                     .toc declares none either.
  3. CURSE ID        A .toc carrying `X-Curse-Project-ID` must NOT still have the
                     "No `X-Curse-Project-ID` yet" bullet in its CONTEXT.md. ONE
                     DIRECTION ONLY: an addon without an id is not required to say
                     so — many simply have no CurseForge project and never mention
                     it, and demanding the note would invent a convention the repo
                     does not have (it fired on 9 addons when written that way).

The check is fully offline (no wago/CDN fetch), so unlike lint-stale-ids.ps1 it needs
no daily drift run — a PR gate alone is enough.

Deliberately tolerant of the legitimate cases, or it would cry wolf:
  * addons with no DB at all (`SavedVars: none`)
  * ShadowsOfUI-Delves genuinely having no CurseForge project
  * ShadowsOfUI-Artisan / -Known correctly declaring `OptionalDeps: Warbandeer`
    because they read `WarbandeerDB` directly

An addon folder is one containing a `<folder>/<folder>.toc` — the same rule
release.sh and the toc-name CI gate use, which is what keeps Tooling/, apps/ and
docs/ out without a hardcoded skip list.

Usage:
    python Tooling/doc_drift.py [--root .]

Exits 1 if any drift is found, 0 otherwise. Output is ASCII only (the Windows
console is cp1252 and raises UnicodeEncodeError on the header line's separators).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# The header line is conventionally line 3, but find it by shape rather than number so
# a blank line or a badge row above it doesn't break the parse.
HEADER_RE = re.compile(r"^\*\*Deps:\*\*")
HEADER_SEARCH_LINES = 8

# `**Field:** value` segments, separated by a middle dot on the header line.
FIELD_SEP = "·"
FIELD_RE = re.compile(r"\*\*([^*]+?):\*\*\s*(.*)")

TOC_FIELD_RE = re.compile(r"^##\s*([^:]+):\s*(.*?)\s*$")

DB_VERSION_RE = re.compile(r"\(v(\d+)")
PARENS_RE = re.compile(r"\([^()]*\)")

CURSE_YET_RE = re.compile(r"No\s+`X-Curse-Project-ID`\s+yet")

DB_HEADER_FIELDS = ("SavedVars", "DB")


def ascii_only(text: str) -> str:
    """Strip non-ASCII so printing to a cp1252 console can't raise."""
    return text.encode("ascii", "replace").decode("ascii")


def parse_toc(path: Path) -> dict[str, str]:
    """`## Field: value` lines from a .toc, keyed by field name."""
    fields: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        match = TOC_FIELD_RE.match(line)
        if match:
            fields[match.group(1).strip()] = match.group(2).strip()
    return fields


def parse_context_header(path: Path) -> dict[str, str] | None:
    """`**Field:** value` segments from the CONTEXT.md header line."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    header = next(
        (ln for ln in lines[:HEADER_SEARCH_LINES] if HEADER_RE.match(ln.strip())), None
    )
    if header is None:
        return None
    fields: dict[str, str] = {}
    for segment in header.split(FIELD_SEP):
        match = FIELD_RE.search(segment.strip())
        if match:
            fields[match.group(1).strip()] = match.group(2).strip()
    return fields


def dep_names(value: str) -> set[str]:
    """Addon names from a dependency list, dropping parenthetical notes and `none`.

    Parentheses are stripped BEFORE splitting on commas, because a note can contain
    one ("Warbandeer_Bars (`bars` view), Warbandeer_Collected (...)").
    """
    stripped = PARENS_RE.sub("", value).replace("`", "")
    names = {part.strip() for part in stripped.split(",")}
    return {n for n in names if n and n.lower() != "none"}


def db_field(header: dict[str, str]) -> tuple[str, str] | None:
    """The header's DB field as (field name, value) — addons use two spellings."""
    for name in DB_HEADER_FIELDS:
        if name in header:
            return name, header[name]
    return None


def check_addon(addon: str, toc: Path, context: Path) -> list[str]:
    """Drift messages for one addon; empty when it is consistent."""
    problems: list[str] = []
    toc_fields = parse_toc(toc)
    header = parse_context_header(context)
    if header is None:
        return [f"{addon}: CONTEXT.md has no '**Deps:**' header line to check against"]

    # 1 - DB version
    toc_version = toc_fields.get("X-NUI-DB-VERSION")
    entry = db_field(header)
    if entry is None:
        if toc_version:
            problems.append(
                f"{addon}: .toc declares X-NUI-DB-VERSION {toc_version} but CONTEXT.md's "
                f"header has no SavedVars/DB field"
            )
    else:
        field_name, value = entry
        match = DB_VERSION_RE.search(value)
        doc_version = match.group(1) if match else None
        declares_none = "none" in value.lower() and doc_version is None
        if toc_version and doc_version != toc_version:
            problems.append(
                f"{addon}: .toc X-NUI-DB-VERSION is {toc_version} but CONTEXT.md "
                f"**{field_name}:** says "
                + (f"v{doc_version}" if doc_version else ascii_only(value or "(nothing)"))
            )
        elif not toc_version and not declares_none and doc_version:
            problems.append(
                f"{addon}: CONTEXT.md **{field_name}:** claims v{doc_version} but the .toc "
                f"has no X-NUI-DB-VERSION"
            )

    # 2 - OptionalDeps
    toc_optional = dep_names(toc_fields.get("OptionalDeps", ""))
    doc_optional = dep_names(header.get("OptionalDeps", ""))
    if toc_optional != doc_optional:
        problems.append(
            f"{addon}: OptionalDeps drift - .toc has "
            f"{sorted(toc_optional) or 'none'}, CONTEXT.md has {sorted(doc_optional) or 'none'}"
        )

    # 3 - CurseForge project id
    has_id = "X-Curse-Project-ID" in toc_fields and toc_fields["X-Curse-Project-ID"]
    says_pending = bool(CURSE_YET_RE.search(context.read_text(encoding="utf-8", errors="replace")))
    if has_id and says_pending:
        problems.append(
            f"{addon}: .toc has X-Curse-Project-ID {toc_fields['X-Curse-Project-ID']} but "
            f"CONTEXT.md still carries the 'No X-Curse-Project-ID yet' note"
        )

    return problems


def addon_dirs(root: Path) -> list[str]:
    """Folders that are addons: those containing <folder>/<folder>.toc."""
    return sorted(
        d.name
        for d in root.iterdir()
        if d.is_dir() and not d.name.startswith(".") and (d / f"{d.name}.toc").is_file()
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repo root (default: cwd)")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    problems: list[str] = []
    checked = 0
    for addon in addon_dirs(root):
        context = root / addon / "CONTEXT.md"
        # No CONTEXT.md is a documentation gap, not metadata DRIFT — there is nothing to
        # disagree with. Flagging it here would make this gate the arbiter of which addons
        # deserve a reference doc, which is a separate call.
        if not context.is_file():
            continue
        checked += 1
        problems.extend(check_addon(addon, root / addon / f"{addon}.toc", context))

    for problem in problems:
        print(f"! {ascii_only(problem)}")
    print(f"= doc_drift: {checked} addons checked, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
