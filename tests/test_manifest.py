#!/usr/bin/python3
"""Checks manifest.json against the QML and Schema.js: no setting declared but unread, or read but undeclared."""
import json, os, re, sys, unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def read(name):
    with open(os.path.join(ROOT, name)) as fh:
        return fh.read()


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.m = json.loads(read("manifest.json"))
        self.bw = self.m["barWidget"]

    def test_entry_points_exist(self):
        for rel in self.m["entryPoints"].values():
            self.assertTrue(os.path.isfile(os.path.join(ROOT, rel)), rel)

    def test_settings_drift(self):
        qml = read("BarWidget.qml")
        used = set(re.findall(r'setting\("([A-Za-z0-9_]+)"', qml))
        schema = {s["key"] for s in self.bw["schema"]}
        self.assertEqual(used, schema)
        self.assertEqual(set(self.bw["defaults"]), schema)

    def test_defaults_match_schema_and_qml_fallbacks(self):
        qml = read("BarWidget.qml")
        for s in self.bw["schema"]:
            self.assertEqual(self.bw["defaults"][s["key"]], s["defaultValue"], s["key"])
            m = re.search(r'setting\("%s", ([^)]+)\)' % s["key"], qml)
            lit = json.loads(m.group(1))
            self.assertEqual(lit, s["defaultValue"], "QML fallback for " + s["key"])
            if s["type"] == "enum":
                self.assertIn(s["defaultValue"], s["options"])
            if s["type"] == "integer":
                self.assertTrue(s["min"] <= s["defaultValue"] <= s["max"])

    def test_qml_choice_lists_match_manifest_options(self):
        qml = read("BarWidget.qml")
        for s in self.bw["schema"]:
            if s["type"] != "enum":
                continue
            # setting(...) may be wrapped by over(...) for popup overrides.
            m = re.search(
                r'setting\("%s", [^)]+\)\s*\)*\s*,\s*(\[[^\]]*\]|styleChoices)' % s["key"],
                qml,
            )
            self.assertIsNotNone(m, s["key"])
            if m.group(1) == "styleChoices":
                m2 = re.search(r'styleChoices: (\[[^\]]*\])', qml)
                opts = json.loads(m2.group(1))
            else:
                opts = json.loads(m.group(1))
            self.assertEqual(opts, s["options"], s["key"])

    def test_schema_js_matches_manifest(self):
        schema_js = read("Schema.js")
        groups = json.loads(re.search(r"var groups = (.*?);\n\nvar defaults", schema_js, re.S).group(1))
        items = {i["key"]: i for g in groups for i in g["items"]}
        self.assertEqual(set(items), {s["key"] for s in self.bw["schema"]})
        for s in self.bw["schema"]:
            self.assertEqual(items[s["key"]]["fallback"], s["defaultValue"], s["key"])

    def test_no_duplicate_signal_handlers(self):
        """QML refuses to load a component that defines the same on<X>Changed twice."""
        for name in sorted(f for f in os.listdir(ROOT) if f.endswith(".qml")):
            # top-level handlers only (4-space indent) so nested objects don't collide
            found = re.findall(r"^    (on[A-Z]\w*):", read(name), re.M)
            dupes = {h for h in found if found.count(h) > 1}
            self.assertFalse(dupes, "%s defines %s twice" % (name, sorted(dupes)))

    def test_no_shell_strings_or_eval(self):
        """Commands must be argument arrays; nothing should go through sh -c."""
        for name in ("Service.qml", "Model.js"):
            code = read(name)
            self.assertNotRegex(code, r'"sh"|"bash"|"-c"|\beval\(|new Function')

    def test_every_text_item_is_plain_text(self):
        """MPRIS metadata is attacker-controlled: Text.AutoText would render
        <img src=...> and fetch remote URLs. Every Text item must pin PlainText."""
        for name in sorted(f for f in os.listdir(ROOT) if f.endswith(".qml")):
            lines = read(name).split("\n")
            for i, line in enumerate(lines):
                if not re.match(r"^\s*(?:[\w.]+:\s*)?Text \{\s*$", line):
                    continue
                depth, block = 0, []
                for l in lines[i:]:
                    depth += l.count("{") - l.count("}")
                    block.append(l)
                    if depth <= 0:
                        break
                self.assertTrue(any("textFormat: Text.PlainText" in b for b in block),
                                "%s:%d Text without textFormat: Text.PlainText" % (name, i + 1))


if __name__ == "__main__":
    unittest.main(verbosity=2)
