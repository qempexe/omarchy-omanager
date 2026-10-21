#!/usr/bin/python3
"""Guard: every helper command is an argument array with limits.

  * nothing collects a command's whole output (StdioCollector): output is read
    through core/Run.qml, which stops a command past its size or time limit
  * no command goes through a shell (sh -c / bash -c)
  * curl is only used through Model.curlArgs, which keeps https only, a time
    limit and a size limit

    python3 tests/test_helpers.py
"""
import glob, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
fails = []


def code(path):
    src = open(path, encoding="utf-8").read()
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    return re.sub(r"(?<![:\"'])//[^\n]*", "", src)


qml = sorted(glob.glob(os.path.join(ROOT, "qml", "**", "*.qml"), recursive=True))
js = sorted(glob.glob(os.path.join(ROOT, "qml", "**", "*.js"), recursive=True))
for path in qml + js:
    name = os.path.relpath(path, ROOT)
    src = code(path)
    if "StdioCollector" in src:
        fails.append(name + ": StdioCollector reads unbounded output; use Run")
    if re.search(r'"(ba)?sh"\s*,\s*"-c"', src):
        fails.append(name + ": command through a shell")
    if re.search(r'"curl"', src) and not name.endswith("Model.js"):
        fails.append(name + ": build curl commands with Model.curlArgs")

model = code(os.path.join(ROOT, "qml/js/Model.js"))
for flag in ('"-q"', '"=https"', '"--proto-redir"', '"--max-time"', '"--max-filesize"'):
    if flag not in model:
        fails.append("Model.curlArgs: missing " + flag)

run = code(os.path.join(ROOT, "qml/core/Run.qml"))
if '"timeout", "-k"' not in run:
    fails.append("Run.qml: commands must run under timeout")
if 'splitMarker: ""' not in run:
    fails.append("Run.qml: output must be read in chunks")

if fails:
    print("FAIL")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("ok: %d files, helpers bounded, no shell, curl https only" % len(qml + js))
