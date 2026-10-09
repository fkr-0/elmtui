"""Contracts for the public re-export manifest generator; no SBCL needed."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import unittest

MODULE_PATH = Path(__file__).resolve().parents[2] / "scripts/audit-facade-exports.py"
spec = spec_from_file_location("facade_exports", MODULE_PATH)
audit = module_from_spec(spec)
spec.loader.exec_module(audit)


class ExportManifestTests(unittest.TestCase):
    def test_framework_names_require_exact_or_dot_boundary(self):
        self.assertTrue(audit.in_framework("ELMTUI"))
        self.assertTrue(audit.in_framework("CL-EVENTS.ASYNC"))
        self.assertFalse(audit.in_framework("ELMTUI-PROVISIONAL"))
        self.assertFalse(audit.in_framework("CL-STATELESS"))
        self.assertFalse(audit.in_framework("COMMON-LISP"))

    def test_known_standard_restart_aliases(self):
        for exporter, home, symbol in audit.LEGACY:
            self.assertEqual("legacy-standard-restart",
                             audit.classify(exporter, home, symbol, "EXTERNAL"))

    def test_private_origin_exposure_is_not_marked_reviewed(self):
        self.assertEqual(
            "private-origin-compat-review",
            audit.classify("ELMTUI.VIEW.STYLED", "ELMTUI.VIEW.API",
                           "UI-NODE-PROPS", "INTERNAL"),
        )

    def test_normal_public_alias_retained(self):
        self.assertEqual(
            "public-alias-retain",
            audit.classify("CL-STATE.API", "CL-STATE.CORE", "STATE-REF", "EXTERNAL"),
        )

    def test_foreign_or_unexpected_origin_fails_closed(self):
        with self.assertRaises(ValueError):
            audit.classify("ELMTUI", "SB-PCL", "SLOT-DEFINITION-NAME", "EXTERNAL")
        with self.assertRaises(ValueError):
            audit.classify("ELMTUI", "CL-STATELESS", "FAKE", "EXTERNAL")
        with self.assertRaises(ValueError):
            audit.classify("ELMTUI", "CL-STATE.API", "FAKE", "INHERITED")

    def test_render_has_stable_tsv_schema(self):
        row = dict(exporter="ELMTUI.APP", home="ELMTUI.APP.API",
                   symbol="MAKE-APP-CONFIG", home_status="INTERNAL",
                   identity="identical", review_status="private-origin-compat-review")
        output = audit.render([row])
        lines = output.splitlines()
        self.assertEqual("\t".join(audit.COLUMNS), lines[0])
        self.assertEqual(2, len(lines))
        self.assertEqual(6, len(lines[1].split("\t")))


if __name__ == "__main__":
    unittest.main()
