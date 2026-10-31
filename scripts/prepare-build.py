#!/usr/bin/env python3
"""Choose the next build from the existing App Store Connect integration."""
from pathlib import Path
import os
import re
import subprocess


def choose_build(environment, latest):
    override = environment.get("CARLINK_BUILD_NUMBER", "").strip()
    if latest < 0:
        raise ValueError("O último build do TestFlight não pode ser negativo.")
    if override and not re.fullmatch(r"[0-9]+", override):
        raise ValueError("CARLINK_BUILD_NUMBER deve ser um inteiro positivo.")
    number = int(override) if override else max(45, latest + 1)
    if number < 45 or number <= latest:
        raise ValueError(f"O próximo build deve ser maior que {latest} e no mínimo 45.")
    return number


def read_latest_build(environment):
    app_id = environment.get("APP_STORE_APPLE_ID", "6819000403")
    try:
        result = subprocess.run([
            "app-store-connect", "get-latest-testflight-build-number", app_id,
            "--platform", "IOS", "--pre-release-version", "0.6.0"
        ], capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError("Não foi possível consultar o TestFlight. Confira a integração CarLink e seu acesso à App Store Connect.") from error
    value = result.stdout.strip()
    if not re.fullmatch(r"[0-9]+", value):
        raise ValueError("A consulta ao TestFlight não retornou um número. O build não será enviado com um número de fallback.")
    return int(value)


def prepare(root, environment, latest):
    number = choose_build(environment, latest)
    path = root / "project.yml"
    spec = path.read_text(encoding="utf-8")
    spec, replacements = re.subn(
        r'^(\s+CURRENT_PROJECT_VERSION:)\s*"[0-9]+"\s*$',
        lambda match: f'{match.group(1)} "{number}"', spec, flags=re.M
    )
    if replacements != 1:
        raise ValueError("Não foi possível localizar um único CURRENT_PROJECT_VERSION no project.yml.")
    path.write_text(spec, encoding="utf-8")
    return number


if __name__ == "__main__":
    try:
        latest = read_latest_build(os.environ)
        build = prepare(Path(__file__).resolve().parents[1], os.environ, latest)
    except ValueError as error:
        raise SystemExit(str(error))
    print(f"Último build no TestFlight: {latest}")
    print(f"CarLink 0.6.0 · próximo build {build} · destino: TestFlight")
