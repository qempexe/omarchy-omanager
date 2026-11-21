#!/usr/bin/python3
"""Checks manifest.json against the QML and Schema.js: no setting declared but unread, or read but undeclared."""
import json, os, re, sys, unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def qml_files():
    out = []
    for d, _, files in os.walk(os.path.join(ROOT, "qml")):
        out += [os.path.relpath(os.path.join(d, f), ROOT) for f in files if f.endswith(".qml")]
    return sorted(out)


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

    def test_batch_controls_in_active_plugin(self):
        """The live manifest must reach the UI with all three batch actions."""
        widget = self.m["entryPoints"]["barWidget"]
        view = os.path.join(os.path.dirname(widget), "panel", "ManagerView.qml")
        state = os.path.join(os.path.dirname(widget), "core", "UiState.qml")
        model = os.path.join(os.path.dirname(widget), "js", "Model.js")
        for name in (view, state, model):
            self.assertTrue(os.path.isfile(os.path.join(ROOT, name)), name)
        for label in ("Install selected", "Remove selected", "Update selected"):
            self.assertIn(label, read(view))
        self.assertIn("ui.requestBatch(ui.batchKind)", read(view))
        self.assertIn("function batchCandidates(", read(model))
        self.assertIn("Model.batchCandidates(", read(state))

    def test_selected_names_can_be_removed_in_active_plugin(self):
        widget = self.m["entryPoints"]["barWidget"]
        base = os.path.dirname(widget)
        view = read(os.path.join(base, "panel", "ManagerView.qml"))
        state = read(os.path.join(base, "core", "UiState.qml"))
        self.assertIn("model: ui.selectedPlugins", view)
        self.assertIn("text: chip.plugin.name", view)
        self.assertIn("onClicked: ui.unselect(chip.plugin.id)", view)
        self.assertIn("opacity: chipArea.containsMouse ? 1 : 0", view)
        self.assertIn("function unselect(id) { selection = Model.withoutSelection(selection, id) }", state)

    def test_selected_names_wrap_before_batch_buttons(self):
        widget = self.m["entryPoints"]["barWidget"]
        view = read(os.path.join(os.path.dirname(widget), "panel", "ManagerView.qml"))
        self.assertRegex(view, r"Flow\s*\{\s*id: selectedChips")
        self.assertNotIn("Flickable.HorizontalFlick", view)
        self.assertIn("Layout.alignment: Qt.AlignTop", view)

    def test_select_all_requires_confirmation(self):
        widget = self.m["entryPoints"]["barWidget"]
        base = os.path.dirname(widget)
        view = read(os.path.join(base, "panel", "ManagerView.qml"))
        state = read(os.path.join(base, "core", "UiState.qml"))
        self.assertRegex(view, r'text: "All";[^\n]*onClicked: ui\.requestSelectAll\(\)')
        self.assertIn('confirm = { kind: "selectAll", tab: tabName, list: visible.slice() }', state)
        self.assertIn('dlg.choosingAll ? "Select all " + dlg.n + " plugins in " + dlg.tabLabel', view)
        self.assertIn("onClicked: ui.confirm = null", view)
        self.assertIn('if (c.kind === "selectAll") ui.confirmSelectAll(c)', view)
        self.assertIn("selectAllVisible(visible)", state)

    def test_large_batch_is_bounded(self):
        base = os.path.dirname(self.m["entryPoints"]["barWidget"])
        view = read(os.path.join(base, "panel", "ManagerView.qml"))
        state = read(os.path.join(base, "core", "UiState.qml"))
        service = read(os.path.join(base, "Service.qml"))
        self.assertIn("model: ui.selectedPlugins.slice(0, 20)", view)
        self.assertIn("model: ui.selectedPlugins", view)
        self.assertIn("Layout.preferredHeight: Math.min(selectedChips.implicitHeight, ui.px(82))", view)
        self.assertIn("if (list.length > batchLimit)", state)
        self.assertIn("function cancelQueued()", service)
        self.assertIn("if (queue.length === 0) refreshInstalled()", service)

    def test_settings_drift(self):
        qml = read("qml/BarWidget.qml")
        used = set(re.findall(r'setting\("([A-Za-z0-9_]+)"', qml))
        schema = {s["key"] for s in self.bw["schema"]}
        self.assertEqual(used, schema)
        self.assertEqual(set(self.bw["defaults"]), schema)

    def test_defaults_match_schema_and_qml_fallbacks(self):
        qml = read("qml/BarWidget.qml")
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
        qml = read("qml/BarWidget.qml")
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
        schema_js = read("qml/js/Schema.js")
        groups = json.loads(re.search(r"var groups = (.*?);\n\nvar defaults", schema_js, re.S).group(1))
        items = {}
        for g in groups:
            for i in g["items"]:
                if i["kind"] == "palette":   # a row of colors: each one is its own setting
                    for t in i["targets"]:
                        items[t["key"]] = {"fallback": i["fallback"][t["key"]]}
                else:
                    items[i["key"]] = i
        self.assertEqual(set(items), {s["key"] for s in self.bw["schema"]})
        for s in self.bw["schema"]:
            self.assertEqual(items[s["key"]]["fallback"], s["defaultValue"], s["key"])

    def test_no_duplicate_signal_handlers(self):
        """QML refuses to load a component that defines the same on<X>Changed twice."""
        for name in qml_files():
            # top-level handlers only (4-space indent) so nested objects don't collide
            found = re.findall(r"^    (on[A-Z]\w*):", read(name), re.M)
            dupes = {h for h in found if found.count(h) > 1}
            self.assertFalse(dupes, "%s defines %s twice" % (name, sorted(dupes)))

    def test_no_shell_strings_or_eval(self):
        """Commands must be argument arrays; nothing should go through sh -c."""
        for name in ("qml/Service.qml", "qml/js/Model.js"):
            code = read(name)
            # git's own `-c name=value` is fine; a bare "-c" would be a shell's
            self.assertNotRegex(code, r'"sh"|"bash"|"-c"\s*,\s*"[^"=]*"|\beval\(|new Function')

    def test_no_native_editable_text_input(self):
        """Qt's TextInput / TextEdit / TextField carry their own clipboard handling, which
        reads foreign clipboard text with no byte or time limit. Text fields must use
        PasteInput, which is built from a plain Text and never touches the clipboard."""
        for name in qml_files():
            for i, line in enumerate(read(name).split("\n")):
                if re.match(r"^\s*(?:[\w.]+:\s*)?(TextInput|TextEdit|TextField)\s*\{", line):
                    self.fail("%s:%d uses a native editable text item; use PasteInput" % (name, i + 1))

    def test_every_text_item_is_plain_text(self):
        """MPRIS metadata is attacker-controlled: Text.AutoText would render
        <img src=...> and fetch remote URLs. Every Text item must pin PlainText."""
        for name in qml_files():
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
