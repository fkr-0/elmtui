"""Negative and positive contract tests for the external dependency gate."""
import unittest

from dependency_oracle import DEPENDENCIES, qualify_dependency_result


class DependencyOracleTests(unittest.TestCase):
    def log(self, count=4):
        return "\n".join(
            f"==> testing {name} independently\nDid 5 checks.\n"
            "    Pass: 5 (100%)\n    Skip: 0\n    Fail: 0"
            for name in DEPENDENCIES[:count]
        ) + "\nAll reusable subsystem tests passed."

    def test_accepts_four_independent_successful_test_suites(self):
        self.assertTrue(qualify_dependency_result({"exit_code": 0}, self.log())[0])

    def test_rejects_missing_test_suite_even_with_success_marker(self):
        self.assertFalse(qualify_dependency_result({"exit_code": 0}, self.log(3))[0])

    def test_rejects_false_success_when_child_failed(self):
        self.assertFalse(qualify_dependency_result({"exit_code": 1}, self.log())[0])

    def test_rejects_zero_checks(self):
        self.assertFalse(qualify_dependency_result(
            {"exit_code": 0}, self.log().replace("Did 5 checks.", "Did 0 checks.", 1)
        )[0])

    def test_rejects_nonzero_failures(self):
        self.assertFalse(qualify_dependency_result(
            {"exit_code": 0}, self.log().replace("Fail: 0", "Fail: 1", 1)
        )[0])


if __name__ == "__main__":
    unittest.main()
