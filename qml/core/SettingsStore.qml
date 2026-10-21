import QtQuick
import Quickshell
import Quickshell.Io

// Local overrides for widget settings. Every change is applied on the spot and
// saved to settings.json in the state folder. Local overrides win over setting(...).
//
// Nothing here runs `omarchy bar set`: that makes Omarchy reload the bar config,
// which froze the shell. settings.json is the source of truth.
//
// This store is the only writer. The file is read once, at startup, and merged
// under anything already changed in memory. It is not watched, so a write can
// never be read back and undo a newer value.
Item {
    id: root

    property string pluginId: "io.github.qempexe.omanager"
    property string stateDir: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/omarchy-omanager"
    property string path: stateDir + "/settings.json"

    property var values: ({})
    property bool loaded: false        // the saved file has been read (or there is none)
    property bool dirReady: false      // the state folder exists, so writes can land

    signal changed()

    function get(key) {
        var v = values[key]
        return v === undefined ? null : v
    }

    function set(key, value) {
        var next = {}
        for (var k in values) next[k] = values[k]
        if (value === null || value === undefined) delete next[key]
        else next[key] = value
        values = next
        persist()
        changed()
    }

    function reset() {
        values = ({})
        persist()
        changed()
    }

    // Back to the given defaults, in one write.
    function resetAll(defaults) {
        var next = {}
        for (var k in defaults) next[k] = defaults[k]
        values = next
        persist()
        changed()
    }

    // Written shortly after the last change (a slider drag is one write, not fifty).
    function persist() { writeTimer.restart() }

    Timer {
        id: writeTimer
        interval: 150
        onTriggered: root.flushWrite()
    }

    // Never writes before the saved file has been read, so an early edit can't
    // overwrite settings that are still on disk.
    function flushWrite() {
        if (!dirReady || !loaded) { writeTimer.restart(); return }
        file.setText(JSON.stringify(root.values, null, 2) + "\n")
    }

    // FileView.text is a method in Quickshell, not a property. Passing `text`
    // straight through hands over the function object, JSON.parse then fails and
    // every start looks like "no saved settings". Always call it.
    function readText(fv) {
        try { return String(typeof fv.text === "function" ? fv.text() : fv.text) } catch (e) { return "" }
    }

    // Startup read: the file's values, with anything changed in memory on top.
    function absorb(text) {
        if (loaded) return
        var fromFile
        try {
            var parsed = JSON.parse(String(text || "{}"))
            fromFile = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({})
        } catch (e) {
            fromFile = ({})
        }
        var merged = {}
        for (var k in fromFile) merged[k] = fromFile[k]
        for (var j in values) merged[j] = values[j]
        values = merged
        loaded = true
        changed()
    }

    Component.onCompleted: mkdir.running = true

    Process {
        id: mkdir
        command: ["mkdir", "-p", "-m", "700", "--", root.stateDir]
        onExited: {
            root.dirReady = true
            if (!root.loaded) file.reload()
        }
    }

    FileView {
        id: file
        path: root.path
        onLoaded: root.absorb(root.readText(file))
        onLoadFailed: { if (!root.loaded) root.loaded = true }
    }
}
