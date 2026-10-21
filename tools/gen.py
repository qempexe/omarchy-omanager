#!/usr/bin/python3
"""Single source of truth for Omanager's settings.

Edit SPEC below, then run:  python3 tools/gen.py
It rewrites manifest.json, Schema.js (the in-window settings UI) and the
generated block inside BarWidget.qml, so they can never drift apart.
"""
import json, os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PLUGIN_ID = "io.github.qempexe.omanager"

# control (enum only) picks how the settings window draws a choice:
#   "scheme" a tile per color scheme, with a tiny window drawn in its colors
#   "tiles"  big tiles with a little picture of each option (few, visual choices)
#   "seg"    one segmented bar (short choices, up to about 5)
#   "chips"  wrapping chips (long lists)
# Left out, it is "seg" for up to 5 options and "chips" for more.
def E(key, label, default, options, labels, hint, when=None, control=None):
    return dict(key=key, label=label, kind="enum", fallback=default, options=options,
                labels=labels, hint=hint, when=when, control=control)

def I(key, label, default, lo, hi, step, hint, divisor=1, decimals=0, when=None):
    return dict(key=key, label=label, kind="int", fallback=default, min=lo, max=hi,
                step=step, divisor=divisor, decimals=decimals, hint=hint, when=when)

def B(key, label, default, hint, when=None):
    return dict(key=key, label=label, kind="bool", fallback=default, hint=hint, when=when)

def S(key, label, default, hint, presets=None, kind="string", when=None, maxLength=None):
    return dict(key=key, label=label, kind=kind, fallback=default, hint=hint,
                presets=presets or [], when=when, maxLength=maxLength)

# A row of colors edited together (pick one, then a swatch or a hex). Each target is
# its own setting in manifest.json and BarWidget.qml: (key, label, default).
def P(key, label, targets, hint, presets, when=None):
    return dict(key=key, label=label, kind="palette", hint=hint, presets=presets, when=when,
                fallback={k: d for k, _, d in targets},
                targets=[{"key": k, "label": l} for k, l, _ in targets])

# Puts a small heading over a run of rows in the settings window.
def sec(title, items):
    return [dict(it, section=title) for it in items]

SWATCHES = ["#141414", "#1d1510", "#1a1b26", "#282a36", "#2e3440", "#2d353b", "#1f1f28", "#3b2a1f",
            "#e0e0e0", "#eadbc8", "#ffffff", "#c0caf5", "#d8dee9", "#dcd7ba", "#f8f8f2", "#e0def4",
            "#d4a35a", "#c8925a", "#7aa2f7", "#cba6f7", "#a7c080", "#88c0d0", "#fabd2f", "#ff6a1f"]

SORTS = ["newest", "listed", "updated", "fresh", "hearts", "stars", "views", "copies", "rank", "rated", "az", "kind"]
SORT_LABELS = {"newest": "Newly uploaded", "listed": "As listed",
               "updated": "Recently upgraded", "fresh": "New or upgraded",
               "hearts": "Most hearts", "stars": "Most stars", "views": "Most viewed",
               "copies": "Most copied", "rank": "Top ranked",
               "rated": "Best install rate", "az": "A to Z", "kind": "Plugin type"}

