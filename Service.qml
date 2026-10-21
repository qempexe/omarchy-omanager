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
    // The installed list and the versions on disk arrive from two different
    // processes; both end up folded into the same { list, map } pair.
    readonly property string pluginsDir: Quickshell.env("HOME") + "/.config/omarchy/plugins"
    property var installed: []
    property var installedMap: ({})
    property var installedBase: null            // last parse of `omarchy plugin list --json`
    property var installedScan: ({})            // plugin id -> { version, dir } from its manifest.json
    property var installedBirths: ({})          // plugin dir -> install time (ms), from stat
    property var gitDirs: ({})                  // plugin dir -> true, the ones that are git checkouts
    property int installedAttempts: 0           // retries while the shell is still coming up
    property bool installedReady: false
    property var updateIds: []
    readonly property int updateCount: updateIds.length

    // ---- user state -------------------------------------------------------
    property var bookmarks: ({})
    property real lastSeen: 0                   // end of the previous visit
    property real prevVisit: 0                  // what "New since last visit" compares against
    // Saved plugin sets (profiles): a named snapshot of the installed plugins,
    // each with the repo needed to reinstall it. Persisted with the bookmarks.
    property var sets: []

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

    // ---- health (Installed tab) -------------------------------------------
    readonly property var catalogIdSet: {
        var m = ({})
        for (var i = 0; i < catalog.length; i++) m[catalog[i].id] = true
        return m
    }
    readonly property var health: Model.healthOf(installed, installedBirths, gitDirs, catalogIdSet)
    readonly property int healthCount: health.length
    readonly property var healthMap: {
        var m = ({})
        for (var i = 0; i < health.length; i++) m[health[i].id] = health[i]
        return m
    }
    function healthFor(id) { return healthMap[id] || null }

    // `omarchy plugin list` has no version field, so an installed plugin's
    // version, directory and install time all come from a scan of its
    // manifest.json directory. The pieces land at different times, so every path
    // leads here and the window always sees one consistent pair.
    function assembleInstalled() {
        if (!installedBase) return
        var r = Model.applyScan(installedBase, installedScan, installedBirths)
        installed = r.list
        installedMap = r.map
        installedReady = true
    }
    onInstalledScanChanged: assembleInstalled()
    onInstalledBirthsChanged: assembleInstalled()

    // An empty scan while third-party plugins are installed means jq is gone or
    // the directory moved. Say it once, so "no updates" is never a mystery.
    property bool warnedNoVersions: false
    function warnNoVersions() {
        if (warnedNoVersions || !installedBase) return
        for (var i = 0; i < installedBase.list.length; i++) {
            if (installedBase.list[i].builtin) continue
            warnedNoVersions = true
            note("Could not read installed plugin versions (is jq installed?)", false)
            return
        }
    }

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
                var parsed = null
                try { parsed = JSON.parse(listOut.text) } catch (e) { parsed = null }
                var r = parsed ? Model.normalizeInstalled(parsed) : null
                if (!r || r.list.length === 0) {
                    // `omarchy plugin list` asks the shell over IPC, and the
                    // shell cannot answer for the first moment after a restart,
                    // while its own plugins are still loading. Retry briefly
                    // rather than showing an empty list and no updates.
                    if (root.installedAttempts < 5) {
                        root.installedAttempts++
                        installedRetry.restart()
                    } else {
                        root.note("Could not read the installed plugin list", false)
                    }
                    return
                }
                root.installedAttempts = 0
                root.installedBase = r
                root.assembleInstalled()
                versionScanner.running = true
                birthScanner.running = true
                gitScanner.running = true
            }
        }
    }

    Timer {
        id: installedRetry
        interval: 1000
        repeat: false
        onTriggered: lister.running = true
    }

    // Third-party plugins live in ~/.config/omarchy/plugins/<dir>/manifest.json.
    // The directory name is not always the plugin id, so the id is read from the
    // manifest itself: one `[id, version, path]` JSON array per plugin on stdout.
    // Hidden directories are clone staging areas and backups, never plugins. One
    // jq per manifest so a half-written file only costs its own line, and the
    // whole command stays an argument array like every other one here.
    Process {
        id: versionScanner
        running: false
        command: ["find", root.pluginsDir, "-mindepth", "2", "-maxdepth", "2",
                  "-name", "manifest.json", "-not", "-path", root.pluginsDir + "/.*",
                  "-exec", "jq", "--compact-output",
                  '[(.id // ""), (.version // ""), (input_filename), (.omarchy.clonedFrom // "")]', "{}", ";"]
        stdout: StdioCollector {
            id: versionOut
            onStreamFinished: {
                var text = versionOut.text || ""
                // Nothing read: keep the versions already known rather than
                // clearing every update the moment a scan comes back empty.
                if (text.trim() !== "") root.installedScan = Model.normalizeScan(text)
                else root.warnNoVersions()
            }
        }
        onExited: root.assembleInstalled()
    }

    // The install time is not in the manifest, so it comes from the directory
    // itself: `stat` prints birth time (0 when the filesystem does not record
    // one) then mtime. It is what makes "Newly installed" possible.
    Process {
        id: birthScanner
        running: false
        command: ["find", root.pluginsDir, "-mindepth", "1", "-maxdepth", "1",
                  "-type", "d", "-not", "-name", ".*",
                  "-exec", "stat", "--format=%W %Y %n", "{}", ";"]
        stdout: StdioCollector {
            id: birthOut
            onStreamFinished: {
                var text = birthOut.text || ""
                if (text.trim() !== "") root.installedBirths = Model.normalizeBirths(text)
            }
        }
        onExited: root.assembleInstalled()
    }

    // Which plugin directories are git checkouts. Only those can be updated by
    // `omarchy plugin update`; the rest are surfaced under Health. `%h` prints
    // the directory that holds each .git.
    Process {
        id: gitScanner
        running: false
        command: ["find", root.pluginsDir, "-mindepth", "2", "-maxdepth", "2",
                  "-name", ".git", "-type", "d", "-printf", "%h\n"]
        stdout: StdioCollector {
            id: gitOut
            onStreamFinished: root.gitDirs = Model.normalizeDirSet(gitOut.text || "")
        }
    }

    // ---- actions ----------------------------------------------------------------
    function perform(kind, id, name, repoUrl) {
        // update/remove act on the on-disk directory, which can differ from the id.
        var target = Model.pluginTarget(kind, id, installedMap)
        var built = Model.actionArgs(kind, target, repoUrl, config)
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

    // ---- clipboard paste (capped, no shell) -------------------------------------------
    // Pasting into a text field never reads the clipboard on the UI thread. wl-paste
    // runs directly (no shell) and its output is read in chunks. Reading stops as soon
    // as 1024 bytes are in, or after 2 seconds, and the process is stopped. The text is
    // then sent back through `pasted`, addressed to the field that asked.
    property string pasteKey: ""
    property string pasteBuf: ""
    readonly property int pasteMax: 1024
    signal pasted(string key, string text)

    function requestPaste(key) {
        if (pasteKey !== "" || pasteProc.running) return   // one paste at a time
        pasteKey = key
        pasteBuf = ""
        pasteProc.running = true
        pasteKill.restart()
    }

    function finishPaste() {
        var k = pasteKey
        if (k === "") return                              // already delivered
        pasteKey = ""
        pasteKill.stop()
        var text = pasteBuf.slice(0, pasteMax)
        pasteBuf = ""
        if (pasteProc.running) pasteProc.running = false  // stop reading the clipboard
        root.pasted(k, text)
    }

    Timer {
        id: pasteKill
        interval: 2000
        onTriggered: root.finishPaste()
    }

    Process {
        id: pasteProc
        running: false
        command: ["wl-paste", "--no-newline"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                if (root.pasteBuf.length >= root.pasteMax) return
                root.pasteBuf += data
                if (root.pasteBuf.length >= root.pasteMax) root.finishPaste()
            }
        }
        onExited: root.finishPaste()
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
    // Reveal an installed plugin's directory in the file manager. The name comes
    // from the filesystem, but it is re-checked before it is used as a path.
    function openPluginDir(dir) {
        var d = "" + dir
        if (!/^[A-Za-z0-9._-]{1,128}$/.test(d)) return
        opener.command = ["xdg-open", pluginsDir + "/" + d]
        opener.running = true
    }
    Process { id: opener; running: false }

    // ---- git history (detail pane changelog) -------------------------------------------
    // Read-only: the recent commits of an installed plugin, or (after a fetch) the
    // commits an update would bring in. Results are kept per plugin id.
    property var history: ({})                  // id -> { state, incoming, lines[], error }
    property string histId: ""
    property string histDir: ""
    property bool histIncoming: false

    function setHistory(id, rec) {
        var h = {}
        for (var k in history) h[k] = history[k]
        h[id] = rec
        history = h
    }

    function loadHistory(id, dir, incoming) {
        var d = str(dir)
        if (!/^[A-Za-z0-9._-]{1,128}$/.test(d)) return
        var cur = history[id]
        if (cur && cur.state === "loading") return
        if (cur && cur.state === "ready" && cur.incoming === (incoming === true)) return
        histId = id
        histDir = d
        histIncoming = incoming === true
        setHistory(id, { state: "loading", incoming: histIncoming, lines: [], error: "" })
        if (histIncoming) {
            fetchProc.command = Model.gitFetchArgs(pluginsDir + "/" + d)
            fetchProc.running = true
        } else {
            startHistoryLog()
        }
    }

    function startHistoryLog() {
        histProc.command = Model.gitLogArgs(pluginsDir + "/" + histDir, histIncoming)
        histProc.running = true
    }

    Process {
        id: fetchProc
        running: false
        stderr: StdioCollector { id: fetchErr }
        onExited: function(code) {
            if (code !== 0) {
                root.setHistory(root.histId, { state: "error", incoming: true, lines: [],
                    error: "Could not reach the remote to fetch changes." })
                return
            }
            root.startHistoryLog()
        }
    }

    Process {
        id: histProc
        running: false
        stdout: StdioCollector { id: histOut }
        stderr: StdioCollector { id: histErr }
        onExited: function(code) {
            if (code !== 0) {
                var msg = (histErr.text || "").trim().split("\n").slice(-1)[0] || "git log failed"
                root.setHistory(root.histId, { state: "error", incoming: root.histIncoming, lines: [], error: msg.slice(0, 160) })
                return
            }
            root.setHistory(root.histId, { state: "ready", incoming: root.histIncoming,
                lines: Model.parseGitLog(histOut.text || ""), error: "" })
        }
    }

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

    // ---- plugin sets (profiles) --------------------------------------------------------
    // Snapshot the currently installed third-party plugins. Each entry keeps a repo
    // so a later restore can reinstall what is missing: the catalog's address, or
    // the manifest's own clonedFrom for a local/unpublished plugin.
    function saveSet(name) {
        var label = String(name === undefined || name === null ? "" : name).trim().slice(0, 60)
        if (label === "") return false
        var plugins = Model.buildSet(installed, catalog)
        if (plugins.length === 0) return false
        var next = sets.slice()
        next.push({ name: label, savedAt: Date.now(), plugins: plugins })
        sets = next
        saveState()
        return true
    }

    // Additive restore: enable what is installed but off, install what is missing
    // (when a repo is known). Nothing already installed is removed or downgraded.
    function restoreSet(index) {
        var s = sets[index]
        if (!s) return 0
        var plan = Model.planRestore(s, installedMap)
        for (var i = 0; i < plan.length; i++)
            perform(plan[i].kind, plan[i].id, plan[i].name, plan[i].repo)
        return plan.length
    }

    function deleteSet(index) {
        if (index < 0 || index >= sets.length) return
        var next = sets.slice()
        next.splice(index, 1)
        sets = next
        saveState()
    }

    function saveState() {
        stateFile.setText(JSON.stringify({
            bookmarks: Object.keys(bookmarks), lastSeen: lastSeen, catalogTime: catalogTime,
            sets: sets
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
                root.sets = Array.isArray(s.sets) ? s.sets : []
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
