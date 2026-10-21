#!/usr/bin/python3
"""Guard: no native text input anywhere in the plugin.

Qt's TextInput / TextField / TextArea / TextEdit watch the system clipboard and
read foreign text through Qt's Wayland receiver, which has no total byte limit
and no deadline. Intercepting paste keys does not stop that, so Omanager draws
its fields itself (PasteInput.qml, built from a plain Text) and reads the
clipboard only through Service.requestPaste (wl-paste, 1 KB cap, 2 s deadline).

This test fails if a native text element, a Controls import, or a direct
clipboard hook appears in any plugin file, and if the capped read loses its cap.

    python3 tests/test_no_native_text.py
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
failures = []


def code_only(src):
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    return re.sub(r"//[^\n]*", "", src)


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as fh:
        return fh.read()


FORBIDDEN = [
    (r"\b(TextInput|TextField|TextArea|TextEdit|SpinBox|ComboBox|Editable\w*)\s*\{", "native text element"),
    (r"^\s*import\s+QtQuick\.Controls", "QtQuick.Controls import"),
    (r"\bQt\.inputMethod\b", "input method hook"),
    (r"\bcanPaste\b", "canPaste (native clipboard watching)"),
    (r"\.paste\s*\(", "direct paste() call"),
    (r"Qt\.application\.clipboard|\bClipboard\b", "Qt clipboard object"),
]

files = sorted(glob.glob(os.path.join(ROOT, "qml", "**", "*.qml"), recursive=True))
for path in files:
    name = os.path.relpath(path, ROOT)
    src = code_only(read(name))
    for pattern, what in FORBIDDEN:
        if re.search(pattern, src, flags=re.M):
            failures.append("%s: %s" % (name, what))

# the typed-text field is the only thing allowed to be a text field, and it is a Text
paste = code_only(read("qml/controls/PasteInput.qml"))
if not re.search(r"\bText\s*\{\s*id:\s*display", paste):
    failures.append("PasteInput.qml: no longer drawn from a plain Text")

# the explicit paste path stays bounded
svc = code_only(read("qml/Service.qml"))
if not re.search(r"pasteMax:\s*1024", svc):
    failures.append("Service.qml: paste byte cap missing or changed")
if not re.search(r"Timer\s*\{\s*id:\s*pasteKill\s*interval:\s*2000", svc):
    failures.append("Service.qml: paste deadline missing or changed")
if '"wl-paste"' not in svc or "sh" in re.findall(r'command:\s*\[\s*"(\w+)"', svc[svc.index("pasteProc"):]):
    failures.append("Service.qml: paste must run wl-paste directly, not through a shell")

# every field is a PasteInput
for name in ("qml/panel/ManagerView.qml", "qml/panel/SettingRow.qml"):
    if "PasteInput" not in read(name):
        failures.append("%s: expected PasteInput" % name)

# the version being shipped has a changelog entry
version = json.loads(read("manifest.json"))["version"]
if ("### " + version) not in read("README.md"):
    failures.append("README.md: no changelog entry for %s" % version)

if failures:
    print("FAIL")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("ok: %d QML files, no native text input, paste read is capped (1 KB, 2 s), v%s documented" % (len(files), version))
