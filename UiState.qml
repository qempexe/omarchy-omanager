import QtQuick
import "Model.js" as Model

// All of Omanager's window state, kept in its own item (not in Panel) so none of
// these names can collide with members of the shell's Panel base type.
// Children read it as `ui.*`: theme colors, spacing helpers, filter state and
// the computed results.
Item {
    id: root

    visible: false

    property var service: null
    property var store: null
    property var cfg: null          // resolved settings, from BarWidget.qml
    property bool opened: false

    property bool popped: false     // true while the manager lives in its own window

    signal searchCleared()
    signal focusSearch()
    signal popOutRequested()
    signal dockRequested()
    signal closeRequested()

    // ---- theme & spacing helpers (used by every child as ui.*) ----------------
    readonly property var cfgSafe: cfg ? cfg : ({
        colorMode: "theme", accentColor: "#ff6a1f", cardStyle: "soft", density: "comfortable",
        cornerRadius: 4, fontScale: 100, surfaceTint: 6, showPreviews: true, frame: true, openAs: "panel",
        windowWidth: 1040, windowHeight: 700, viewMode: "split", columns: "auto", filtersPanel: "left",
        defaultSource: "community", defaultSort: "newest", recencyScope: "either", recencyDays: "any",
        verifiedOnly: false, hideInstalled: false, showCounts: true, newBadgeDays: 14,
        confirmInstall: true, confirmRemove: true, allowUnverified: true, showSecurityNote: true
    })

    // Colours handed in by BarWidget: the bar's own foreground and background.
    property color barFg: "white"
    property color barBg: "#121217"

    function lumOf(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
    // Black or white, whichever reads better on colour c.
    function contrast(c) {
        return lumOf(c) > 0.5 ? Qt.rgba(0.08, 0.08, 0.08, 1) : Qt.rgba(0.96, 0.96, 0.96, 1)
    }
    function grey(l) { return Qt.rgba(l, l, l, 1) }

    // The opaque base every surface paints. It is the bar's real background, so the
    // bar panel and the pop-out window show the same colour (it used to be a neutral
    // grey derived from the foreground, which is why the two looked different).
    // Monochrome drops every hue: the surface becomes a grey at the bar's brightness.
    readonly property color barSurface: Qt.rgba(barBg.r, barBg.g, barBg.b, 1)
    readonly property color surface: mono ? grey(lumOf(barSurface)) : barSurface
    readonly property bool lightSurface: lumOf(surface) > 0.5
    // Text has to read against the surface. If the bar's foreground is too close to
    // its background, fall back to black or white.
    // Monochrome text is pure white or black, never a tinted foreground.
    readonly property color fg: mono ? contrast(surface)
        : (Math.abs(lumOf(barFg) - lumOf(surface)) >= 0.35 ? barFg : contrast(surface))
    readonly property real lum: lumOf(fg)
    readonly property bool lightText: lum > 0.5
    // The layout (List + stage / Cards / List) is live UI state: it changes the
    // instant it is chosen, and is saved right after. It never waits on the
    // settings file, `omarchy bar set` or the settings object being rebuilt.
    property string viewOverride: ""
    readonly property string viewMode: viewOverride !== "" ? viewOverride : cfgSafe.viewMode
    function setView(mode) {
        viewOverride = mode
        Qt.callLater(function() { if (root.store) root.store.set("viewMode", mode) })
    }
    onCfgSafeChanged: if (viewOverride !== "" && cfgSafe.viewMode === viewOverride) viewOverride = ""

    readonly property bool mono: cfgSafe.colorMode === "mono"
    readonly property color accent: cfgSafe.colorMode === "custom"
        ? Qt.color(Model.validHex(cfgSafe.accentColor, "#ff6a1f")) : fg
    readonly property real accLum: 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b
    readonly property color accentText: contrast(accent)
    // Status colours: the pastels used on dark bars vanish on light ones, so pick
    // darker variants for light surfaces. Monochrome removes hues altogether.
    readonly property color good: mono ? fg
        : (lightSurface ? Qt.rgba(0.14, 0.50, 0.26, 1) : Qt.rgba(0.48, 0.85, 0.56, 1))
    readonly property color warn: mono ? fg
        : (lightSurface ? Qt.rgba(0.62, 0.40, 0.02, 1) : Qt.rgba(0.94, 0.71, 0.30, 1))
    readonly property color bad: mono ? fg
        : (lightSurface ? Qt.rgba(0.74, 0.16, 0.26, 1) : Qt.rgba(0.97, 0.46, 0.56, 1))
    readonly property color warnText: contrast(warn)
    property string fontName: ""
    readonly property string cardStyle: cfgSafe.cardStyle
    readonly property real radius: cfgSafe.cornerRadius
    readonly property bool animations: true

    function tint(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }

    // Label colour for text on an "on" chip or tab filled with colour `c` (the fill is
    // c at 22% over the surface). Works for any accent, light or dark.
    function onFill(c) {
        return Qt.rgba(surface.r * 0.78 + c.r * 0.22, surface.g * 0.78 + c.g * 0.22,
                       surface.b * 0.78 + c.b * 0.22, 1)
    }
    function onText(c) { return contrast(onFill(c)) }
    function accentTint(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
    function fs(n) { return Math.round(n * cfgSafe.fontScale / 100) }
    function px(n) {
        var f = cfgSafe.density === "compact" ? 0.85 : (cfgSafe.density === "spacious" ? 1.2 : 1.0)
        return Math.round(n * f)
    }
    // Category color: hue per category in "By category" mode, otherwise the accent.
    function tone(category) {
        if (cfgSafe.colorMode === "category")
            return Qt.hsla(Model.hueOf(category), 0.55, lightSurface ? 0.38 : 0.68, 1)
        return accent
    }

    // ---- filter state ----------------------------------------------------------
    property string tabName: "browse"        // browse | installed | updates | saved | settings
    property string query: ""
    property string source: "community"
    property string category: ""
    property var tags: []
    property bool verifiedOnly: false
    property bool hideInstalled: false
    property string status: "any"
    property string scope: "either"
    property int days: 0
    property string sortKey: "newest"
    property var selected: null              // plugin shown in the detail pane
    property var confirm: null               // { kind, p } waiting for a yes
    property bool showLog: false
    property real now: Date.now()
    property bool seeded: false

    readonly property var sortOptions: [
        { key: "newest", label: "Newly uploaded" },
        { key: "listed", label: "As listed" },
        { key: "updated", label: "Recently upgraded" },
        { key: "fresh", label: "New or upgraded" },
        { key: "hearts", label: "Most hearts" },
        { key: "stars", label: "Most stars" },
        { key: "views", label: "Most viewed" },
        { key: "rated", label: "Best install rate" },
        { key: "az", label: "A to Z" }
    ]

    function resetFilters() {
        var c = cfgSafe
        query = ""
        searchCleared()
        source = c.defaultSource
        category = ""
        tags = []
        verifiedOnly = c.verifiedOnly
        hideInstalled = c.hideInstalled
        status = "any"
        scope = c.recencyScope
        days = c.recencyDays === "any" ? 0 : Number(c.recencyDays)
        sortKey = c.defaultSort
    }

    readonly property bool filtersActive: query !== "" || category !== "" || tags.length > 0
        || status !== "any" || days !== 0 || verifiedOnly || hideInstalled
        || sortKey !== cfgSafe.defaultSort || (days !== 0 && scope !== cfgSafe.recencyScope)
        || (tabName === "browse" && source !== cfgSafe.defaultSource)

    onCfgChanged: if (cfg && !seeded) { seeded = true; resetFilters() }
    onTabNameChanged: {
        status = "any"; category = ""; tags = []; selected = null
        recomputeTimer.restart()
    }

    // ---- results ---------------------------------------------------------------------
    property var items: []
    property var facets: ({ categories: [], tags: [] })
    property int poolSize: 0

    function recompute() {
        if (!service) { items = []; return }
        var t = tabName
        if (t === "settings") return
        var o = {
            query: query, source: source, category: category, tags: tags,
            verifiedOnly: verifiedOnly, hideInstalled: hideInstalled, status: status,
            scope: scope, days: days, sort: sortKey, now: now, since: service.prevVisit,
            bookmarks: service.bookmarks, updateSet: updateSet
        }
        if (t === "installed") {
            o.source = "all"; o.hideInstalled = false
            o.status = (status === "enabled" || status === "disabled") ? status : "installed"
        } else if (t === "updates") {
            o.source = "all"; o.hideInstalled = false; o.status = "updates"
        } else if (t === "saved") {
            o.source = "all"; o.hideInstalled = false; o.status = "saved"
        }
        var r = Model.query(service.catalog, service.installed, service.installedMap, o)
        items = r.items
        facets = r.facets
        poolSize = r.poolSize
    }

    readonly property var updateSet: {
        var m = ({})
        var ids = service ? service.updateIds : []
        for (var i = 0; i < ids.length; i++) m[ids[i]] = true
        return m
    }

    Timer { id: recomputeTimer; interval: 70; onTriggered: root.recompute() }
    Timer { interval: 60000; repeat: true; running: root.opened; onTriggered: root.now = Date.now() }

    onQueryChanged: recomputeTimer.restart()
    onSourceChanged: recomputeTimer.restart()
    onCategoryChanged: recomputeTimer.restart()
    onTagsChanged: recomputeTimer.restart()
    onVerifiedOnlyChanged: recomputeTimer.restart()
    onHideInstalledChanged: recomputeTimer.restart()
    onStatusChanged: recomputeTimer.restart()
    onScopeChanged: recomputeTimer.restart()
    onDaysChanged: recomputeTimer.restart()
    onSortKeyChanged: recomputeTimer.restart()
    onUpdateSetChanged: recomputeTimer.restart()
    onServiceChanged: recomputeTimer.restart()

    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onCatalogChanged() { recomputeTimer.restart() }
        function onInstalledMapChanged() { recomputeTimer.restart() }
        function onBookmarksChanged() { recomputeTimer.restart() }
    }

    // ---- item state / actions ---------------------------------------------------------
    function stateOf(p) {
        var inst = service ? service.installedMap[p.id] : null
        return {
            installed: !!inst,
            enabled: !!inst && inst.enabled,
            update: !!updateSet[p.id],
            version: inst ? inst.version : ""
        }
    }

    function openDetail(p) { selected = p }

    function requestAction(kind, p) {
        if (!service) return
        if (kind === "install" && !cfgSafe.allowUnverified && !p.verified) {
            service.note("Blocked: " + p.name + " is not verified (see Settings \u203A Safety)", false)
            return
        }
        var ask = ((kind === "install" || kind === "update") && cfgSafe.confirmInstall)
               || (kind === "remove" && cfgSafe.confirmRemove)
        if (ask) { confirm = { kind: kind, p: p }; return }
        runAction(kind, p)
    }

    function runAction(kind, p) {
        service.perform(kind, p.id, p.name, p.repo)
    }

    // What the stage (big pane in "List + stage" layout) shows: the selection, else the top result.
    readonly property var stageItem: selected !== null ? selected : (items.length > 0 ? items[0] : null)

    // ---- empty states -----------------------------------------------------------------------
    readonly property string emptyTitle: {
        if (!service) return "Starting\u2026"
        if (service.catalogState === "loading" && service.catalog.length === 0) return "Loading the plugin catalog\u2026"
        if (service.catalogState === "error" && service.catalog.length === 0) return "Couldn't load the catalog"
        if (tabName === "updates") return "Everything is up to date"
        if (tabName === "saved") return "Nothing saved yet"
        if (tabName === "installed") return filtersActive ? "No installed plugin matches" : "No plugins installed"
        return "No plugins match"
    }
    readonly property string emptyHint: {
        if (!service) return ""
        if (service.catalogState === "error" && service.catalog.length === 0) return service.catalogError
        if (tabName === "saved") return "Tap the star on a plugin to keep it here."
        if (tabName === "updates") return "Updates appear when the catalog has a newer version than the one you installed."
        return ""
    }


    onOpenedChanged: {
        if (opened) {
            now = Date.now()
            if (service) {
                service.prevVisit = service.lastSeen
                service.refreshInstalled()
                service.refresh(cfgSafe.refreshOnOpen === true)
            }
            recomputeTimer.restart()
            Qt.callLater(function() { if (root.tabName !== "settings") root.focusSearch() })
        } else {
            selected = null
            confirm = null
            showLog = false
            if (service) service.markSeen()
        }
    }
}
