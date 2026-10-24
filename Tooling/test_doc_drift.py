#!/usr/bin/env python3
"""unittest coverage for doc_drift.py (nazumods/wow#1077).

Runs fully offline against tempdir fixtures. Invoke directly
(`python Tooling/test_doc_drift.py`) or via `python -m unittest`. Every rule has a
passing AND a failing fixture, and main() is driven end to end, so inverting or deleting
a check breaks a test (the repo's mutation-test discipline).
"""

import io
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import doc_drift as dd  # noqa: E402


def _header(**fields: str) -> str:
    """A CONTEXT.md whose line 3 is the `**Deps:**` header with the given extra fields."""
    parts = ["**Deps:** none"] + [f"**{k}:** {v}" for k, v in fields.items()]
    return "# Addon\n\n" + " · ".join(parts) + "\n\nBody.\n"


class _TmpRootTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def addon(self, name: str, toc: str, context: str | None) -> Path:
        d = self.root / name
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{name}.toc").write_text(toc, encoding="utf-8")
        if context is not None:
            (d / "CONTEXT.md").write_text(context, encoding="utf-8")
        return d

    def check(self, toc: str, context: str) -> list[str]:
        d = self.addon("A", toc, context)
        return dd.check_addon("A", d / "A.toc", d / "CONTEXT.md")


class ParsingTests(unittest.TestCase):
    def test_dep_names_drops_parens_and_none(self) -> None:
        self.assertEqual(
            dd.dep_names("Warbandeer_Bars (`bars`, view), Other"), {"Warbandeer_Bars", "Other"}
        )
        self.assertEqual(dd.dep_names("none"), set())
        self.assertEqual(dd.dep_names(""), set())

    def test_ascii_only_replaces_non_ascii(self) -> None:
        self.assertEqual(dd.ascii_only("a·b"), "a?b")


class DbVersionTests(_TmpRootTest):
    def test_matching_version_passes(self) -> None:
        toc = "## X-NUI-DB-VERSION: 3\n"
        self.assertEqual(self.check(toc, _header(SavedVars="`ADB` (v3)")), [])

    def test_mismatched_version_fails(self) -> None:
        toc = "## X-NUI-DB-VERSION: 4\n"
        problems = self.check(toc, _header(SavedVars="`ADB` (v3)"))
        self.assertEqual(len(problems), 1)
        self.assertIn("X-NUI-DB-VERSION is 4", problems[0])

    def test_db_spelling_is_accepted(self) -> None:
        toc = "## X-NUI-DB-VERSION: 2\n"
        self.assertEqual(self.check(toc, _header(DB="`ADB` (v2)")), [])

    def test_toc_version_without_header_field_fails(self) -> None:
        problems = self.check("## X-NUI-DB-VERSION: 1\n", _header())
        self.assertTrue(any("no SavedVars/DB field" in p for p in problems), problems)

    def test_header_claims_version_toc_lacks_fails(self) -> None:
        problems = self.check("## Title: A\n", _header(SavedVars="`ADB` (v3)"))
        self.assertTrue(any("no X-NUI-DB-VERSION" in p for p in problems), problems)

    def test_none_pairs_with_no_toc_version(self) -> None:
        self.assertEqual(self.check("## Title: A\n", _header(SavedVars="none")), [])

    def test_missing_deps_header_fails(self) -> None:
        problems = self.check("## Title: A\n", "# Addon\n\nNo header here.\n")
        self.assertEqual(len(problems), 1)
        self.assertIn("no '**Deps:**' header", problems[0])


class OptionalDepsTests(_TmpRootTest):
    def test_matching_ignores_notes_and_order(self) -> None:
        toc = "## OptionalDeps: B, A\n"
        ctx = _header(OptionalDeps="A (note, with comma), B")
        self.assertEqual(self.check(toc, ctx), [])

    def test_drift_fails(self) -> None:
        problems = self.check("## OptionalDeps: A\n", _header(OptionalDeps="A, B"))
        self.assertEqual(len(problems), 1)
        self.assertIn("OptionalDeps drift", problems[0])

    def test_toc_declares_but_header_silent_fails(self) -> None:
        problems = self.check("## OptionalDeps: A\n", _header())
        self.assertTrue(any("OptionalDeps drift" in p for p in problems), problems)

    def test_neither_declares_passes(self) -> None:
        self.assertEqual(self.check("## Title: A\n", _header()), [])


class CurseIdTests(_TmpRootTest):
    def test_id_with_pending_note_fails(self) -> None:
        ctx = _header() + "- No `X-Curse-Project-ID` yet\n"
        problems = self.check("## X-Curse-Project-ID: 123\n", ctx)
        self.assertEqual(len(problems), 1)
        self.assertIn("X-Curse-Project-ID 123", problems[0])

    def test_id_without_note_passes(self) -> None:
        self.assertEqual(self.check("## X-Curse-Project-ID: 123\n", _header()), [])

    def test_note_without_id_passes(self) -> None:
        # One direction only: an addon with no id is not required to say so, nor forbidden.
        ctx = _header() + "- No `X-Curse-Project-ID` yet\n"
        self.assertEqual(self.check("## Title: A\n", ctx), [])


class MainTests(_TmpRootTest):
    def run_main(self) -> tuple[int, str]:
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["doc_drift.py", "--root", str(self.root)]):
            with redirect_stdout(out):
                code = dd.main()
        return code, out.getvalue()

    def test_clean_tree_exits_zero(self) -> None:
        self.addon("A", "## Title: A\n", _header())
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("1 addons checked, 0 problem(s)", out)

    def test_drift_exits_one(self) -> None:
        self.addon("A", "## OptionalDeps: X\n", _header())
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("! A: OptionalDeps drift", out)

    def test_addon_without_context_is_skipped(self) -> None:
        self.addon("A", "## OptionalDeps: X\n", None)
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("0 addons checked", out)

    def test_non_addon_dirs_are_ignored(self) -> None:
        (self.root / "Tooling").mkdir()
        (self.root / ".hidden").mkdir()
        self.assertEqual(dd.addon_dirs(self.root), [])

    def test_output_is_ascii(self) -> None:
        self.addon("A", "## X-NUI-DB-VERSION: 1\n", _header(SavedVars="café"))
        code, out = self.run_main()
        self.assertEqual(code, 1)
        out.encode("ascii")


if __name__ == "__main__":
    unittest.main()
