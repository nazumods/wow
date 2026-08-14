#!/usr/bin/env python3
"""unittest coverage for external_drift.py (nazumods/wow#912).

Runs fully offline against tempdir fixtures -- no network, no repo state. Invoke
directly (`python Tooling/test_external_drift.py`) or via `python -m unittest`. Every
rule has a passing AND a failing fixture, and main()/emit_relations are driven end to
end, so inverting or deleting a check breaks a test (the repo's mutation-test discipline).
"""

import io
import json
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

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


class _TmpRootTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()


class CheckExternalTests(_TmpRootTest):
    def _external(self, text: str) -> Path:
        path = self.root / "EXTERNAL.md"
        path.write_text(text, encoding="utf-8")
        return path

    # --- GitHub-URL invariant ------------------------------------------------
    def test_clean_passes(self) -> None:
        self.assertEqual(ed.check_external("A", self._external(GOOD_EXTERNAL)), [])

    def test_missing_url_fails(self) -> None:
        text = GOOD_EXTERNAL.replace(
            "https://github.com/nazumods/wow", "https://example.com"
        )
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("first line" in p for p in problems), problems)

    def test_wrong_repo_superstring_fails(self) -> None:
        # A `wow`-prefixed sibling repo must NOT satisfy the "links home" invariant.
        text = "See https://github.com/nazumods/wow-companion here\n\n## Found a bug?\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("first line" in p for p in problems), problems)

    def test_url_not_on_first_line_fails(self) -> None:
        text = "# Title first\n\nhttps://github.com/nazumods/wow\n\n## Found a bug?\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("first line" in p for p in problems), problems)

    def test_url_only_in_html_comment_fails(self) -> None:
        # Invisible on the rendered page => must not satisfy the invariant.
        text = "<!-- https://github.com/nazumods/wow -->\n\n## Found a bug?\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("first line" in p for p in problems), problems)

    def test_markdown_link_url_passes(self) -> None:
        text = "Home: [source](https://github.com/nazumods/wow)\n\n## Found a bug?\n"
        self.assertEqual(ed.check_external("A", self._external(text)), [])

    def test_leading_blank_lines_skipped(self) -> None:
        text = "\n\n\nhttps://github.com/nazumods/wow\n\n## Found a bug?\n"
        self.assertEqual(ed.check_external("A", self._external(text)), [])

    # --- bug/suggestion-section invariant ------------------------------------
    def test_missing_bug_section_fails(self) -> None:
        text = "https://github.com/nazumods/wow\n\n# Title\n\nJust prose, no reporting path.\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("bug" in p.lower() for p in problems), problems)

    def test_plain_text_bug_keyword_without_header_fails(self) -> None:
        # Pins the "must be a section HEADER" rule: the keyword is present, but only as
        # prose, so it must still fail (distinct from test_missing_bug_section_fails,
        # where the keyword is absent entirely).
        text = "https://github.com/nazumods/wow\n\nFound a bug? Have a suggestion? Email us.\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("bug" in p.lower() for p in problems), problems)

    def test_bold_bug_section_passes(self) -> None:
        text = (
            "https://github.com/nazumods/wow\n\n**Found a bug? Have a suggestion?**\n"
        )
        self.assertEqual(ed.check_external("A", self._external(text)), [])

    def test_setext_bug_section_passes(self) -> None:
        text = "https://github.com/nazumods/wow\n\nFound a bug? Have a suggestion?\n------------\n"
        self.assertEqual(ed.check_external("A", self._external(text)), [])

    def test_bug_section_only_in_html_comment_fails(self) -> None:
        text = "https://github.com/nazumods/wow\n\n<!--\n## Found a bug?\n-->\n\nJust prose.\n"
        problems = ed.check_external("A", self._external(text))
        self.assertTrue(any("bug" in p.lower() for p in problems), problems)

    def test_empty_file_reports_both(self) -> None:
        problems = ed.check_external("A", self._external(""))
        self.assertEqual(len(problems), 2, problems)


class RelationsTests(_TmpRootTest):
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

    def test_slug_hyphenates_underscored_folder(self) -> None:
        _make_addon(
            self.root, "Warbandeer_Characters", "## X-Curse-Project-ID: 1546588\n"
        )
        _make_addon(
            self.root,
            "Dep",
            "## Dependencies: Warbandeer_Characters\n## X-Curse-Project-ID: 9\n",
        )
        ids = ed.curse_ids(self.root)
        projects = ed.relations_for("Dep", self.root, ids)["projects"]
        self.assertEqual(projects[0]["slug"], "warbandeer-characters")
        self.assertEqual(projects[0]["projectID"], "1546588")

    def test_dep_list_drops_none_and_notes_and_dedupes(self) -> None:
        self.assertEqual(ed.dep_list("none"), [])
        self.assertEqual(ed.dep_list(""), [])
        self.assertEqual(
            ed.dep_list("LibNAddOn, Warbandeer_Bars (`bars` view), LibNAddOn"),
            ["LibNAddOn", "Warbandeer_Bars"],
        )


class LintTests(_TmpRootTest):
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


class MainTests(_TmpRootTest):
    """Drive main() end to end so the gate-wiring exit codes and --emit-relations
    routing are pinned (not just the pure helpers)."""

    def _run(self, *extra: str) -> tuple[int, str, str]:
        argv = ["external_drift.py", "--root", str(self.root), *extra]
        out, err = io.StringIO(), io.StringIO()
        with (
            mock.patch.object(sys, "argv", argv),
            redirect_stdout(out),
            redirect_stderr(err),
        ):
            code = ed.main()
        return code, out.getvalue(), err.getvalue()

    def test_exit_0_when_clean(self) -> None:
        _make_addon(self.root, "Good", "## Title: X\n", external=GOOD_EXTERNAL)
        code, _, _ = self._run()
        self.assertEqual(code, 0)

    def test_exit_1_on_drift(self) -> None:
        _make_addon(self.root, "Bad", "## Title: X\n", external="no url, no section\n")
        code, _, _ = self._run()
        self.assertEqual(code, 1)

    def test_exit_0_when_no_external_files(self) -> None:
        _make_addon(self.root, "NoExt", "## Title: X\n")
        code, out, _ = self._run()
        self.assertEqual(code, 0)
        self.assertIn("0 EXTERNAL.md checked", out)

    def test_emit_relations_all_published(self) -> None:
        _make_addon(self.root, "Lib", "## X-Curse-Project-ID: 111\n")
        _make_addon(
            self.root, "App", "## Dependencies: Lib\n## X-Curse-Project-ID: 222\n"
        )
        code, out, _ = self._run("--emit-relations")
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(sorted(data), ["App", "Lib"])
        self.assertEqual(data["App"]["projects"][0]["projectID"], "111")

    def test_emit_relations_single_addon(self) -> None:
        _make_addon(self.root, "Lib", "## X-Curse-Project-ID: 111\n")
        _make_addon(
            self.root, "App", "## Dependencies: Lib\n## X-Curse-Project-ID: 222\n"
        )
        code, out, _ = self._run("--emit-relations", "App")
        self.assertEqual(code, 0)
        self.assertEqual(list(json.loads(out)), ["App"])

    def test_emit_relations_unknown_addon_exits_1(self) -> None:
        _make_addon(self.root, "Lib", "## X-Curse-Project-ID: 111\n")
        code, _, err = self._run("--emit-relations", "Ghost")
        self.assertEqual(code, 1)
        self.assertIn("Ghost", err)


if __name__ == "__main__":
    unittest.main()
