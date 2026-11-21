import QtQuick
import QtQuick.Layouts
import "../js/Model.js" as Model
import "../browse"
import "../controls"

// The whole manager UI, drawn: one rounded panel,
// a header card, underlined tabs, one content card of rows, and the Esc footer.
// It lives either in the docked popup (Panel.qml) or in a floating window
// (PopoutWindow.qml); both feed it the same UiState (`ui`).
//
// Narrow windows (the default) show a compact list with the filters in a drawer.
// From about 720px wide it also offers the filter sidebar and the "List + stage" view.
Item {
    id: view

    property var ui: null
    property bool selectionListOpen: false
    Connections {
        target: view.ui
        function onSelCountChanged() {
            if (view.ui.selCount === 0) view.selectionListOpen = false
        }
    }
    clip: true

    readonly property bool wide: width >= ui.px(720)
    readonly property bool filtersAllowed: ui.filtersPanelKey === "left"
    readonly property bool sidebarDocked: wide && filtersAllowed
    property bool filtersOpen: false
    // what the layout really is right now ("List + stage" needs room)
    readonly property string mode: (ui.viewMode === "split" && !wide) ? "list" : ui.viewMode
    readonly property bool split: mode === "split"
    // tabs that show the plugin list (not Settings, not Sets)
    readonly property bool listTab: ui.tabName !== "settings" && ui.tabName !== "sets"

    // Esc steps back out of whatever is covering things. True when it did something.
    function stepBack() {
        if (selectionListOpen) { selectionListOpen = false; return true }
        if (ui.menu) { ui.closeMenu(); return true }
        if (ui.confirm) { ui.confirm = null; return true }
        if (ui.selected && !split) { ui.selected = null; return true }
        if (filtersOpen) { filtersOpen = false; return true }
        if (ui.showLog) { ui.showLog = false; return true }
        var t = ui.tabName === "settings" ? ui.settingsFilter : ui.query
        if (t !== "") {
            if (ui.tabName === "settings") ui.settingsFilter = ""
            else ui.query = ""
            ui.searchCleared()
            return true
        }
        return false
    }

    function cycleLayout() {
        var order = wide ? ["split", "grid", "list", "compact"] : ["grid", "list", "compact"]
        var i = order.indexOf(mode)
        ui.setView(order[(i + 1) % order.length])
    }

    // In a window nothing else listens for Esc; the docked popup has its own shortcut.
    Keys.onEscapePressed: function(e) {
        if (ui.popped) {
            if (!view.stepBack()) ui.closeRequested()
            e.accepted = true
        } else e.accepted = false
    }

    Connections {
        target: view.ui
        ignoreUnknownSignals: true
        function onSearchCleared() { searchField.text = "" }
        function onFocusSearch() { searchField.forceActiveFocus() }
        // one search box serves both: the catalog, and (on Settings) the settings
        function onTabNameChanged() { searchField.text = view.ui.tabName === "settings" ? view.ui.settingsFilter : view.ui.query }
    }

    // ---- chrome: the same panel in the dock and in the pop-out window ------------
    Rectangle {
        anchors.fill: parent
        radius: ui.r(3)
        color: ui.panelColor
    }
    Rectangle {   // optional accent wash (Window tint, 0 by default)
        anchors.fill: parent
        radius: ui.r(3)
        visible: ui.tintPct > 0
        color: ui.accentTint(ui.tintPct / 100)
    }
    Rectangle {   // edge: a plain neutral line, or one color if "Window outline" is on
        anchors.fill: parent
        radius: ui.r(3)
        color: "transparent"
        visible: !ui.frameGradientOn
        border.width: 1
        border.color: ui.frameOn ? ui.frameColor : ui.tint(0.14)
        opacity: ui.frameOn ? 0.8 : 1
    }
    Canvas {      // edge in the theme's window border gradient, at its angle
        id: frameCanvas
        anchors.fill: parent
        visible: ui.frameGradientOn
        opacity: 0.85
        readonly property var stops: ui.borderColors
        readonly property real angle: ui.borderAngle
        readonly property real rad: ui.r(3)
        onStopsChanged: requestPaint()
        onAngleChanged: requestPaint()
        onRadChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const n = stops.length
            if (!visible || n < 2 || width < 4 || height < 4) return
            const a = angle * Math.PI / 180, dx = Math.cos(a), dy = Math.sin(a)
            const half = (Math.abs(dx) * width + Math.abs(dy) * height) / 2
            const g = ctx.createLinearGradient(width / 2 - dx * half, height / 2 - dy * half,
                                               width / 2 + dx * half, height / 2 + dy * half)
            for (let i = 0; i < n; i++) g.addColorStop(i / (n - 1), stops[i])
            const r = Math.max(0, Math.min(rad, width / 2, height / 2)), x = 0.5, y = 0.5, w = width - 1, h = height - 1
            ctx.strokeStyle = g
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.arcTo(x + w, y, x + w, y + h, r)
            ctx.arcTo(x + w, y + h, x, y + h, r)
            ctx.arcTo(x, y + h, x, y, r)
            ctx.arcTo(x, y, x + w, y, r)
            ctx.closePath()
            ctx.stroke()
        }
    }

    function setSearch(t) {
        if (ui.tabName === "settings") ui.settingsFilter = t
        else ui.query = t
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ui.px(14)
        spacing: ui.px(12)

        // ---- header card: title, status, actions ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + ui.px(24)
            radius: ui.r(2.5)
            color: ui.tint(0.05)
            border.width: 1
            border.color: ui.tint(0.08)

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: ui.px(12)
                spacing: ui.px(12)

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: ui.px(30); implicitHeight: ui.px(30)
                    radius: ui.r(1.5)
                    color: ui.accentTint(0.18)
                    border.width: 1
                    border.color: ui.tint(0.08)
                    Image {   // the logo, light or dark to suit the window
                        anchors.centerIn: parent
                        width: ui.px(24); height: width
                        source: Qt.resolvedUrl(ui.lightText ? "../../assets/logo.png" : "../../assets/logo-dark.png")
                        sourceSize.width: 96
                        sourceSize.height: 96
                        smooth: true
                        mipmap: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Txt {
                        ui: view.ui
                        Layout.fillWidth: true
                        text: "Omanager"
                        font.pixelSize: ui.fs(13)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Txt {
                        ui: view.ui
                        Layout.fillWidth: true
                        font.pixelSize: ui.fs(11)
                        opacity: 0.6
                        elide: Text.ElideRight
                        text: {
                            if (!ui.service) return "Starting\u2026"
                            if (ui.service.busy) return ui.service.busyLabel
                            if (ui.service.catalog.length > 0)
                                return ui.service.catalog.length + " plugins  \u00B7  " + ui.service.installed.length + " installed"
                            return ui.service.catalogState === "loading" ? "Downloading catalog\u2026" : "Plugin manager"
                        }
                    }
                }

                Btn {
                    ui: view.ui
                    Layout.alignment: Qt.AlignVCenter
                    visible: ui.tabName === "settings"
                    kind: settingsView.confirmReset ? "primary" : "normal"
                    text: settingsView.confirmReset ? "Really reset?" : "Reset all"
                    onClicked: settingsView.resetAll()
                }
                Btn {
                    ui: view.ui
                    Layout.alignment: Qt.AlignVCenter
                    text: ui.service && ui.service.catalogState === "loading" ? "\u2026" : "\u21BB"
                    implicitWidth: ui.px(24)
                    enabled: ui.service && ui.service.catalogState !== "loading"
                    onClicked: { ui.service.refresh(true); ui.service.refreshInstalled() }
                }
                Btn {
                    ui: view.ui
                    Layout.alignment: Qt.AlignVCenter
                    text: ui.popped ? "Dock" : "Pop out"
                    onClicked: ui.popped ? ui.dockRequested() : ui.popOutRequested()
                }
                Btn { ui: view.ui; Layout.alignment: Qt.AlignVCenter; text: "\u00D7"; implicitWidth: ui.px(24); onClicked: ui.closeRequested() }
            }
        }

        // ---- tabs ------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: ui.px(32)

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: ui.tint(0.10)
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: [
                        { key: "browse", label: "Browse", n: -1 },
                        { key: "installed", label: "Installed", n: ui.service ? ui.service.installed.length : 0 },
                        { key: "updates", label: "Updates", n: ui.service ? ui.service.updateCount : 0 },
                        { key: "saved", label: "Saved", n: ui.service ? Object.keys(ui.service.bookmarks).length : 0 },
                        { key: "sets", label: "Sets", n: ui.service ? ui.service.sets.length : 0 },
                        { key: "settings", label: "Settings", n: -1 }
                    ]
                    delegate: Item {
                        readonly property bool on: ui.tabName === modelData.key
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true

                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            spacing: ui.px(6)
                            Txt {
                                ui: view.ui
                                text: modelData.label
                                font.pixelSize: ui.fs(12)
                                font.weight: parent.parent.on ? Font.DemiBold : Font.Normal
                                opacity: parent.parent.on ? 1 : (tabArea.containsMouse ? 0.8 : 0.5)
                            }
                            Rectangle {
                                visible: modelData.n > 0
                                width: cnt.implicitWidth + ui.px(10); height: ui.px(15); radius: height / 2
                                color: modelData.key === "updates" ? ui.warn : ui.tint(0.16)
                                anchors.verticalCenter: parent.verticalCenter
                                Txt {
                                    id: cnt
                                    ui: view.ui
                                    anchors.centerIn: parent
                                    text: modelData.n
                                    font.pixelSize: ui.fs(9)
                                    color: modelData.key === "updates" ? ui.warnText : ui.fg
                                }
                            }
                        }
                        Rectangle {
                            visible: parent.on
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: ui.accent
                        }
                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ui.tabName = modelData.key
                        }
                    }
                }
            }
        }

        // ---- content card -------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            radius: ui.r(2.5)
            color: ui.tint(0.035)
            border.width: 1
            border.color: ui.tint(0.07)
            clip: true

            Item {
                id: mainArea
                anchors.fill: parent
                anchors.margins: ui.px(10)

                ColumnLayout {
                    anchors.fill: parent
                    spacing: ui.px(8)

                    // ---- toolbar: search, filters, layout ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ui.px(8)

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: ui.px(80)
                            Layout.maximumWidth: ui.px(420)
                            implicitHeight: ui.px(28)
                            radius: ui.r(1.5)
                            color: ui.tint(0.05)
                            border.width: 1
                            border.color: searchField.activeFocus ? ui.tint(0.28) : ui.tint(0.08)
                            clip: true               // text longer than the box is cut at its edge, never drawn past it

                            Txt { ui: view.ui; anchors.left: parent.left; anchors.leftMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; text: "\u2315"; opacity: 0.5; font.pixelSize: ui.fs(14) }
                            PasteInput {
                                id: searchField
                                key: "search"
                                service: ui.service
                                anchors.fill: parent
                                anchors.leftMargin: ui.px(30)
                                anchors.rightMargin: ui.px(30)
                                color: ui.fg
                                font.family: ui.fontName
                                font.pixelSize: ui.fs(12)
                                maximumLength: 50
                                text: ui.query
                                onTextEdited: view.setSearch(text)
                                Keys.onEscapePressed: function(e) {
                                    if (text !== "") { text = ""; view.setSearch(""); e.accepted = true }
                                    else e.accepted = false
                                }
                                Keys.onDownPressed: if (ui.tabName !== "settings") results.focusGrid()
                                Txt {
                                    ui: view.ui
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: searchField.text === "" && !searchField.activeFocus
                                    text: ui.tabName === "settings" ? "Search settings\u2026" : "Search, or tag:media, kind:panel, @author\u2026"
                                    opacity: 0.4
                                }
                            }
                            Txt {
                                ui: view.ui
                                anchors.right: parent.right
                                anchors.rightMargin: ui.px(10)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text !== ""
                                text: "\u2715"
                                opacity: 0.6
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { searchField.text = ""; view.setSearch("") } }
                            }
                        }

                        Btn {
                            ui: view.ui
                            visible: view.listTab && view.filtersAllowed && !view.wide
                            active: view.filtersOpen
                            text: ui.filtersActive ? "Filters \u2022" : "Filters"
                            onClicked: view.filtersOpen = !view.filtersOpen
                        }
                        Btn {
                            ui: view.ui
                            visible: view.listTab
                            text: view.mode === "split" ? "\u25E7 Stage"
                                : (view.mode === "grid" ? "\u25A6 Cards"
                                : (view.mode === "list" ? "\u2630 List" : "\u2263 Compact"))
                            onClicked: view.cycleLayout()
                        }
                        Btn {
                            ui: view.ui
                            visible: view.listTab
                            active: ui.selectMode
                            text: ui.selectMode ? "Done" : "Select"
                            onClicked: ui.setSelectMode(!ui.selectMode)
                        }
                    }

                    // ---- tab-specific batch action bar ----
                    RowLayout {
                        Layout.fillWidth: true
                        visible: ui.batchKind !== "" || ui.selectMode
                        spacing: ui.px(6)

                        Flickable {
                            Layout.fillWidth: true
                            Layout.minimumWidth: ui.px(100)
                            Layout.preferredHeight: Math.min(selectedChips.implicitHeight, ui.px(82))
                            contentWidth: width
                            contentHeight: selectedChips.implicitHeight
                            flickableDirection: Flickable.VerticalFlick
                            clip: true

                            Flow {
                                id: selectedChips
                                width: parent.width
                                spacing: ui.px(5)

                                Txt {
                                    ui: view.ui
                                    height: ui.px(24)
                                    verticalAlignment: Text.AlignVCenter
                                    text: ui.selCount === 0 ? "Select plugins or use All"
                                        : ui.selCount + " selected"
                                    font.pixelSize: ui.fs(11)
                                    opacity: 0.7
                                }
                                Repeater {
                                    model: ui.selectedPlugins.slice(0, 20)
                                    delegate: Rectangle {
                                        id: chip
                                        property var plugin: modelData
                                        width: Math.min(ui.px(180), nameLabel.implicitWidth + ui.px(32))
                                        height: ui.px(24)
                                        radius: ui.r(1.5)
                                        color: ui.accentTint(chipArea.containsMouse ? 0.26 : 0.16)
                                        border.width: 1
                                        border.color: ui.accentTint(0.4)

                                        Txt {
                                            id: nameLabel
                                            ui: view.ui
                                            anchors.left: parent.left
                                            anchors.leftMargin: ui.px(8)
                                            anchors.right: removeMark.left
                                            anchors.rightMargin: ui.px(4)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: chip.plugin.name
                                            elide: Text.ElideRight
                                            font.pixelSize: ui.fs(11)
                                        }
                                        Txt {
                                            id: removeMark
                                            ui: view.ui
                                            anchors.right: parent.right
                                            anchors.rightMargin: ui.px(7)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "\u00d7"
                                            opacity: chipArea.containsMouse ? 1 : 0
                                            font.pixelSize: ui.fs(14)
                                        }
                                        MouseArea {
                                            id: chipArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ui.unselect(chip.plugin.id)
                                        }
                                    }
                                }
                            }
                        }
                        Btn { ui: view.ui; Layout.alignment: Qt.AlignTop; text: "All"; enabled: ui.batchKind === "" ? ui.items.length > 0 : ui.batchEligible.length > 0; onClicked: ui.requestSelectAll() }
                        Btn { ui: view.ui; Layout.alignment: Qt.AlignTop; text: "None"; visible: ui.selCount > 0; onClicked: ui.clearSelection() }
                        Btn {
                            ui: view.ui
                            Layout.alignment: Qt.AlignTop
                            visible: ui.batchKind !== ""
                            kind: ui.batchKind === "remove" ? "danger" : "primary"
                            text: ui.batchKind === "install" ? "Install selected"
                                : (ui.batchKind === "remove" ? "Remove selected" : "Update selected")
                            enabled: ui.selectedFor(ui.batchKind).length > 0
                            onClicked: ui.requestBatch(ui.batchKind)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: ui.selCount > 20 || (ui.selectMode && ui.selCount > 0)
                        spacing: ui.px(6)
                        Btn { ui: view.ui; visible: ui.selCount > 20; text: "+" + (ui.selCount - 20) + " more"; onClicked: view.selectionListOpen = true }
                        Btn { ui: view.ui; text: "Update"; visible: ui.selectMode && ui.tabName !== "updates"; enabled: ui.selectedFor("update").length > 0; onClicked: ui.requestBatch("update") }
                        Btn { ui: view.ui; text: "Enable"; visible: ui.selectMode; enabled: ui.selectedFor("enable").length > 0; onClicked: ui.requestBatch("enable") }
                        Btn { ui: view.ui; text: "Disable"; visible: ui.selectMode; enabled: ui.selectedFor("disable").length > 0; onClicked: ui.requestBatch("disable") }
                        Btn { ui: view.ui; text: "Save"; visible: ui.selectMode; enabled: ui.selectedFor("save").length > 0; onClicked: ui.requestBatch("save") }
                        Btn { ui: view.ui; text: "Remove"; kind: "danger"; visible: ui.selectMode && ui.tabName !== "installed"; enabled: ui.selectedFor("remove").length > 0; onClicked: ui.requestBatch("remove") }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: ui.service && (ui.service.current !== null || ui.service.queue.length > 0)
                        Txt {
                            ui: view.ui
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: ui.service && ui.service.current
                                ? ui.service.current.label + "  (" + ui.service.queue.length + " waiting)" : ""
                        }
                        Btn {
                            ui: view.ui
                            visible: ui.service && ui.service.queue.length > 0
                            text: "Stop after current"
                            onClicked: ui.service.cancelQueued()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0

                        RowLayout {
                            anchors.fill: parent
                            spacing: ui.px(12)
                            visible: view.listTab

                            FilterSidebar {
                                ui: view.ui
                                visible: view.sidebarDocked
                                Layout.preferredWidth: ui.px(214)
                                Layout.fillHeight: true
                            }
                            Rectangle {
                                visible: view.sidebarDocked
                                Layout.fillHeight: true
                                implicitWidth: 1
                                color: ui.tint(0.10)
                            }

                            ResultsView {
                                id: results
                                ui: view.ui
                                Layout.fillWidth: !view.split
                                Layout.minimumWidth: ui.px(220)
                                // wide enough for the full stats line without cutting it off
                                Layout.preferredWidth: view.split
                                    ? Math.max(ui.px(240), Math.min(ui.px(500), mainArea.width * 0.46)) : ui.px(300)
                                Layout.maximumWidth: view.split ? Math.max(ui.px(240), Math.min(ui.px(500), mainArea.width * 0.46)) : 100000
                                Layout.fillHeight: true
                            }

                            Rectangle {
                                visible: view.split
                                Layout.fillHeight: true
                                implicitWidth: 1
                                color: ui.tint(0.10)
                            }

                            // the stage: big preview + actions for the selected (or top) plugin
                            DetailPane {
                                ui: view.ui
                                inline: true
                                p: ui.stageItem
                                visible: view.split
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.fillHeight: true
                            }
                        }

                        SettingsView {
                            id: settingsView
                            ui: view.ui
                            anchors.fill: parent
                            visible: ui.tabName === "settings"
                        }

                        SetsView {
                            ui: view.ui
                            anchors.fill: parent
                            visible: ui.tabName === "sets"
                        }

                        // filters drawer (narrow windows)
                        Rectangle {
                            visible: view.filtersOpen && !view.wide && view.filtersAllowed && view.listTab
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: Math.min(ui.px(250), parent.width - ui.px(40))
                            radius: ui.r(2)
                            color: ui.surface
                            border.width: 1
                            border.color: ui.tint(0.16)
                            clip: true
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function(w) { w.accepted = true } }
                            FilterSidebar {
                                ui: view.ui
                                anchors.fill: parent
                                anchors.margins: ui.px(10)
                            }
                        }

                        DetailPane {
                            ui: view.ui
                            p: ui.selected
                            visible: !view.split && ui.selected !== null && view.listTab
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: Math.min(ui.px(420), parent.width - ui.px(40))
                        }
                    }
                }
            }
        }

        // ---- activity log ----
        Rectangle {
            Layout.fillWidth: true
            visible: ui.showLog
            implicitHeight: ui.px(110)
            radius: Math.max(2, ui.radius)
            color: ui.tint(0.05)
            border.width: 1
            border.color: ui.tint(0.10)
            clip: true
            ListView {
                anchors.fill: parent
                anchors.margins: ui.px(8)
                model: ui.service ? ui.service.log.slice().reverse() : []
                delegate: Txt {
                    ui: view.ui
                    width: ListView.view.width
                    elide: Text.ElideRight
                    font.pixelSize: ui.fs(10)
                    color: modelData.ok ? ui.fg : ui.bad
                    text: Qt.formatTime(new Date(modelData.time), "HH:mm:ss") + "  " + modelData.text
                }
            }
            Txt {
                ui: view.ui
                anchors.centerIn: parent
                visible: !ui.service || ui.service.log.length === 0
                text: "Nothing has happened yet."
                opacity: 0.4
            }
        }

        // ---- footer: Esc hint, status, log, and the instant-apply note ----------------
        RowLayout {
            Layout.fillWidth: true
            spacing: ui.px(8)

            Rectangle {
                implicitWidth: escLabel.implicitWidth + ui.px(12)
                implicitHeight: ui.px(18)
                radius: ui.r(1)
                color: ui.tint(0.08)
                Txt { id: escLabel; ui: view.ui; anchors.centerIn: parent; text: "Esc"; font.pixelSize: ui.fs(10); opacity: 0.75 }
            }
            Txt { ui: view.ui; text: "close"; font.pixelSize: ui.fs(10); opacity: 0.45 }

            Txt {
                ui: view.ui
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: ui.fs(10)
                opacity: 0.65
                visible: view.listTab
                color: ui.service && ui.service.catalogState === "stale" ? ui.warn : ui.fg
                text: {
                    if (!ui.service) return ""
                    if (ui.service.busy) return ui.service.busyLabel + (ui.service.queue.length > 0 ? "  (+" + ui.service.queue.length + " queued)" : "")
                    if (ui.service.catalogState === "loading")
                        return ui.service.catalog.length > 0 ? "Checking for a newer catalog\u2026" : "Downloading catalog\u2026"
                    if (ui.service.catalogState === "stale") return "Offline: showing the saved catalog from " + Model.relTime(ui.service.catalogTime, ui.now)
                    if (ui.service.catalogState === "error") return ui.service.catalogError
                    return "Catalog checked " + Model.relTime(ui.service.catalogTime, ui.now)
                        + (ui.service.log.length ? "  \u00B7  " + ui.service.log[ui.service.log.length - 1].text : "")
                }
            }
            Txt {
                ui: view.ui
                Layout.fillWidth: true
                visible: ui.tabName === "settings"
                elide: Text.ElideRight
                font.pixelSize: ui.fs(10)
                opacity: 0.45
                text: settingsView.changed === 0 ? "All settings are at their defaults"
                    : settingsView.changed + (settingsView.changed === 1 ? " setting differs" : " settings differ") + " from the defaults"
            }
            Btn { ui: view.ui; visible: view.listTab; text: ui.showLog ? "Hide log" : "Log"; implicitHeight: ui.px(22); active: ui.showLog; onClicked: ui.showLog = !ui.showLog }
            Txt { ui: view.ui; visible: ui.tabName === "settings"; text: "Changes apply instantly"; font.pixelSize: ui.fs(10); opacity: 0.45 }
        }
    }

    // A virtual list for large selections; the toolbar only instantiates 20 chips.
    Rectangle {
        anchors.fill: parent
        visible: view.selectionListOpen && ui.selCount > 0
        z: 30
        color: Qt.rgba(ui.surface.r, ui.surface.g, ui.surface.b, 0.95)
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - ui.px(40), ui.px(480))
            height: Math.min(parent.height - ui.px(60), ui.px(500))
            color: ui.surface
            border.width: 1
            border.color: ui.tint(0.2)
            radius: ui.r(2)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: ui.px(16)
                spacing: ui.px(8)
                RowLayout {
                    Layout.fillWidth: true
                    Txt { ui: view.ui; Layout.fillWidth: true; text: ui.selCount + " selected" }
                    Btn { ui: view.ui; text: "Close"; onClicked: view.selectionListOpen = false }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ui.selectedPlugins
                    spacing: ui.px(4)
                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width : 0
                        height: ui.px(28)
                        radius: ui.r(1.5)
                        color: selectedRow.containsMouse ? ui.accentTint(0.2) : ui.tint(0.07)
                        Txt {
                            ui: view.ui
                            anchors.fill: parent
                            anchors.leftMargin: ui.px(8)
                            anchors.rightMargin: ui.px(8)
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: modelData.name + "  ×"
                        }
                        MouseArea {
                            id: selectedRow
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ui.unselect(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ---- confirmation dialog ----
    Rectangle {
        anchors.fill: parent
        visible: ui.confirm !== null
        radius: ui.r(3)
        color: Qt.rgba(ui.surface.r, ui.surface.g, ui.surface.b, 0.85)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function(w) { w.accepted = true } }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - ui.px(40), ui.px(460))
            implicitHeight: dlg.implicitHeight + ui.px(36)
            height: implicitHeight
            radius: ui.radius
            color: ui.surface
            border.width: 1
            border.color: ui.tint(0.18)

            ColumnLayout {
                id: dlg
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ui.px(18)
                spacing: ui.px(10)

                readonly property string kind: ui.confirm ? ui.confirm.kind : ""
                readonly property var plug: ui.confirm ? ui.confirm.p : null
                readonly property var list: (ui.confirm && ui.confirm.list) ? ui.confirm.list : null
                readonly property int n: list ? list.length : (plug ? 1 : 0)
                readonly property bool choosingAll: kind === "selectAll"
                readonly property bool batchLimited: kind === "batchLimit"
                readonly property string tabLabel: ui.confirm && ui.confirm.tab
                    ? ui.confirm.tab.charAt(0).toUpperCase() + ui.confirm.tab.slice(1) : ""
                readonly property string verb: batchLimited ? "Run first " + dlg.list.length
                    : (choosingAll ? "Select all"
                    : (kind === "remove" ? "Remove" : (kind === "update" ? "Update" : "Install")))

                Txt {
                    ui: view.ui
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: ui.fs(15)
                    font.weight: Font.DemiBold
                    text: dlg.batchLimited ? "Run first " + dlg.n + " of " + ui.confirm.count + " selected plugins?"
                        : dlg.choosingAll ? "Select all " + dlg.n + " plugins in " + dlg.tabLabel + "?"
                        : (dlg.plug ? (dlg.n > 1 ? dlg.verb + " " + dlg.n + " plugins?"
                                                    : dlg.verb + " " + dlg.plug.name + "?") : "")
                }
                Txt {
                    ui: view.ui
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    opacity: 0.75
                    text: {
                        if (dlg.choosingAll)
                            return "This replaces your current selection with all " + dlg.n
                                + " eligible plugins shown in this tab. No plugins will be installed, updated or removed until you choose an action."
                        if (dlg.batchLimited)
                            return "Only the first " + ui.batchLimit + " will be queued. The rest remain selected. Stop after current cancels waiting jobs, not the one already running."
                        if (!dlg.plug) return ""
                        if (dlg.kind === "remove") return dlg.n > 1 ? "Those plugin folders are deleted from your plugins directory."
                                                                    : "The plugin folder is deleted from your plugins directory."
                        var t = "Plugins run as unsandboxed code inside your shell, with your user permissions. Installing fetches the plugin's current upstream code"
                        t += dlg.plug.verified ? ", which may be newer than the snapshot that earned its Verified badge." : "."
                        if (dlg.list && dlg.list.some(function(p) { return !p.verified }))
                            t += "\n\nThis selection includes unverified plugins."
                        else if (!dlg.plug.verified) t += "\n\nThis plugin is NOT verified."
                        return t
                    }
                }
                Txt {
                    ui: view.ui
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    visible: dlg.plug && dlg.n === 1 && dlg.plug.repo !== "" && dlg.kind !== "remove"
                    font.pixelSize: ui.fs(10)
                    opacity: 0.55
                    text: dlg.plug ? "From " + dlg.plug.repo : ""
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: ui.px(8)
                    Btn { ui: view.ui; text: "Cancel"; onClicked: ui.confirm = null }
                    Btn {
                        ui: view.ui
                        kind: dlg.kind === "remove" ? "danger" : "primary"
                        text: dlg.verb
                        onClicked: {
                            var c = ui.confirm
                            ui.confirm = null
                            if (!c) return
                            if (c.kind === "selectAll") ui.confirmSelectAll(c)
                            else if (c.kind === "batchLimit") ui.runBatch(c.action, c.list)
                            else if (c.list) ui.runBatch(c.kind, c.list)
                            else ui.runAction(c.kind, c.p)
                        }
                    }
                }
            }
        }
    }

    // ---- right-click menu (over everything, above the confirm dialog) ----
    ContextMenu {
        ui: view.ui
        anchors.fill: parent
        z: 50
    }
}
