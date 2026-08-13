#!/usr/bin/env python3
"""Check each addon's EXTERNAL.md against #911's invariants and emit CF relations (#912).

Background (nazumods/wow#912, a SPIKE): can CI detect drift between an addon's
EXTERNAL.md -- the CurseForge/Wago.io page copy proposed in #911 -- and the live
external project, and ideally update the external resource too? The research answer:

  * DESCRIPTION: no public API can write it back. CurseForge has no author endpoint
    for the description/summary (idea CF-I-6366 is "Future consideration"), and Wago's
    documented API is upload-only. So a page cannot be auto-updated; the most CI can do
    is DETECT that the source moved and prompt a human to paste it into the dashboard.
  * DEPENDENCIES: the one writable surface, CurseForge-only. Its Upload API takes a
    `relations` block at file-upload time. `--emit-relations` renders exactly that block
    from the .toc, so a future publish.yml step could POST it. Wago exposes no relations
    API at all.

This module is the offline half of that finding: no API key, no network, so it runs as
a PR gate in .github/workflows/test.yml the same way doc_drift.py does. It stays inert
until #911 lands EXTERNAL.md files -- an addon without one is skipped, not failed,
because missing page copy is a content gap, not drift.

Checks per EXTERNAL.md (#911's two stated, offline-verifiable invariants):

  1. GITHUB URL   The first non-empty line references the repo (github.com/nazumods/wow),
                  so the external page always links home.
  2. BUG SECTION  A "Found a bug / Have a suggestion?" heading exists, so a reader always
                  has a reporting path.

An addon folder is one containing <folder>/<folder>.toc -- the same rule release.sh,
the toc-name gate and doc_drift.py use, which keeps Tooling/, apps/ and .github/ out
without a hardcoded skip list.

Usage:
    python Tooling/external_drift.py [--root .]              # lint (CI gate); exit 1 on drift
    python Tooling/external_drift.py --emit-relations [ADDON]  # print CF relations JSON, exit 0

Output is ASCII only (the Windows console is cp1252 and raises UnicodeEncodeError on
non-ASCII).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = "nazumods/wow"
REPO_URL_RE = re.compile(r"github\.com/nazumods/wow", re.IGNORECASE)

# A "Found a bug / Have a suggestion?" section (#911). Accept a markdown heading or a
# bold lead-in so the copy can be styled either way; key on the spec's own keywords.
BUG_SECTION_RE = re.compile(
    r"^\s{0,3}(#{1,6}\s|\*\*).*\b(bug|suggestion)s?\b", re.IGNORECASE | re.MULTILINE
)

TOC_FIELD_RE = re.compile(r"^##\s*([^:]+):\s*(.*?)\s*$")
PARENS_RE = re.compile(r"\([^()]*\)")

REL_REQUIRED = "requiredDependency"
REL_OPTIONAL = "optionalDependency"


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


def addon_dirs(root: Path) -> list[str]:
    """Folders that are addons: those containing <folder>/<folder>.toc."""
    return sorted(
        d.name
        for d in root.iterdir()
        if d.is_dir() and not d.name.startswith(".") and (d / f"{d.name}.toc").is_file()
    )


def first_nonempty_line(text: str) -> str:
    for line in text.splitlines():
        if line.strip():
            return line.strip()
    return ""


def dep_list(value: str) -> list[str]:
    """Ordered addon names from a .toc dependency field, dropping parenthetical notes
    and the literal `none`; .toc order is preserved and duplicates collapsed."""
    stripped = PARENS_RE.sub("", value).replace("`", "")
    names: list[str] = []
    for part in stripped.split(","):
        name = part.strip()
        if name and name.lower() != "none" and name not in names:
            names.append(name)
    return names


def check_external(addon: str, path: Path) -> list[str]:
    """Problems for one EXTERNAL.md; empty when it satisfies #911's invariants."""
    problems: list[str] = []
    text = path.read_text(encoding="utf-8-sig", errors="replace")

    first = first_nonempty_line(text)
    if not REPO_URL_RE.search(first):
        shown = ascii_only(first[:60]) if first else "(empty file)"
        problems.append(
            f"{addon}: EXTERNAL.md first line must reference github.com/{REPO} (got: {shown})"
        )

    if not BUG_SECTION_RE.search(text):
        problems.append(
            f"{addon}: EXTERNAL.md needs a 'Found a bug / Have a suggestion?' section"
        )

    return problems


def curse_ids(root: Path) -> dict[str, str]:
    """folder name -> X-Curse-Project-ID for suite addons that carry one."""
    ids: dict[str, str] = {}
    for addon in addon_dirs(root):
        pid = parse_toc(root / addon / f"{addon}.toc").get("X-Curse-Project-ID")
        if pid:
            ids[addon] = pid
    return ids


def relations_for(addon: str, root: Path, ids: dict[str, str]) -> dict:
    """The CurseForge Upload API `relations` block derived from an addon's .toc.

    Dependencies -> requiredDependency, OptionalDeps -> optionalDependency. A dep that is
    itself a suite CurseForge project gets its authoritative projectID; one that is not
    (an external addon, or none published) is marked `unresolved`, and its slug is only a
    lowercased guess a human must confirm -- a folder name is not necessarily a CF slug.
    """
    fields = parse_toc(root / addon / f"{addon}.toc")
    projects: list[dict] = []
    for field, rel_type in (
        ("Dependencies", REL_REQUIRED),
        ("OptionalDeps", REL_OPTIONAL),
    ):
        for name in dep_list(fields.get(field, "")):
            entry: dict = {"slug": name.lower().replace("_", "-"), "type": rel_type}
            if name in ids:
                entry["projectID"] = ids[name]
            else:
                entry["unresolved"] = True
            projects.append(entry)
    return {"projects": projects}


def lint(root: Path) -> tuple[int, list[str]]:
    """(addons checked, drift messages) over every EXTERNAL.md under root."""
    problems: list[str] = []
    checked = 0
    for addon in addon_dirs(root):
        external = root / addon / "EXTERNAL.md"
        # No EXTERNAL.md is a content gap (#911 hasn't reached this addon), not DRIFT --
        # there is nothing to check against. Skip it, the way doc_drift skips a missing
        # CONTEXT.md, so this gate never becomes the arbiter of which addons need copy.
        if not external.is_file():
            continue
        checked += 1
        problems.extend(check_external(addon, external))
    return checked, problems


def emit_relations(root: Path, only: str | None) -> int:
    """Print the CF relations JSON for ADDON, or for every published addon. Read-only."""
    ids = curse_ids(root)
    targets = [only] if only else sorted(ids)
    payload: dict[str, dict] = {}
    for addon in targets:
        if not (root / addon / f"{addon}.toc").is_file():
            print(f"! {addon}: no {addon}/{addon}.toc", file=sys.stderr)
            return 1
        payload[addon] = relations_for(addon, root, ids)
    print(json.dumps(payload, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repo root (default: cwd)")
    parser.add_argument(
        "--emit-relations",
        nargs="?",
        const="",
        metavar="ADDON",
        help="print the CurseForge relations JSON derived from the .toc (all published "
        "addons, or just ADDON) and exit; makes no network call and changes nothing",
    )
    args = parser.parse_args()
    root = Path(args.root).resolve()

    if args.emit_relations is not None:
        return emit_relations(root, args.emit_relations or None)

    checked, problems = lint(root)
    for problem in problems:
        print(f"! {ascii_only(problem)}")
    print(
        f"= external_drift: {checked} EXTERNAL.md checked, {len(problems)} problem(s)"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
