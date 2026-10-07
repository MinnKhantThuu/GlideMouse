#!/usr/bin/env python3
"""Validate every locale and format argument before shipping a translation."""
import json
import plistlib
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
catalog = json.loads((root / "Sources/GlideMouse/Resources/Localizable.xcstrings").read_text())
languages = ("en", "my", "zh-Hans")
errors = []
formats = re.compile(r"%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?(?:l{1,2})?[@diufgs]")
for key, entry in catalog["strings"].items():
    units = entry.get("localizations", {})
    source = units.get("en", {}).get("stringUnit", {}).get("value", key)
    for language in languages:
        unit = units.get(language, {}).get("stringUnit", {})
        value = unit.get("value", "")
        if not value or unit.get("state") != "translated":
            errors.append(f"{language}: missing translation for {key}")
        if formats.findall(source) != formats.findall(value):
            errors.append(f"{language}: format arguments differ for {key}")
for source in (root / "Sources/GlideMouse").rglob("*.swift"):
    if "Harness" in source.name:
        continue
    for key in re.findall(r'(?:model\.)?text\("([^"\\]*)"\)', source.read_text()):
        if key not in catalog["strings"]:
            errors.append(f"{source.name}: missing literal key {key}")
for source in (root / "Sources/MouseCore").rglob("*.swift"):
    for key in re.findall(r'ConfigurationError\.invalid\("([^"\\]*)"\)', source.read_text()):
        if key not in catalog["strings"]:
            errors.append(f"{source.name}: missing validation message {key}")
# Optional .app argument also checks that Xcode shipped every translated value.
if len(sys.argv) > 1:
    resources = Path(sys.argv[1]) / "Contents/Resources"
    for language in languages:
        data = (resources / f"{language}.lproj/Localizable.strings").read_bytes()
        # Xcode can emit UTF-16 XML with a UTF-8 declaration. Normalize the BOM
        # before Python's XML parser reads it; binary plists remain untouched.
        if data.startswith((b"\xff\xfe", b"\xfe\xff")):
            data = data.decode("utf-16").encode("utf-8")
        compiled = plistlib.loads(data)
        for key, entry in catalog["strings"].items():
            expected = entry["localizations"][language]["stringUnit"]["value"]
            if compiled.get(key) != expected:
                errors.append(f"{language}: compiled value differs for {key}")
result = {"passed": not errors, "entries": len(catalog["strings"]), "languages": languages, "compiledBundleChecked": len(sys.argv) > 1, "errors": errors}
print(json.dumps(result, ensure_ascii=False, indent=2))
raise SystemExit(0 if not errors else 1)
