"""Exercise signing checks with fake artifacts, without Apple tools or credentials."""
from pathlib import Path
import contextlib
import datetime
import io
import os
import plistlib
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SCRIPT = Path(__file__).with_name("verify-ipa.py").resolve()
VIDEO = "com.apple.developer.carplay-video"
AUDIO = "com.apple.developer.carplay-audio"


class SigningChecks(unittest.TestCase):
    def execute(self, granted, signed, expired=False, missing_scene=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            ipa = root / "build/ios/ipa/CarLink.ipa"
            ipa.parent.mkdir(parents=True)
            info = {"CFBundleIdentifier": "com.carlink.CarLink", "CFBundleShortVersionString": "0.6.0", "CFBundleVersion": "45",
                    "CarLinkCarPlayCategory": "audio", "CarLinkExperiment": "window-45",
                    "UIApplicationSceneManifest": {"UISceneConfigurations": {} if missing_scene else {
                        "UIWindowSceneSessionRoleCarPlay": [{"UISceneClassName": "UIWindowScene",
                            "UISceneDelegateClassName": "CarLink.CarWindowSceneDelegate"}]}}}
            with zipfile.ZipFile(ipa, "w") as archive:
                archive.writestr("Payload/CarLink.app/Info.plist", plistlib.dumps(info))
                archive.writestr("Payload/CarLink.app/embedded.mobileprovision", b"fake-profile")
            expiry = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) + datetime.timedelta(days=-1 if expired else 1)
            profile = {"ExpirationDate": expiry, "Entitlements": {"application-identifier": "TEAM.com.carlink.CarLink", **granted}}
            original = Path.cwd()
            try:
                os.chdir(root)
                with patch("subprocess.check_output", return_value=plistlib.dumps(profile)), \
                     patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0, plistlib.dumps(signed), b"")) as command, \
                     contextlib.redirect_stdout(io.StringIO()):
                    runpy.run_path(str(SCRIPT), run_name="__main__")
                    self.assertTrue(any("--verify" in call.args[0] for call in command.call_args_list))
            finally:
                os.chdir(original)

    def test_broader_profile_with_audio_only_signature_is_allowed(self):
        self.execute({VIDEO: True, AUDIO: True}, {AUDIO: True})

    def test_combined_categories_in_executable_are_rejected(self):
        with self.assertRaisesRegex(SystemExit, "inesperada"):
            self.execute({VIDEO: True, AUDIO: True}, {VIDEO: True, AUDIO: True})

    def test_video_only_signature_that_hid_the_icon_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "inesperada"):
            self.execute({VIDEO: True, AUDIO: True}, {VIDEO: True})

    def test_missing_audio_in_profile_or_signature_is_rejected(self):
        for granted, signed in [({}, {AUDIO: True}), ({AUDIO: True}, {}), ({AUDIO: False}, {AUDIO: True})]:
            with self.subTest(granted=granted, signed=signed), self.assertRaisesRegex(SystemExit, "ausente"):
                self.execute(granted, signed)

    def test_expired_profile_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "expirado"):
            self.execute({AUDIO: True}, {AUDIO: True}, expired=True)

    def test_missing_window_manifest_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "cena própria"):
            self.execute({AUDIO: True}, {AUDIO: True}, missing_scene=True)


if __name__ == "__main__":
    unittest.main()
