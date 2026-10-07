import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar button for Omanager. Clicking it opens / closes the manager window
// (Panel.qml). The window follows the Omarchy panel contract: this entry point
// forwards opened / open() / close() / toggle() so Escape, the bar and
// `omarchy-shell shell summon|hide` all work.
BarWidget {
    id: root

    moduleName: "io.github.qempexe.omanager"

    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null

    // ---- local overrides (written by the in-window settings) ---------------
    SettingsStore { id: settingsStore }

    // Local override wins over `omarchy bar set` / the manifest default.
    function over(key, fallback) {
        var v = settingsStore.get(key)
        return v === null ? fallback : v
    }

    function pick(value, allowed, fallback) {
        var v = String(value)
        return allowed.indexOf(v) >= 0 ? v : fallback
    }

    function whole(value, lo, hi, fallback) {
        var v = Number(value)
        if (!isFinite(v)) return fallback
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    // `omarchy bar set` may store booleans as strings, so accept both.
    function flag(value, fallback) {
        if (value === true || value === "true") return true
        if (value === false || value === "false") return false
        return fallback
    }

    // ---- settings: every key read here is declared in manifest.json --------
    // BEGIN GENERATED SETTINGS (tools/gen.py)
    readonly property string opt_colorMode: pick(over("colorMode", setting("colorMode", "theme")), ["theme", "custom", "mono", "category"], "theme")
    readonly property string opt_accentColor: String(over("accentColor", setting("accentColor", "#ff6a1f")))
    readonly property string opt_cardStyle: pick(over("cardStyle", setting("cardStyle", "soft")), ["soft", "outline", "flat"], "soft")
    readonly property string opt_density: pick(over("density", setting("density", "comfortable")), ["compact", "comfortable", "spacious"], "comfortable")
    readonly property int opt_cornerRadius: whole(over("cornerRadius", setting("cornerRadius", 4)), 0, 20, 4)
    readonly property bool opt_frame: flag(over("frame", setting("frame", true)), true)
    readonly property int opt_fontScale: whole(over("fontScale", setting("fontScale", 100)), 80, 150, 100)
    readonly property int opt_surfaceTint: whole(over("surfaceTint", setting("surfaceTint", 6)), 0, 30, 6)
    readonly property bool opt_showPreviews: flag(over("showPreviews", setting("showPreviews", true)), true)
    readonly property int opt_windowWidth: whole(over("windowWidth", setting("windowWidth", 1040)), 640, 1600, 1040)
    readonly property int opt_windowHeight: whole(over("windowHeight", setting("windowHeight", 700)), 420, 1100, 700)
    readonly property string opt_openAs: pick(over("openAs", setting("openAs", "panel")), ["panel", "window"], "panel")
    readonly property string opt_viewMode: pick(over("viewMode", setting("viewMode", "split")), ["split", "grid", "list", "compact"], "split")
    readonly property string opt_columns: pick(over("columns", setting("columns", "auto")), ["auto", "1", "2", "3", "4"], "auto")
    readonly property string opt_filtersPanel: pick(over("filtersPanel", setting("filtersPanel", "left")), ["left", "hidden"], "left")
    readonly property string opt_defaultSource: pick(over("defaultSource", setting("defaultSource", "community")), ["community", "builtin", "all"], "community")
    readonly property string opt_defaultSort: pick(over("defaultSort", setting("defaultSort", "newest")), ["newest", "listed", "updated", "fresh", "hearts", "stars", "views", "rated", "az"], "newest")
    readonly property string opt_recencyScope: pick(over("recencyScope", setting("recencyScope", "either")), ["either", "added", "updated"], "either")
    readonly property string opt_recencyDays: pick(over("recencyDays", setting("recencyDays", "any")), ["any", "7", "30", "90", "365"], "any")
    readonly property bool opt_verifiedOnly: flag(over("verifiedOnly", setting("verifiedOnly", false)), false)
    readonly property bool opt_hideInstalled: flag(over("hideInstalled", setting("hideInstalled", false)), false)
    readonly property bool opt_showCounts: flag(over("showCounts", setting("showCounts", true)), true)
    readonly property int opt_newBadgeDays: whole(over("newBadgeDays", setting("newBadgeDays", 14)), 1, 60, 14)
    readonly property string opt_catalogUrl: String(over("catalogUrl", setting("catalogUrl", "https://plugins.omarchy.org/catalog.json")))
    readonly property int opt_refreshHours: whole(over("refreshHours", setting("refreshHours", 1)), 1, 168, 1)
    readonly property bool opt_refreshOnOpen: flag(over("refreshOnOpen", setting("refreshOnOpen", true)), true)
    readonly property bool opt_checkUpdates: flag(over("checkUpdates", setting("checkUpdates", true)), true)
    readonly property bool opt_confirmInstall: flag(over("confirmInstall", setting("confirmInstall", true)), true)
    readonly property bool opt_confirmRemove: flag(over("confirmRemove", setting("confirmRemove", true)), true)
    readonly property bool opt_allowUnverified: flag(over("allowUnverified", setting("allowUnverified", true)), true)
    readonly property bool opt_enableAfterInstall: flag(over("enableAfterInstall", setting("enableAfterInstall", true)), true)
    readonly property bool opt_showSecurityNote: flag(over("showSecurityNote", setting("showSecurityNote", true)), true)
    readonly property string opt_barDisplay: pick(over("barDisplay", setting("barDisplay", "both")), ["icon", "text", "both"], "both")
    readonly property string opt_barText: String(over("barText", setting("barText", "Plugins")))
    readonly property bool opt_showBadge: flag(over("showBadge", setting("showBadge", true)), true)
    readonly property string opt_middleClick: pick(over("middleClick", setting("middleClick", "refresh")), ["refresh", "none"], "refresh")

    readonly property var cfg: ({
        colorMode: opt_colorMode,
        accentColor: opt_accentColor,
        cardStyle: opt_cardStyle,
        density: opt_density,
        cornerRadius: opt_cornerRadius,
        frame: opt_frame,
        fontScale: opt_fontScale,
        surfaceTint: opt_surfaceTint,
        showPreviews: opt_showPreviews,
        windowWidth: opt_windowWidth,
        windowHeight: opt_windowHeight,
        openAs: opt_openAs,
        viewMode: opt_viewMode,
        columns: opt_columns,
        filtersPanel: opt_filtersPanel,
        defaultSource: opt_defaultSource,
        defaultSort: opt_defaultSort,
        recencyScope: opt_recencyScope,
        recencyDays: opt_recencyDays,
        verifiedOnly: opt_verifiedOnly,
        hideInstalled: opt_hideInstalled,
        showCounts: opt_showCounts,
        newBadgeDays: opt_newBadgeDays,
        catalogUrl: opt_catalogUrl,
        refreshHours: opt_refreshHours,
        refreshOnOpen: opt_refreshOnOpen,
        checkUpdates: opt_checkUpdates,
        confirmInstall: opt_confirmInstall,
        confirmRemove: opt_confirmRemove,
        allowUnverified: opt_allowUnverified,
        enableAfterInstall: opt_enableAfterInstall,
        showSecurityNote: opt_showSecurityNote,
        barDisplay: opt_barDisplay,
        barText: opt_barText,
        showBadge: opt_showBadge,
        middleClick: opt_middleClick
    })
    // END GENERATED SETTINGS

    // ---- service -----------------------------------------------------------
    readonly property string configKey: [opt_catalogUrl, opt_refreshHours, opt_checkUpdates,
                                         opt_enableAfterInstall].join("|")

    function pushConfig() {
        if (!service) return
        service.configure({
            catalogUrl: opt_catalogUrl, refreshHours: opt_refreshHours,
            checkUpdates: opt_checkUpdates, enableAfterInstall: opt_enableAfterInstall
        })
    }

    onConfigKeyChanged: Qt.callLater(pushConfig)
    Component.onCompleted: pushConfig()

    readonly property int updates: service && opt_showBadge ? service.updateCount : 0
    readonly property string icon: "\uDB81\uDC31"

    readonly property string label: {
        var t = opt_barDisplay === "icon" ? icon
              : (opt_barDisplay === "text" ? opt_barText : icon + " " + opt_barText)
        return updates > 0 ? t + " " + updates : t
    }

    readonly property string tooltip: {
        var n = service ? service.catalog.length : 0
        var s = "Omanager: " + (n > 0 ? n + " plugins" : "plugin manager")
        if (service && service.updateCount > 0) s += ", " + service.updateCount + " update(s)"
        return s
    }

    // ---- window state (shared by the bar panel and the pop-out window) -----------
    // One UiState feeds whichever surface is showing, so filters, selection and
    // scroll context survive popping out and docking back.
    property bool popped: false
    property bool modeChosen: false

    UiState {
        id: ux
        service: root.service
        store: settingsStore
        cfg: root.cfg
        opened: root.panelOpened || root.windowShown
        popped: root.popped
        fg: root.bar ? root.bar.barForeground : Color.foreground
        fontName: root.bar ? root.bar.fontFamily : Style.font.family
        onPopOutRequested: root.popOut()
        onDockRequested: root.dock()
        onCloseRequested: root.close()
    }

    readonly property bool panelOpened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool windowShown: windowLoader.item ? windowLoader.item.visible === true : false

    // The shell only knows about the bar-panel state.
    readonly property bool opened: panelOpened
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false

    // The first open follows the "Open as" setting; after that the header's
    // pop-out / dock buttons decide.
    function chooseMode() {
        if (modeChosen) return
        modeChosen = true
        popped = opt_openAs === "window"
    }

    function showWindow() {
        windowLoader.active = true
        if (windowLoader.item) windowLoader.item.visible = true
    }

    function hideWindow() {
        if (windowLoader.item) windowLoader.item.visible = false
        windowLoader.active = false
    }

    // If the bar panel cannot be shown (Panel.qml failed to load, or the shell
    // never reported it open), show the manager as its own window instead of
    // doing nothing. The reason goes to the shell log (`qs log`).
    property bool wantPanel: false

    function fallbackToWindow(reason) {
        console.warn("Omanager: " + reason + "; opening as a window instead")
        wantPanel = false
        panelCheck.stop()
        modeChosen = true
        popped = true
        showWindow()
    }

    function openPanel() {
        if (panelLoader.status === Loader.Error || !panelLoader.item) {
            fallbackToWindow("Panel.qml is not loaded (status " + panelLoader.status + ")")
            return
        }
        injectPanel()
        wantPanel = true
        panelLoader.item.open()
        panelCheck.restart()
    }

    function closePanel() {
        wantPanel = false
        panelCheck.stop()
        if (panelLoader.item) panelLoader.item.close()
    }

    function open() {
        chooseMode()
        if (popped) showWindow()
        else openPanel()
    }

    function close() {
        closePanel()
        hideWindow()
    }

    function toggle() {
        chooseMode()
        if (popped) {
            if (windowShown) hideWindow()
            else showWindow()
        } else if (panelOpened) {
            closePanel()
        } else {
            openPanel()
        }
    }

    function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

    function popOut() {
        modeChosen = true
        popped = true
        closePanel()
        showWindow()
    }

    function dock() {
        modeChosen = true
        hideWindow()
        popped = false
        Qt.callLater(root.openPanel)
    }

    onPanelOpenedChanged: if (panelOpened) { wantPanel = false; panelCheck.stop() }

    Timer {
        id: panelCheck
        interval: 600
        repeat: false
        onTriggered: if (root.wantPanel && !root.panelOpened && !root.popped)
            root.fallbackToWindow("the panel did not open")
    }

    function showTab(name) {
        ux.tabName = name
        open()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
        panelLoader.item.ui = ux
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    onServiceChanged: { pushConfig(); injectPanel() }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omanager: Panel.qml failed to load; run `qs log` for the QML error")
    }

    // A real, resizable, movable window. Only exists while popped out.
    Loader {
        id: windowLoader
        active: false
        source: Qt.resolvedUrl("PopoutWindow.qml")
        onLoaded: {
            item.ui = ux
            item.visible = true
        }
        onStatusChanged: if (status === Loader.Error)
            console.warn("Omanager: PopoutWindow.qml failed to load; run `qs log` for the QML error")
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.label
        tooltipText: root.tooltip
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
            else if (buttonCode === Qt.RightButton) root.showTab("settings")
            else if (buttonCode === Qt.MiddleButton && root.opt_middleClick === "refresh" && root.service)
                root.service.refresh(true)
        }
    }
}
