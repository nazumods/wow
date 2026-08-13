#!/usr/bin/env python3
"""unittest coverage for external_drift.py (nazumods/wow#912).

Runs fully offline against tempdir fixtures -- no network, no repo state. Invoke
directly (`python Tooling/test_external_drift.py`) or via `python -m unittest`. Every
rule has a passing AND a failing fixture, so inverting or deleting a check breaks a test.
"""

import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent))
import external_drift as ed  # noqa: E402

# A fully valid EXTERNAL.md: repo URL on the first non-empty line, and a bug/suggestion
# section heading. Every failing fixture below is this minus exactly one invariant.
GOOD_EXTERNAL = (
    "See https://github.com/nazumods/wow for source and issues.\n\n"
    "# Warbandeer\n\nDoes a thing.\n\n"
    "## Found a bug / Have a suggestion?\n\nOpen an issue on GitHub.\n"
)


def _make_addon(
    root: Path, name: str, toc: str = "", external: str | None = None
) -> Path:
    """Create <root>/<name>/<name>.toc (+ EXTERNAL.md) so addon_dirs() sees an addon."""
    d = root / name
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{name}.toc").write_text(toc, encoding="utf-8")
    if external is not None:
        (d / "EXTERNAL.md").write_text(external, encoding="utf-8")
    return d


class CheckExternalTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _external(self, text: str) -> Path:
        path = self.root / "EXTERNAL.md"
        path.write_text(text, encoding="utf-8")
        return path

    def test_clean_passes(self) -> None:
        self.assertEqual(ed.check_external("A", self._external(GOOD_EXTERNAL)), [])

    def test_missing_url_fails(self) -> None:
        text = GOOD_EXTERNAL.replace(
            "https://github.com/nazumods/wow", "https://example.com"
        )
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("first line" in p for p in problems), problems)

    def test_url_not_on_first_line_fails(self) -> None:
        text = "# Title first\n\nhttps://github.com/nazumods/wow\n\n## Found a bug?\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("first line" in p for p in problems), problems)

    def test_missing_bug_section_fails(self) -> None:
        text = "https://github.com/nazumods/wow\n\n# Title\n\nJust prose, no reporting path.\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("bug" in p.lower() for p in problems), problems)

    def test_bold_bug_section_passes(self) -> None:
        text = (
            "https://github.com/nazumods/wow\n\n**Found a bug? Have a suggestion?**\n"
        )
        self.assertEqual(ed.check_external("A", self._external(text)), [])

    def test_empty_file_reports_both(self) -> None:
        problems = ed.check_external("A", self._external(""))
        self.assertEqual(len(problems), 2, problems)


class RelationsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_resolves_sibling_project_id_and_marks_external(self) -> None:
        _make_addon(self.root, "LibNAddOn", "## X-Curse-Project-ID: 111\n")
        _make_addon(
            self.root,
            "MyAddon",
            "## Dependencies: LibNAddOn\n## OptionalDeps: ClassCodex\n## X-Curse-Project-ID: 222\n",
        )
        ids = ed.curse_ids(self.root)
        projects = ed.relations_for("MyAddon", self.root, ids)["projects"]

        required = [p for p in projects if p["type"] == ed.REL_REQUIRED]
        optional = [p for p in projects if p["type"] == ed.REL_OPTIONAL]

        self.assertEqual(len(required), 1)
        self.assertEqual(required[0]["projectID"], "111")
        self.assertNotIn("unresolved", required[0])

        self.assertEqual(len(optional), 1)
        self.assertTrue(
            optional[0].get("unresolved")
        )  # ClassCodex is not a suite CF project
        self.assertEqual(optional[0]["slug"], "classcodex")

    def test_dep_list_drops_none_and_notes_and_dedupes(self) -> None:
        self.assertEqual(ed.dep_list("none"), [])
        self.assertEqual(ed.dep_list(""), [])
        self.assertEqual(
            ed.dep_list("LibNAddOn, Warbandeer_Bars (`bars` view), LibNAddOn"),
            ["LibNAddOn", "Warbandeer_Bars"],
        )


class LintTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_skips_addon_without_external(self) -> None:
        _make_addon(self.root, "NoExt", "## Title: X\n")  # no EXTERNAL.md
        checked, problems = ed.lint(self.root)
        self.assertEqual(checked, 0)
        self.assertEqual(problems, [])

    def test_flags_drifted_external(self) -> None:
        _make_addon(self.root, "Bad", "## Title: X\n", external="nothing useful here\n")
        checked, problems = ed.lint(self.root)
        self.assertEqual(checked, 1)
        self.assertEqual(len(problems), 2)  # missing url + missing bug section

    def test_clean_external_passes(self) -> None:
        _make_addon(self.root, "Good", "## Title: X\n", external=GOOD_EXTERNAL)
        checked, problems = ed.lint(self.root)
        self.assertEqual(checked, 1)
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
