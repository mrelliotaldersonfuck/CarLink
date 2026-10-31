#!/usr/bin/env python3
"""Verify audio-only signing to restore the CarPlay catalog in experiment 45."""
from pathlib import Path
import datetime
import plistlib
import subprocess
import tempfile
import zipfile

required = ("com.apple.developer.carplay-audio",)
ipas = sorted(Path("build/ios/ipa").glob("*.ipa"), key=lambda p: p.stat().st_mtime)
if not ipas:
    raise SystemExit("Nenhum IPA foi gerado em build/ios/ipa.")
with tempfile.TemporaryDirectory(prefix="carlink-signing-") as temporary:
    destination = Path(temporary)
    with zipfile.ZipFile(ipas[-1]) as archive:
        # A build artifact is expected, but still keep extraction inside the temp directory.
        for member in archive.infolist():
            resolved = (destination / member.filename).resolve()
            if not resolved.is_relative_to(destination.resolve()):
                raise SystemExit("Caminho inválido dentro do IPA.")
        archive.extractall(destination)
        for member in archive.infolist():
            mode = (member.external_attr >> 16) & 0o777
            if mode:
                (destination / member.filename).chmod(mode)
    apps = list((destination / "Payload").glob("*.app"))
    if len(apps) != 1:
        raise SystemExit("O IPA não contém exatamente um aplicativo.")
    app = apps[0]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != "com.carlink.CarLink":
        raise SystemExit("Bundle ID incorreto no IPA.")
    if info.get("CarLinkCarPlayCategory") != "audio" or info.get("CarLinkExperiment") != "window-45":
        raise SystemExit("O IPA não contém o experimento 45 com categoria áudio.")
    scenes = info.get("UIApplicationSceneManifest", {}).get("UISceneConfigurations", {})
    window_scenes = scenes.get("UIWindowSceneSessionRoleCarPlay", [])
    if not any(scene.get("UISceneClassName") == "UIWindowScene" and
               scene.get("UISceneDelegateClassName", "").endswith(".CarWindowSceneDelegate") for scene in window_scenes):
        raise SystemExit("A cena própria da janela está ausente no IPA.")
    profile = plistlib.loads(subprocess.check_output(
        ["security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")], stderr=subprocess.DEVNULL))
    if profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        raise SystemExit("Perfil de assinatura expirado.")
    granted = profile["Entitlements"]
    if not granted.get("application-identifier", "").endswith(".com.carlink.CarLink"):
        raise SystemExit("O perfil não corresponde ao App ID autorizado.")
    process = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)], capture_output=True, check=True)
    signed = plistlib.loads(process.stdout)
    # A profile can grant a superset of capabilities. The executable must only
    # request the selected category; do not reject a broader existing profile.
    if signed.get("com.apple.developer.carplay-video") is True:
        raise SystemExit("Categoria vídeo inesperada na assinatura: este build recupera a categoria áudio.")
    for key in required:
        if granted.get(key) is not True or signed.get(key) is not True:
            raise SystemExit(f"Entitlement ausente no perfil ou assinatura: {key}")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print(f"IPA verificado: {info['CFBundleIdentifier']} {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
    print("CarPlay áudio autorizado no perfil e assinatura; vídeo ausente da assinatura; experimento de janela incluído.")
