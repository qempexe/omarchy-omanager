#!/usr/bin/python3
"""Single source of truth for Omanager's settings.

Edit SPEC below, then run:  python3 tools/gen.py
It rewrites manifest.json, Schema.js (the in-window settings UI) and the
generated block inside BarWidget.qml, so they can never drift apart.
"""
import json, os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PLUGIN_ID = "io.github.qempexe.omanager"

def E(key, label, default, options, labels, hint, when=None):
    return dict(key=key, label=label, kind="enum", fallback=default, options=options,
                labels=labels, hint=hint, when=when)

def I(key, label, default, lo, hi, step, hint, divisor=1, decimals=0, when=None):
    return dict(key=key, label=label, kind="int", fallback=default, min=lo, max=hi,
                step=step, divisor=divisor, decimals=decimals, hint=hint, when=when)

def B(key, label, default, hint, when=None):
    return dict(key=key, label=label, kind="bool", fallback=default, hint=hint, when=when)

def S(key, label, default, hint, presets=None, kind="string", when=None):
    return dict(key=key, label=label, kind=kind, fallback=default, hint=hint,
                presets=presets or [], when=when)

SORTS = ["newest", "updated", "fresh", "hearts", "stars", "views", "rated", "az"]
SORT_LABELS = {"newest": "Newly uploaded", "updated": "Recently upgraded",
               "fresh": "New or upgraded", "hearts": "Most hearts", "stars": "Most stars",
               "views": "Most viewed", "rated": "Best install rate", "az": "A to Z"}

SPEC = [
  ("Appearance", [
    E("colorMode", "Colors", "theme", ["theme", "custom", "mono", "category"],
      {"theme": "Follow theme", "custom": "My color", "mono": "Monochrome", "category": "By category"},
      "Follow theme matches your bar. My color uses the accent below. Monochrome removes every hue. By category tints each category differently."),
    S("accentColor", "My accent color", "#ff6a1f",
      "Pick one, or type a hex like #ff6a1f.",
      presets=["#ff6a1f", "#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#e0af68", "#f7768e", "#c0caf5"],
      kind="color", when=[{"key": "colorMode", "is": ["custom"]}]),
    E("cardStyle", "Card style", "soft", ["soft", "outline", "flat"],
      {"soft": "Soft", "outline": "Outline", "flat": "Flat"},
      "Soft fills cards lightly, outline draws a border only, flat has neither."),
    E("density", "Spacing", "comfortable", ["compact", "comfortable", "spacious"],
      {"compact": "Compact", "comfortable": "Comfortable", "spacious": "Spacious"},
      "How much air there is between things."),
    I("cornerRadius", "Roundness", 4, 0, 20, 2, "0 is square, 20 is very round."),
    B("frame", "Window outline", True, "A thin accent-colored outline around the whole manager."),
    I("fontScale", "Text size", 100, 80, 150, 5, "1 is normal, 1.25 is a quarter bigger.", divisor=100, decimals=2),
    I("surfaceTint", "Window tint", 6, 0, 30, 1, "How much of the accent color washes over the window."),
    B("showPreviews", "Show screenshots", True,
      "Loads preview images from plugins.omarchy.org. Turn off to stay fully offline for images."),
  ]),
  ("Window", [
    I("windowWidth", "Window width", 1040, 640, 1600, 20, "How wide the manager opens."),
    I("windowHeight", "Window height", 700, 420, 1100, 20, "How tall the manager opens."),
    E("openAs", "Open as", "panel", ["panel", "window"], {"panel": "Bar panel", "window": "Own window"},
      "Where the bar button opens the manager. You can always pop it out or dock it back from the header."),
    E("viewMode", "Layout", "split", ["split", "grid", "list"], {"split": "List + stage", "grid": "Cards", "list": "List"},
      "List + stage keeps a big preview of the selected plugin beside the list. Cards show screenshots, list fits the most."),
    E("columns", "Card columns", "auto", ["auto", "1", "2", "3", "4"],
      {"auto": "Auto", "1": "1", "2": "2", "3": "3", "4": "4"},
      "Auto fits as many as the window allows.", when=[{"key": "viewMode", "is": ["grid"]}]),
    E("filtersPanel", "Filters sidebar", "left", ["left", "hidden"], {"left": "Shown", "hidden": "Hidden"},
      "Hide it for a cleaner look. Search still works."),
  ]),
  ("Browse", [
    E("defaultSource", "Start on", "community", ["community", "builtin", "all"],
      {"community": "Community", "builtin": "Built-in", "all": "Everything"},
      "Which plugins you see first when the window opens."),
    E("defaultSort", "Sort by", "newest", SORTS, SORT_LABELS,
      "Newly uploaded = first listed. Recently upgraded = latest update. New or upgraded = whichever is most recent."),
    E("recencyScope", "Recency filter looks at", "either", ["either", "added", "updated"],
      {"either": "Uploaded or upgraded", "added": "Uploaded", "updated": "Upgraded"},
      "Used together with the time window below.", when=[{"key": "recencyDays", "is": ["7", "30", "90", "365"]}]),
    E("recencyDays", "Only show from the last", "any", ["any", "7", "30", "90", "365"],
      {"any": "Any time", "7": "Week", "30": "Month", "90": "3 months", "365": "Year"},
      "Hide plugins that have not been uploaded or upgraded recently."),
    B("verifiedOnly", "Verified only", False, "Hide plugins without the Verified badge."),
    B("hideInstalled", "Hide installed", False, "Keep plugins you already have out of Browse."),
    B("showCounts", "Show counts", True, "Numbers next to categories and tags."),
    I("newBadgeDays", "Call it New for", 14, 1, 60, 1, "Days a plugin keeps its New badge after upload."),
  ]),
  ("Catalog", [
    S("catalogUrl", "Catalog address", "https://plugins.omarchy.org/catalog.json",
      "Where the plugin list comes from. Must start with https://."),
    I("refreshHours", "Refresh every", 1, 1, 168, 1, "Hours between automatic checks. An unchanged catalog costs a tiny request, not a full download."),
    B("refreshOnOpen", "Refresh when opened", True, "Check for a newer catalog every time the window opens. Cheap when nothing changed."),
    B("checkUpdates", "Look for updates", True, "Compare installed versions with the catalog and show an Updates tab."),
  ]),
  ("Safety", [
    B("confirmInstall", "Ask before installing", True, "Plugins run as unsandboxed code in your shell, so a confirmation is shown first."),
    B("confirmRemove", "Ask before removing", True, "Confirm before a plugin is removed."),
    B("allowUnverified", "Allow unverified plugins", True, "Off blocks install buttons for anything without the Verified badge."),
    B("enableAfterInstall", "Enable after install", True, "Turn a plugin on as soon as it is installed."),
    B("showSecurityNote", "Show the security note", True, "A short reminder in the plugin details."),
  ]),
  ("Bar", [
    E("barDisplay", "Bar button shows", "both", ["icon", "text", "both"],
      {"icon": "Icon", "text": "Text", "both": "Both"}, "What the button on the bar looks like."),
    S("barText", "Bar button text", "Plugins", "Used when text is shown.",
      presets=["Plugins", "Store", "Add-ons"], when=[{"key": "barDisplay", "is": ["text", "both"]}]),
    B("showBadge", "Update badge", True, "Show how many plugin updates are waiting next to the button."),
    E("middleClick", "Middle click", "refresh", ["refresh", "none"], {"refresh": "Refresh catalog", "none": "Nothing"},
      "What clicking the bar button with the middle mouse button does."),
  ]),
]

