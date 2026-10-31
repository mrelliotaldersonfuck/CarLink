#!/usr/bin/env python3
"""Repeat the compiler diagnostics at the end of a noisy xcodebuild log."""
from pathlib import Path
import re
import sys


def summarize(text: str) -> str:
    lines = text.splitlines()
    matches = []
    seen = set()
    for index, line in enumerate(lines):
        if re.search(r"(?:fatal )?error:|Undefined symbols|duplicate symbol|CodeSign.*failed", line, re.I):
            if line not in seen:
                seen.add(line)
                matches.append(index)
    if not matches:
        return (
            "O trecho disponível não contém o diagnóstico específico. "
            "Baixe o artefato build/compile.log completo e CarLink.xcresult.\n"
        )
    sections = ["Erros de compilação (consulte compile.log para o contexto completo):"]
    for index in matches[:25]:
        sections.append("\n".join(lines[max(0, index - 2):min(len(lines), index + 7)]))
    return "\n\n".join(sections) + "\n"


if __name__ == "__main__":
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/compile.log")
    result = summarize(path.read_text(encoding="utf-8", errors="replace"))
    path.with_name("compile-errors.txt").write_text(result, encoding="utf-8")
    print(result)
