import QtQuick
import "../js/Model.js" as Model

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
        cornerRadius: 4, fontScale: 100, surfaceTint: 0, showPreviews: true, frame: false, openAs: "panel",
        windowWidth: 560, windowHeight: 680, viewMode: "list", columns: "auto", filtersPanel: "left",
        defaultSource: "community", defaultSort: "newest", recencyScope: "either", recencyDays: "any",
        verifiedOnly: false, hideInstalled: false, showCounts: true, newBadgeDays: 14,
        confirmInstall: true, confirmRemove: true, allowUnverified: true, showSecurityNote: true
    })

    // Narrow scalars for the delegates (cards, stage, filters). A delegate that reads
    // `ui.cfgSafe.X` depends on the whole settings object, which is rebuilt on every
    // change, so every card re-evaluated when any setting changed. These only change
    // when their own value changes, so an unrelated setting no longer touches them.
    readonly property real densityF: cfgSafe.density === "compact" ? 0.85 : (cfgSafe.density === "spacious" ? 1.2 : 1.0)
    readonly property real fontPct: cfgSafe.fontScale
    readonly property real tintPct: cfgSafe.surfaceTint
    readonly property bool frameOn: cfgSafe.frame === true
    readonly property bool showPreviews: cfgSafe.showPreviews === true
    readonly property int newBadgeDays: Number(cfgSafe.newBadgeDays)
    readonly property string colorModeKey: cfgSafe.colorMode
    readonly property string filtersPanelKey: cfgSafe.filtersPanel

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
    // The shell theme's own accent (BarWidget looks it up; transparent when the
    // shell does not expose one). "Follow theme" and "By category" use it for
    // selected tiles, tabs and sliders, so the window matches the rest of the shell.
    property color themeAccent: "transparent"
    readonly property bool hasThemeAccent: themeAccent.a > 0
    readonly property color accent: cfgSafe.colorMode === "custom"
        ? Qt.color(Model.validHex(cfgSafe.accentColor, "#ff6a1f"))
        : (!mono && hasThemeAccent ? Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 1) : fg)
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
    // Corner radius for a surface, as a multiple of the Roundness setting:
    // 1.5 buttons and chips, 2 plugin cards, 2.5 cards, 3 the window itself.
    // Roundness 0 stays square; the cap keeps very round settings sensible.
    function r(k) { return Math.min(24, Math.round(radius * k)) }
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
    // Type is drawn: 11 titles, 10 body, 8 to 9 hints.
    readonly property real baseScale: 0.82
    function fs(n) { return Math.max(7, Math.round(n * fontPct / 100 * baseScale)) }
    function px(n) {
        return Math.round(n * densityF)
    }
    // Category color: hue per category in "By category" mode, otherwise the accent.
    function tone(category) {
        if (colorModeKey === "category")
            return Qt.hsla(Model.hueOf(category), 0.55, lightSurface ? 0.38 : 0.68, 1)
        return accent
    }

    // ---- filter state ----------------------------------------------------------
    property string tabName: "browse"        // browse | installed | updates | saved | sets | settings
    property string query: ""
    property string settingsFilter: ""      // the header search while the Settings tab is open
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
    // The Installed tab can also order by when a plugin first landed on disk.
    // That is a fact about the local directory, not the catalog, so the option
    // lives only here; the other orders still apply.
    readonly property var installedSortOptions: [
        { key: "installed", label: "Newly installed" }
    ].concat(sortOptions)

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
        lastDefaults = defaultsNow()
    }

    // The Browse defaults from Settings. The filters start on them, and a filter that
    // still shows the old default follows a change to it. A filter the user has set
    // to something else stays where they put it.
    property var lastDefaults: ({})
    function defaultsNow() {
        var c = cfgSafe
        return { source: c.defaultSource, sort: c.defaultSort, scope: c.recencyScope,
                 days: c.recencyDays === "any" ? 0 : Number(c.recencyDays),
                 verified: c.verifiedOnly === true, hide: c.hideInstalled === true }
    }
    function syncDefaults() {
        var old = lastDefaults
        var now = defaultsNow()
        if (source === old.source) source = now.source
        if (sortKey === old.sort) sortKey = now.sort
        if (scope === old.scope) scope = now.scope
        if (days === old.days) days = now.days
        if (verifiedOnly === old.verified) verifiedOnly = now.verified
        if (hideInstalled === old.hide) hideInstalled = now.hide
        lastDefaults = now
    }

    readonly property bool filtersActive: query !== "" || category !== "" || tags.length > 0
        || status !== "any" || days !== 0 || verifiedOnly || hideInstalled
        || sortKey !== cfgSafe.defaultSort || (days !== 0 && scope !== cfgSafe.recencyScope)
        || (tabName === "browse" && source !== cfgSafe.defaultSource)

    onCfgChanged: {
        if (!cfg) return
        if (!seeded) { seeded = true; resetFilters() }
        else syncDefaults()
    }
    onTabNameChanged: {
        status = "any"; category = ""; tags = []; selected = null
        selectMode = false; selection = ({})
        if (tabName !== "installed" && sortKey === "installed") sortKey = cfgSafe.defaultSort
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
            bookmarks: service.bookmarks, updateSet: updateSet, healthSet: healthSet
        }
        if (t === "installed") {
            o.source = "all"; o.hideInstalled = false
            o.status = (status === "enabled" || status === "disabled" || status === "issues") ? status : "installed"
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

    // ---- health (Installed tab) ------------------------------------------------
    readonly property int healthCount: service ? service.healthCount : 0
    readonly property var healthSet: {
        var m = ({})
        var h = service ? service.health : []
        for (var i = 0; i < h.length; i++) m[h[i].id] = true
        return m
    }
    readonly property string healthSummary: {
        if (!service) return ""
        var c = {}
        var h = service.health
        for (var i = 0; i < h.length; i++) c[h[i].kind] = (c[h[i].kind] || 0) + 1
        var parts = []
        if (c.renamed) parts.push(c.renamed + " in a differently named folder")
        if (c.nogit) parts.push(c.nogit + " not git-managed")
        if (c.orphan) parts.push(c.orphan + " not in the catalog")
        if (c.nomanifest) parts.push(c.nomanifest + " without a manifest")
        return parts.join("  \u00b7  ")
    }
    function healthFor(p) { return service ? service.healthFor(p.id) : null }

    // ---- plugin sets (profiles) -------------------------------------------------
    readonly property var sets: service ? service.sets : []
    readonly property int setCount: sets.length
    function saveSet(name) { return service ? service.saveSet(name) : false }
    function restoreSet(i) { return service ? service.restoreSet(i) : 0 }
    function deleteSet(i) { if (service) service.deleteSet(i) }
    // How many plugins in a set are reinstatable (have a repo) — the rest only get
    // enabled if already present. Shown as a hint in the Sets tab.
    function setRepos(i) {
        var s = sets[i]
        if (!s || !s.plugins) return 0
        var n = 0
        for (var k = 0; k < s.plugins.length; k++) if (s.plugins[k].repo !== "") n++
        return n
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
    onHealthSetChanged: recomputeTimer.restart()
    onServiceChanged: recomputeTimer.restart()

    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onCatalogChanged() { recomputeTimer.restart() }
        function onInstalledMapChanged() { recomputeTimer.restart() }
        function onBookmarksChanged() { recomputeTimer.restart() }
        function onHealthChanged() { recomputeTimer.restart() }
    }

    // ---- item state / actions ---------------------------------------------------------
    function stateOf(p) {
        var inst = service ? service.installedMap[p.id] : null
        return {
            installed: !!inst,
            enabled: !!inst && inst.enabled,
            update: !!updateSet[p.id],
            version: inst ? inst.version : "",
            installedAt: inst ? (inst.installedAt || 0) : 0,
            dir: inst ? (inst.dir || "") : ""
        }
    }

    function openDetail(p) { selected = p }

    // ---- right-click context menu ----------------------------------------------
    // { p, x, y } in the window's own coordinates, or null when no menu is up.
    property var menu: null
    function openMenu(p, x, y) { menu = null; menu = { p: p, x: x, y: y } }
    function closeMenu() { menu = null }

    // ---- batch selection --------------------------------------------------------
    // id -> plugin, so a batch action knows each plugin's name and repo even after
    // the list is filtered. Selecting is a mode: cards show a checkbox and click
    // picks instead of opening.
    property bool selectMode: false
    property var selection: ({})
    readonly property int selCount: {
        var n = 0
        for (var k in selection) n++
        return n
    }
    function toggleSelect(p) {
        var s = {}
        for (var k in selection) s[k] = selection[k]
        if (s[p.id] !== undefined) delete s[p.id]
        else s[p.id] = p
        selection = s
    }
    function clearSelection() { selection = ({}) }
    function setSelectMode(on) { selectMode = on === true; if (!selectMode) clearSelection() }
    function selectAllVisible() {
        var s = {}
        for (var i = 0; i < items.length; i++) s[items[i].id] = items[i]
        selection = s
    }
    // The selected plugins that a given batch action actually applies to.
    function selectedFor(kind) {
        var out = []
        for (var id in selection) {
            var p = selection[id]
            var st = stateOf(p)
            if (kind === "enable" && st.installed && !st.enabled) out.push(p)
            else if (kind === "disable" && st.installed && st.enabled) out.push(p)
            else if (kind === "update" && st.update) out.push(p)
            else if (kind === "remove" && st.installed && !p.builtin) out.push(p)
            else if (kind === "install" && !st.installed && !p.builtin && p.repo !== "" && p.installable) out.push(p)
            else if (kind === "save" && !(service && service.bookmarks[p.id])) out.push(p)
        }
        return out
    }
    function requestBatch(kind) {
        var list = selectedFor(kind)
        if (list.length === 0) return
        var ask = (kind === "remove" && cfgSafe.confirmRemove)
               || ((kind === "install" || kind === "update") && cfgSafe.confirmInstall)
        if (ask) { confirm = { kind: kind, p: list[0], list: list }; return }
        runBatch(kind, list)
    }
    function runBatch(kind, list) {
        if (!service) return
        for (var i = 0; i < list.length; i++)
            service.perform(kind, list[i].id, list[i].name, list[i].repo)
        clearSelection()
    }

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
            menu = null
            selectMode = false
            selection = ({})
            showLog = false
            if (service) service.markSeen()
        }
    }
}
