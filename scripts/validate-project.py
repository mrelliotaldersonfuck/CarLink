#!/usr/bin/env python3
"""Validate portable configuration; iOS compilation happens in the macOS workflow."""
from pathlib import Path
import json
import plistlib
import re

root = Path(__file__).resolve().parents[1]
info = plistlib.loads((root / "CarLink/Info.plist").read_bytes())
entitlements = plistlib.loads((root / "CarLink/CarLink.entitlements").read_bytes())
privacy = plistlib.loads((root / "CarLink/PrivacyInfo.xcprivacy").read_bytes())
assert entitlements == {"com.apple.developer.carplay-audio": True}, "Build 45 restores the audio category without combining video"
assert info["CarLinkCarPlayCategory"] == "audio"
assert info["CarLinkExperiment"] == "window-45"
scene = info["UIApplicationSceneManifest"]["UISceneConfigurations"]
assert "UIWindowSceneSessionRoleApplication" not in scene, "SwiftUI manages the phone scene"
car_scene = scene["CPTemplateApplicationSceneSessionRoleApplication"][0]
assert car_scene["UISceneClassName"] == "CPTemplateApplicationScene"
window_scene = scene["UIWindowSceneSessionRoleCarPlay"][0]
assert window_scene["UISceneClassName"] == "UIWindowScene"
assert window_scene["UISceneDelegateClassName"] == "$(PRODUCT_MODULE_NAME).CarWindowSceneDelegate"
assert info["CFBundleIdentifier"] == "$(PRODUCT_BUNDLE_IDENTIFIER)"
assert info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)"
assert info["AVInitialRouteSharingPolicy"] == "LongFormVideo"
assert privacy["NSPrivacyTracking"] is False
spec = (root / "project.yml").read_text(encoding="utf-8")
for key, value in {
    "PRODUCT_BUNDLE_IDENTIFIER": "com.carlink.CarLink",
    "IPHONEOS_DEPLOYMENT_TARGET": '"18.0"',
    "MARKETING_VERSION": '"0.6.0"',
    "SWIFT_VERSION": '"5.0"',
}.items():
    assert re.search(rf"^\s+{key}:\s*{re.escape(value)}\s*$", spec, re.M), f"Unexpected {key}"
build = re.search(r'^\s+CURRENT_PROJECT_VERSION:\s*"([0-9]+)"\s*$', spec, re.M)
assert build and int(build.group(1)) > 0, "Build number must be a positive integer"
for path in root.rglob("*.json"):
    if not any(part in {".build", "build", ".git"} for part in path.parts):
        json.loads(path.read_text(encoding="utf-8"))
icon = root / "CarLink/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
assert icon.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "Missing app icon"
print("Configuration, scene manifest, privacy manifest, entitlements and assets: OK")
