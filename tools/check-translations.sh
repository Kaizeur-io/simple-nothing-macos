#!/bin/sh
# Vérifie que chaque texte français passé à l'interface a sa traduction en anglais et en espagnol.
# Lit les fichiers comme macOS les lit (plutil), pour repérer aussi un fichier abîmé.
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, pathlib, re, subprocess, sys
found = set()
pattern = re.compile(r'(?:\btr\(|Caps\(|SectionTitle\(|title: |subtitle: |label: |CardHead\(title: |[?:] |-> String \{ |: |return |\(|, )"((?:[^"\\]|\\.)+)"')
for file in pathlib.Path("Sources/SimpleNothing").glob("*.swift"):
    if file.name in ("Journal.swift", "Verification.swift"): continue
    for line in file.read_text().split("\n"):
        if "Journal.note" in line or "systemName" in line and "tr(" not in line: continue
        for match in pattern.finditer(line):
            text = match.group(1)
            if re.search(r"[A-Za-zÀ-ÿ]{2}", text) and re.search(r"[a-zà-ÿ] |[àâçéèêëîïôûù]|^[A-ZÉ][a-zà-ÿ]+$", text) and "\\(" not in text:
                found.add(text.replace('\\"', '"'))
# Noms propres et mots identiques d'une langue à l'autre : rien à traduire.
same = {"App", "Bodoni 72", "CMF Headphone Pro", "Codec", "Concert", "Dirac Opteo", "English", "Español", "Firmware", "Français",
        "MacBook Pro", "Orange", "Phone (3)", "Pop", "Rock"}
found = {text for text in found if text not in same and not text.endswith("\\n")}
status = 0
for lang in ("en", "es"):
    path = f"Sources/SimpleNothing/Traductions/{lang}.lproj/Localizable.strings"
    table = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", path], capture_output=True, text=True, check=True).stdout)
    missing = sorted(text for text in found if text not in table)
    print(f"{lang} : {len(table)} traductions, {len(missing)} texte(s) sans traduction")
    for text in missing: print("   ", text)
    status |= bool(missing)
sys.exit(status)
PY
