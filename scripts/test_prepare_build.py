import tempfile
from pathlib import Path
import unittest
import importlib.util
from unittest.mock import patch
import subprocess

spec = importlib.util.spec_from_file_location("prepare_build", Path(__file__).with_name("prepare-build.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BuildNumberTests(unittest.TestCase):
    def test_base_is_above_previous_44(self):
        self.assertEqual(module.choose_build({}, 44), 45)
        self.assertEqual(module.choose_build({}, 18), 45)

    def test_builtin_workflow_counter_does_not_override_version(self):
        self.assertEqual(module.choose_build({"BUILD_NUMBER": "2", "PROJECT_BUILD_NUMBER": "8"}, 47), 48)

    def test_counter_increases_and_explicit_override(self):
        self.assertGreater(module.choose_build({}, 48), module.choose_build({}, 47))
        self.assertEqual(module.choose_build({"CARLINK_BUILD_NUMBER": "100"}, 47), 100)

    def test_bad_and_old_numbers_are_rejected(self):
        for environment in [{"CARLINK_BUILD_NUMBER": "40"}, {"CARLINK_BUILD_NUMBER": "-1"}, {"CARLINK_BUILD_NUMBER": "x"}]:
            with self.assertRaises(ValueError):
                module.choose_build(environment, 47)
        with self.assertRaises(ValueError):
            module.choose_build({"CARLINK_BUILD_NUMBER": "44"}, 18)

    def test_updates_only_version_setting(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "project.yml"
            source = 'settings:\n  base:\n    CURRENT_PROJECT_VERSION: "41"\n    MARKETING_VERSION: "0.6.0"\n'
            path.write_text(source, encoding="utf-8")
            self.assertEqual(module.prepare(root, {}, 48), 49)
            self.assertEqual(path.read_text(encoding="utf-8"), source.replace('"41"', '"49"'))

    @patch.object(module.subprocess, "run")
    def test_latest_is_read_from_apple_app_id(self, command):
        command.return_value = subprocess.CompletedProcess([], 0, "48\n", "")
        self.assertEqual(module.read_latest_build({"APP_STORE_APPLE_ID": "6819000403"}), 48)
        arguments = command.call_args.args[0]
        self.assertIn("6819000403", arguments)
        self.assertIn("0.6.0", arguments)

    @patch.object(module.subprocess, "run")
    def test_api_errors_do_not_fall_back_to_an_old_number(self, command):
        command.side_effect = subprocess.CalledProcessError(1, "app-store-connect")
        with self.assertRaises(ValueError):
            module.read_latest_build({})
        command.side_effect = None
        command.return_value = subprocess.CompletedProcess([], 0, "", "")
        with self.assertRaises(ValueError):
            module.read_latest_build({})


if __name__ == "__main__":
    unittest.main()
