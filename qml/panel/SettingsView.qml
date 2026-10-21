import QtQuick
import QtQuick.Layouts
import "../js/Schema.js" as Schema
import "../controls"

// The body of the Settings tab. The panel header (ManagerView) already has the
// title, the search box and Reset all, so this is just:
//   * one underlined tab per group in Schema.js;
//   * that group's settings (tiles, segmented bars, sliders, switches), or every
//     match while searching.
// Every change is applied instantly and saved through the SettingsStore.
Item {
    id: root

    property var ui: null
    property int group: 0
    readonly property string filter: ui ? ui.settingsFilter : ""
    property bool confirmReset: false

    readonly property bool searching: filter.trim() !== ""
    readonly property bool onAbout: group === Schema.groups.length && !searching

    function rad(k) { return ui.r(k) }

    function val(key) {
        return ui.cfg && ui.cfg[key] !== undefined ? ui.cfg[key] : Schema.defaults[key]
    }

    // A row's value: one setting, or for a palette row its colors as { key: value }.
    function rowValue(item) {
        if (item.kind !== "palette") return val(item.key)
        var o = {}
        for (var i = 0; i < item.targets.length; i++) o[item.targets[i].key] = val(item.targets[i].key)
        return o
    }

    function same(item) {
        if (item.kind !== "palette") return String(val(item.key)) === String(item.fallback)
        for (var i = 0; i < item.targets.length; i++) {
            var k = item.targets[i].key
            if (String(val(k)).toLowerCase() !== String(item.fallback[k]).toLowerCase()) return false
        }
        return true
    }

    function edit(item, v) {
        if (!ui.store) return
        if (item.kind !== "palette") { ui.store.set(item.key, v); return }
        if (v && v.reset) {
            for (var i = 0; i < item.targets.length; i++)
                ui.store.set(item.targets[i].key, item.fallback[item.targets[i].key])
        } else if (v && v.key) {
            ui.store.set(v.key, v.value)
        }
    }

    // Window size is set by the window manager while the manager is popped out,
    // so these two settings have no effect there. Shown, but locked.
    function offHere(item) {
        return ui.popped === true && (item.key === "windowWidth" || item.key === "windowHeight")
    }

    function dimmed(item) {
        if (!item.when) return false
        for (var i = 0; i < item.when.length; i++) {
            var c = item.when[i]
            if (c.is.map(String).indexOf(String(val(c.key))) < 0) return true
        }
        return false
    }

    function matches(item) {
        var f = filter.trim().toLowerCase()
        if (f === "") return true
        return (item.label + " " + item.hint + " " + (item.section || "")).toLowerCase().indexOf(f) >= 0
    }

    // the rows to show: the chosen group, or every match while searching.
    // `head` is the heading over a row: the group title while searching, otherwise
    // the row's section when it starts a new one.
    readonly property var rows: {
        var out = []
        for (var g = 0; g < Schema.groups.length; g++) {
            if (!searching && g !== group) continue
            var items = Schema.groups[g].items
            var first = true
            var lastSection = ""
            for (var i = 0; i < items.length; i++) {
                if (!matches(items[i])) continue
                var section = items[i].section || ""
                var head = searching ? (first ? Schema.groups[g].title : "")
                                     : (section !== lastSection ? section : "")
                out.push({ item: items[i], head: head })
                lastSection = section
                first = false
            }
        }
        return out
    }

    // how many settings differ from their defaults
    readonly property int changed: {
        var n = 0
        for (var g = 0; g < Schema.groups.length; g++) {
            var items = Schema.groups[g].items
            for (var i = 0; i < items.length; i++)
                if (!same(items[i])) n++
        }
        return n
    }

    function resetAll() {
        if (!root.confirmReset) { root.confirmReset = true; confirmTimer.restart(); return }
        root.confirmReset = false
        if (ui.store) ui.store.resetAll(Schema.defaults)
    }
    Timer { id: confirmTimer; interval: 2500; onTriggered: root.confirmReset = false }

    ColumnLayout {
        anchors.fill: parent
        spacing: ui.px(12)

        // ---- tabs -------------------------------------------------------------------
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
                    model: Schema.groups.concat([{ title: "About" }])
                    delegate: Item {
                        readonly property bool on: index === root.group && !root.searching
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true

                        Txt {
                            ui: root.ui
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            text: modelData.title
                            opacity: root.searching ? 0.3 : (parent.on ? 1.0 : (tabArea.containsMouse ? 0.8 : 0.5))
                            font.pixelSize: ui.fs(12)
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
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
                            onClicked: { root.group = index; ui.settingsFilter = ""; ui.searchCleared() }
                        }
                    }
                }
            }
        }

        // ---- the settings of the active tab -------------------------------------------
        // the last tab: About
        AboutPage {
            ui: root.ui
            visible: root.onAbout
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Flickable {
            id: flick
            visible: !root.onAbout
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: card.implicitHeight + ui.px(4)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: card
                width: flick.width
                implicitHeight: rowsCol.implicitHeight + ui.px(12)

                ColumnLayout {
                    id: rowsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: ui.px(16)
                    anchors.rightMargin: ui.px(16)
                    anchors.topMargin: ui.px(6)
                    spacing: 0

                    Txt {
                        ui: root.ui
                        visible: root.rows.length === 0
                        Layout.topMargin: ui.px(14)
                        Layout.bottomMargin: ui.px(14)
                        text: "No setting matches that."
                        opacity: 0.5
                    }

                    Repeater {
                        model: root.rows
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Rectangle {
                                visible: index > 0
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: ui.tint(0.07)
                            }
                            Txt {
                                ui: root.ui
                                visible: modelData.head !== ""
                                Layout.topMargin: ui.px(12)
                                text: modelData.head.toUpperCase()
                                font.pixelSize: ui.fs(9)
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                                opacity: 0.45
                            }
                            SettingRow {
                                Layout.fillWidth: true
                                Layout.topMargin: ui.px(14)
                                Layout.bottomMargin: ui.px(14)
                                ui: root.ui
                                settingKey: modelData.item.key
                                label: modelData.item.label
                                hint: root.offHere(modelData.item)
                                    ? "Not used in a pop-out window: your window manager sizes it. Dock it to use this."
                                    : (modelData.item.hint || "")
                                kind: modelData.item.kind
                                control: modelData.item.control || ""
                                options: modelData.item.options || []
                                labels: modelData.item.labels || ({})
                                presets: modelData.item.presets || []
                                maxLength: modelData.item.maxLength !== undefined ? modelData.item.maxLength : 2048
                                min: modelData.item.min !== undefined ? modelData.item.min : 0
                                max: modelData.item.max !== undefined ? modelData.item.max : 100
                                step: modelData.item.step !== undefined ? modelData.item.step : 1
                                divisor: modelData.item.divisor !== undefined ? modelData.item.divisor : 1
                                decimals: modelData.item.decimals !== undefined ? modelData.item.decimals : 0
                                defaultValue: modelData.item.fallback
                                dimmed: root.dimmed(modelData.item)
                                locked: root.offHere(modelData.item)
                                value: root.rowValue(modelData.item)
                                targets: modelData.item.targets || []
                                onEdited: function(v) {
                                    if (root.offHere(modelData.item)) return
                                    if (modelData.item.key === "viewMode") ui.setView(v)
                                    else root.edit(modelData.item, v)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