ITEMS = [dict(it, group=g) for g, items in SPEC for it in items]

def manifest_item(it):
    t = {"enum": "enum", "int": "integer", "bool": "boolean", "string": "string", "color": "string"}[it["kind"]]
    d = {"key": it["key"], "type": t, "label": it["label"]}
    if it["kind"] == "enum": d["options"] = it["options"]
    if it["kind"] == "int":
        d.update(min=it["min"], max=it["max"], step=it["step"])
    d["defaultValue"] = it["fallback"]
    d["description"] = it["hint"]
    return d

def write_manifest():
    m = {
      "schemaVersion": 1, "id": PLUGIN_ID, "name": "Omanager", "version": "1.0.0",
      "author": "qempexe", "license": "MIT",
      "description": "Plugin manager for the Omarchy bar: browse, filter, install, update and remove plugins from a window.",
      "kinds": ["service", "bar-widget"], "keepLoaded": True,
      "entryPoints": {"service": "Service.qml", "barWidget": "BarWidget.qml"},
      "barWidget": {
        "displayName": "Omanager",
        "description": "Browse, filter, install and update Omarchy plugins",
        "category": "System",
        "aliases": ["plugins", "store", "manager", "marketplace", "installer"],
        "allowMultiple": False, "defaultSection": "right",
        "defaults": {it["key"]: it["fallback"] for it in ITEMS},
        "schema": [manifest_item(it) for it in ITEMS],
      },
    }
    with open(os.path.join(ROOT, "manifest.json"), "w") as fh:
        json.dump(m, fh, indent=2); fh.write("\n")

def write_schema():
    groups = []
    for g, items in SPEC:
        groups.append({"title": g, "items": [{k: v for k, v in it.items() if v is not None} for it in items]})
    with open(os.path.join(ROOT, "Schema.js"), "w") as fh:
        fh.write(".pragma library\n\n// Generated by tools/gen.py. Do not edit by hand.\n")
        fh.write("var groups = " + json.dumps(groups, indent=2) + ";\n\n")
        fh.write("var defaults = " + json.dumps({it["key"]: it["fallback"] for it in ITEMS}, indent=2) + ";\n")

def qml_line(it):
    k, d = it["key"], json.dumps(it["fallback"])
    inner = 'over("%s", setting("%s", %s))' % (k, k, d)
    if it["kind"] == "enum":
        return '    readonly property string opt_%s: pick(%s, %s, %s)' % (k, inner, json.dumps(it["options"]), d)
    if it["kind"] == "int":
        return '    readonly property int opt_%s: whole(%s, %d, %d, %s)' % (k, inner, it["min"], it["max"], d)
    if it["kind"] == "bool":
        return '    readonly property bool opt_%s: flag(%s, %s)' % (k, inner, d)
    return '    readonly property string opt_%s: String(%s)' % (k, inner)

def write_bar():
    path = os.path.join(ROOT, "BarWidget.qml")
    src = open(path).read()
    lines = [qml_line(it) for it in ITEMS]
    cfg = ["    readonly property var cfg: ({"] + \
          ["        %s: opt_%s%s" % (it["key"], it["key"], "," if i < len(ITEMS) - 1 else "") for i, it in enumerate(ITEMS)] + \
          ["    })"]
    block = "    // BEGIN GENERATED SETTINGS (tools/gen.py)\n" + "\n".join(lines) + "\n\n" + "\n".join(cfg) + "\n    // END GENERATED SETTINGS"
    new = re.sub(r"    // BEGIN GENERATED SETTINGS.*?// END GENERATED SETTINGS", lambda m: block, src, flags=re.S)
    open(path, "w").write(new)

if __name__ == "__main__":
    write_manifest(); write_schema()
    if os.path.exists(os.path.join(ROOT, "BarWidget.qml")): write_bar()
    print("settings:", len(ITEMS))
