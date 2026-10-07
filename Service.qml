import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Shared brain of Omanager (one instance for the whole shell).
//   * downloads and caches the plugin catalog (curl, https only)
//   * reads installed plugins from `omarchy plugin list --json`
//   * runs install / update / enable / disable / remove, one at a time,
//     as argument arrays (never through a shell)
//   * remembers bookmarks and the last visit
Item {
    id: root

    property var shell: null
    property var manifest: null

    readonly property string pluginId: "io.github.qempexe.omanager"

    property string stateDir: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/omarchy-omanager"
    readonly property string cachePath: stateDir + "/catalog.json"
    readonly property string statePath: stateDir + "/state.json"

    // ---- configuration pushed by the bar widget ---------------------------
    property var config: ({
        catalogUrl: "https://plugins.omarchy.org/catalog.json",
        refreshHours: 12, checkUpdates: true,
        enableAfterInstall: true
    })
    property bool started: false

    // ---- catalog ----------------------------------------------------------
    property var catalog: []
    property string catalogState: "idle"        // idle | loading | ready | stale | error
    property string catalogError: ""
    property real catalogTime: 0                // ms since epoch of the last good download

    // ---- installed --------------------------------------------------------
    property var installed: []
    property var installedMap: ({})
    property bool installedReady: false
    property var updateIds: []
    readonly property int updateCount: updateIds.length

    // ---- user state -------------------------------------------------------
    property var bookmarks: ({})
    property real lastSeen: 0                   // end of the previous visit
    property real prevVisit: 0                  // what "New since last visit" compares against

    // ---- activity ---------------------------------------------------------
    property var queue: []
    property var current: null
    property var busyIds: ({})                  // plugin id -> label of what it is doing
    property var log: []                        // newest last: { time, text, ok }
    readonly property bool busy: current !== null || queue.length > 0
    readonly property string busyLabel: current ? current.label : ""

    // ---- config / lifecycle -----------------------------------------------
    function configure(cfg) {
        var url = Model.safeCatalogUrl(cfg.catalogUrl)
        config = {
            catalogUrl: url !== "" ? url : "https://plugins.omarchy.org/catalog.json",
            refreshHours: Math.max(1, Number(cfg.refreshHours) || 12),
            checkUpdates: cfg.checkUpdates !== false,
            enableAfterInstall: cfg.enableAfterInstall !== false
        }
        recompute()
        if (!started) {
            started = true
            mkdir.running = true
            refreshInstalled()
        } else if (url !== "" && url !== lastUrl) {
            refresh(true)
        }
    }
    property string lastUrl: ""
    property bool haveCache: false
    property bool gotData: false
    property var stats: ({})

    function recompute() {
        updateIds = config.checkUpdates ? Model.findUpdates(catalog, installedMap) : []
    }
    onCatalogChanged: recompute()
    onInstalledMapChanged: recompute()

    function stale() {
        return catalogTime === 0 || (Date.now() - catalogTime) > config.refreshHours * 3600000
    }

    function note(text, ok) {
        var next = log.slice(-39)
        next.push({ time: Date.now(), text: String(text).slice(0, 400), ok: ok !== false })
        log = next
    }

    // ---- catalog download ---------------------------------------------------
    function refresh(force) {
        if (catalogState === "loading") return
        if (!force && !stale()) return
        var url = Model.safeCatalogUrl(config.catalogUrl)
        if (url === "") {
            catalogState = "error"
            catalogError = "The catalog address must start with https://"
            return
        }
        lastUrl = url
        catalogState = "loading"
        catalogError = ""
        gotData = false
        var args = ["curl", "-fsSL", "--compressed", "--max-time", "60", "--proto", "=https",
                    "-A", "omarchy-omanager"]
        // Conditional GET: when we already hold a copy, an unchanged catalog costs one 304.
        if (haveCache && catalog.length > 0) args = args.concat(["-z", cachePath])
        args.push(url)
        fetcher.command = args
        fetcher.running = true
    }

    function failFetch(msg) {
        catalogError = msg
        catalogState = catalog.length > 0 ? "stale" : "error"
        note("Catalog: " + msg, false)
    }

    function takeCatalog(text, fromCache) {
        var parsed
        try { parsed = JSON.parse(text) } catch (e) {
            if (!fromCache) failFetch("The download was not valid JSON")
            return false
        }
        var list = Model.normalizeCatalog(parsed)
        if (list.length === 0) {
            if (!fromCache) failFetch("Downloaded, but no plugins were recognised in it")
            return false
        }
        Model.applyStats(list, stats)
        catalog = list
        catalogState = "ready"
        catalogError = ""
        haveCache = true
        if (!fromCache) {
            gotData = true
            catalogTime = Date.now()
            cacheFile.setText(text)
            saveState()
            note("Catalog updated: " + list.length + " plugins")
        }
        fetchStats()
        return true
    }

    Process {
        id: fetcher
        running: false
        stdout: StdioCollector {
            id: fetchOut
            onStreamFinished: {
                if (root.catalogState !== "loading") return
                if (fetchOut.text && fetchOut.text.length > 2)
                    root.takeCatalog(fetchOut.text, false)
            }
        }
        onExited: function(code) {
            if (root.catalogState !== "loading") return
            if (code !== 0) root.failFetch("Download failed (curl exit " + code + "). Are you online?")
            else notModified.restart()      // exit 0 and no body: the 304 case
        }
    }

    // Exit 0 with nothing printed means the server said "not modified".
    Timer {
        id: notModified
        interval: 200
        onTriggered: {
            if (root.catalogState !== "loading" || root.gotData) return
            root.catalogState = "ready"
            root.catalogTime = Date.now()
            root.saveState()
            root.note("Catalog is already up to date")
            root.fetchStats()
        }
    }

    // ---- engagement stats (hearts / views / copies live in a separate API) ----
    function fetchStats() {
        if (statsFetcher.running) return
        statsFetcher.command = ["curl", "-fsSL", "--compressed", "--max-time", "30", "--proto", "=https",
                                "-A", "omarchy-omanager", Model.STATS_URL]
        statsFetcher.running = true
    }

    Process {
        id: statsFetcher
        running: false
        stdout: StdioCollector {
            id: statsOut
            onStreamFinished: {
                try {
                    var m = Model.normalizeStats(JSON.parse(statsOut.text))
                    if (Object.keys(m).length === 0) return
                    root.stats = m
                    if (Model.applyStats(root.catalog, m) > 0) root.catalog = root.catalog.slice()
                } catch (e) { /* decoration only: ignore */ }
            }
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: root.started
        onTriggered: if (root.stale()) root.refresh(false)
    }

    // ---- installed plugins ----------------------------------------------------
    function refreshInstalled() {
        if (lister.running) return
        lister.running = true
    }

    Process {
        id: lister
        command: ["omarchy", "plugin", "list", "--json"]
        running: false
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    var r = Model.normalizeInstalled(JSON.parse(listOut.text))
                    root.installed = r.list
                    root.installedMap = r.map
                    root.installedReady = true
                } catch (e) {
                    root.note("Could not read the installed plugin list", false)
                }
            }
        }
    }

    // ---- actions ----------------------------------------------------------------
    function perform(kind, id, name, repoUrl) {
        var built = Model.actionArgs(kind, id, repoUrl, config)
        if (!built) {
            note("Can't " + kind + " " + name + ": missing or unsafe " + (kind === "install" ? "repository address" : "plugin id"), false)
            return false
        }
        var verb = { install: "Installing", update: "Updating", enable: "Enabling",
                     disable: "Disabling", remove: "Removing" }[kind]
        var busy = {}
        for (var k in busyIds) busy[k] = busyIds[k]
        busy[id] = verb
        busyIds = busy
        var q = queue.slice()
        q.push({ kind: kind, id: id, name: name, label: verb + " " + name + "\u2026",
                 argv: built.argv, fallback: built.fallback, triedFallback: false })
        queue = q
        drain()
        return true
    }

    function drain() {
        if (current !== null || queue.length === 0) return
        current = queue[0]
        queue = queue.slice(1)
        actor.command = current.argv
        actor.running = true
    }

    function finishCurrent(ok, text) {
        var c = current
        note((ok ? "" : "Failed: ") + c.label.replace("\u2026", "") + (text ? " \u2014 " + text : ""), ok)
        var busy = {}
        for (var k in busyIds) if (k !== c.id) busy[k] = busyIds[k]
        busyIds = busy
        current = null
        refreshInstalled()
        drain()
    }

    Process {
        id: actor
        running: false
        stdout: StdioCollector { id: actorOut }
        stderr: StdioCollector { id: actorErr }
        onExited: function(code) {
            var c = root.current
            if (!c) return
            var out = (actorErr.text || actorOut.text || "").trim().split("\n").slice(-2).join(" ")
            if (code !== 0 && c.fallback && !c.triedFallback) {
                c.triedFallback = true
                actor.command = c.fallback
                actor.running = true
                return
            }
            root.finishCurrent(code === 0, code === 0 ? "" : out)
        }
    }

    // ---- clipboard / links ----------------------------------------------------------
    function copyText(text) {
        copier.command = ["wl-copy", String(text)]
        copier.running = true
        note("Copied to clipboard")
    }
    Process { id: copier; running: false }

    function openUrl(url) {
        var u = Model.safeWebUrl(url)
        if (u === "") return
        opener.command = ["xdg-open", u]
        opener.running = true
    }
    Process { id: opener; running: false }

    // ---- bookmarks / visits ------------------------------------------------------------
    function toggleBookmark(id) {
        var next = {}
        for (var k in bookmarks) next[k] = true
        if (next[id]) delete next[id]
        else next[id] = true
        bookmarks = next
        saveState()
    }

    function markSeen() {
        lastSeen = Date.now()
        saveState()
    }

    function saveState() {
        stateFile.setText(JSON.stringify({
            bookmarks: Object.keys(bookmarks), lastSeen: lastSeen, catalogTime: catalogTime
        }, null, 2) + "\n")
    }

    function readText(fv) {
        try { return String(typeof fv.text === "function" ? fv.text() : fv.text) } catch (e) { return "" }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.stateDir]
        onExited: { stateFile.reload(); cacheFile.reload() }
    }

    FileView {
        id: stateFile
        path: root.statePath
        onLoaded: {
            try {
                var s = JSON.parse(root.readText(stateFile))
                var b = {}
                var arr = Array.isArray(s.bookmarks) ? s.bookmarks : []
                for (var i = 0; i < arr.length; i++) b[String(arr[i])] = true
                root.bookmarks = b
                root.lastSeen = Number(s.lastSeen) || 0
                root.prevVisit = root.lastSeen
                if (root.catalogTime === 0) root.catalogTime = Number(s.catalogTime) || 0
            } catch (e) { }
        }
    }

    FileView {
        id: cacheFile
        path: root.cachePath
        onLoaded: {
            if (root.catalog.length === 0) root.takeCatalog(root.readText(cacheFile), true)
            root.refresh(false)
        }
        onLoadFailed: root.refresh(true)
    }

    IpcHandler {
        target: root.pluginId

        function refresh(): string { root.refresh(true); return "ok" }

        function status(): string {
            return JSON.stringify({
                catalogState: root.catalogState, catalogError: root.catalogError,
                catalogTime: root.catalogTime, plugins: root.catalog.length,
                installed: root.installed.length, updates: root.updateIds,
                busy: root.busy, queued: root.queue.length,
                lastLog: root.log.length ? root.log[root.log.length - 1] : null
            })
        }
    }
}