SPEC = [
  ("Colors", sec("Scheme", [
    E("colorMode", "Colors", "theme", ["theme", "palette", "borders", "custom", "monochrome"],
      {"theme": "Follow theme", "palette": "Theme palette", "borders": "Window borders",
       "custom": "Custom", "monochrome": "Monochrome"},
      "Follow theme matches your Omarchy theme live. Theme palette gives every category its own color from the theme. "
      "Window borders takes the colors of your theme's window border, gradient and all. "
      "Custom lets you choose the background, text and accent. Monochrome removes every hue.", control="scheme"),
    P("customColors", "Custom colors",
      [("customBg", "Background", "#141414"), ("customFg", "Text", "#e0e0e0"), ("accentColor", "Accent", "#ff6a1f")],
      "Background and accent color the window. Text colors it too, and anywhere when Text is set to My text color.",
      SWATCHES, when=[{"key": "colorMode", "is": ["custom"]}]),
  ]) + sec("Text", [
    E("textColor", "Text", "auto", ["auto", "theme", "custom"],
      {"auto": "Always readable", "theme": "Theme", "custom": "My text color"},
      "Always readable keeps your theme's text color, and switches to black or white when the window is too light or too dark for it. "
      "My text color uses the Text color from Custom colors."),
  ])),
  ("Appearance", [
    E("cardStyle", "Card style", "soft", ["soft", "outline", "flat"],
      {"soft": "Soft", "outline": "Outline", "flat": "Flat"},
      "Soft fills cards lightly, outline draws a border only, flat has neither.", control="tiles"),
    E("density", "Spacing", "comfortable", ["compact", "comfortable", "spacious"],
      {"compact": "Compact", "comfortable": "Comfortable", "spacious": "Spacious"},
      "How much air there is between things.", control="tiles"),
    I("cornerRadius", "Roundness", 4, 0, 20, 2, "0 is square, 20 is very round."),
    I("fontScale", "Text size", 100, 80, 150, 5, "1 is normal, 1.25 is a quarter bigger.", divisor=100, decimals=2),
    B("showPreviews", "Show screenshots", True,
      "Loads preview images from plugins.omarchy.org. Turn off to stay fully offline for images."),
  ]),
  ("Window", sec("Size", [
    I("windowWidth", "Window width", 560, 400, 1600, 20, "How wide the manager opens. From about 720 it also gets the filter sidebar and the List + stage layout."),
    I("windowHeight", "Window height", 680, 420, 1100, 20, "How tall the manager opens."),
  ]) + sec("Layout", [
    E("openAs", "Open as", "panel", ["panel", "window"], {"panel": "Bar panel", "window": "Own window"},
      "Where the bar button opens the manager. You can always pop it out or dock it back from the header.", control="tiles"),
    E("viewMode", "Layout", "list", ["split", "grid", "list", "compact"],
      {"split": "List + stage", "grid": "Cards", "list": "List", "compact": "Compact"},
      "List + stage keeps a big preview of the selected plugin beside the list (wide windows only). Cards show screenshots, list fits the most, compact is a dense table-like view.", control="tiles"),
    E("columns", "Card columns", "auto", ["auto", "1", "2", "3", "4"],
      {"auto": "Auto", "1": "1", "2": "2", "3": "3", "4": "4"},
      "Auto fits as many as the window allows.", when=[{"key": "viewMode", "is": ["grid"]}]),
    E("filtersPanel", "Filters sidebar", "left", ["left", "hidden"], {"left": "Shown", "hidden": "Hidden"},
      "Hide it for a cleaner look. Search still works. In a narrow window the filters open from a Filters button instead."),
  ]) + sec("Look", [
    B("frame", "Window outline", False, "Draw the window edge in color instead of a plain neutral line."),
    B("frameGradient", "Outline gradient", True,
      "When your theme's window border is a gradient, the outline runs through all its colors, at the same angle.",
      when=[{"key": "frame", "is": ["true"]}]),
    E("frameColor", "Outline color", "accent", ["accent", "first", "middle", "last"],
      {"accent": "Accent", "first": "Border's first", "middle": "Border's middle", "last": "Border's last"},
      "The one color of the outline when it isn't a gradient. The border colors come from your theme's window border, "
      "and fall back to the accent when it has none.", when=[{"key": "frame", "is": ["true"]}]),
    I("surfaceTint", "Window tint", 0, 0, 30, 1, "How much of the accent color washes over the window. 0 keeps it plain, like the other panels."),
    I("opacity", "Window opacity", 97, 50, 100, 1, "How solid the window background is. Lower lets your wallpaper show through."),
  ])),
  ("Browse", [
    E("defaultSource", "Start on", "community", ["community", "builtin", "all"],
      {"community": "Community", "builtin": "Built-in", "all": "Everything"},
      "Which plugins you see first when the window opens."),
    E("defaultSort", "Sort by", "newest", SORTS, SORT_LABELS,
      "Newly uploaded = first listed. As listed = the order the catalog feed returns them in. Recently upgraded = latest new version or push. "
      "Top ranked adds up the places by hearts, copies, views and stars, like the website.", control="chips"),
    E("recencyScope", "Recency filter looks at", "either", ["either", "added", "updated"],
      {"either": "Uploaded or upgraded", "added": "Uploaded", "updated": "Upgraded"},
      "Used together with the time window below.", when=[{"key": "recencyDays", "is": ["7", "30", "90", "365"]}]),
    E("recencyDays", "Only show from the last", "any", ["any", "7", "30", "90", "365"],
      {"any": "Any time", "7": "Week", "30": "Month", "90": "3 months", "365": "Year"},
      "Hide plugins that have not been uploaded or upgraded recently."),
    B("verifiedOnly", "Verified only", False, "Start on Verified in the Verification filter, which hides plugins without the badge."),
    B("hideInstalled", "Hide installed", False, "Keep plugins you already have out of Browse."),
    B("showCounts", "Show counts", True, "Numbers next to categories and tags."),
    I("newBadgeDays", "Call it New for", 14, 1, 60, 1, "Days a plugin keeps its New badge after upload."),
  ]),
  ("Catalog", [
    S("catalogUrl", "Catalog address", "https://plugins.omarchy.org/catalog.json",
      "Where the plugin list comes from. Must start with https://.", maxLength=100),
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
      presets=["Plugins", "Store", "Add-ons"], when=[{"key": "barDisplay", "is": ["text", "both"]}], maxLength=10),
    B("showBadge", "Update badge", True, "Show how many plugin updates are waiting next to the button."),
    E("middleClick", "Middle click", "refresh", ["refresh", "none"], {"refresh": "Refresh catalog", "none": "Nothing"},
      "What clicking the bar button with the middle mouse button does."),
  ]),
]

# The settings one by one: a palette row counts as its colors.
def expand(it):
    if it["kind"] != "palette":
        return [it]
    labels = {t["key"]: t["label"] for t in it["targets"]}
    return [dict(key=k, label="Custom " + labels[k].lower(), kind="color", fallback=d, hint=it["hint"], presets=it["presets"],
                 when=it.get("when"), maxLength=7) for k, d in it["fallback"].items()]

ITEMS = [dict(x, group=g) for g, items in SPEC for it in items for x in expand(it)]

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
      "schemaVersion": 1, "id": PLUGIN_ID, "name": "Omanager", "version": "1.5.0",
      "author": "qempexe", "license": "MIT",
      "description": "Plugin manager for the Omarchy bar: browse, filter, install, update and remove plugins from a window.",
      "kinds": ["service", "bar-widget"], "keepLoaded": True,
      "entryPoints": {"service": "qml/Service.qml", "barWidget": "qml/BarWidget.qml"},
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
    with open(os.path.join(ROOT, "qml/js/Schema.js"), "w") as fh:
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
    path = os.path.join(ROOT, "qml/BarWidget.qml")
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
    if os.path.exists(os.path.join(ROOT, "qml/BarWidget.qml")): write_bar()
    print("settings:", len(ITEMS))
