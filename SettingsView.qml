import QtQuick
import QtQuick.Layouts
import "Schema.js" as Schema

// In-window settings: grouped, searchable, plain language. Every change is
// applied instantly and saved through the SettingsStore (which also mirrors it
// to `omarchy bar set`, so Omarchy's own settings UI stays in sync).
Item {
    id: root

    property var ui: null
    property int group: 0
    property string filter: ""
    property bool confirmReset: false

    function val(key) {
        return ui.cfg && ui.cfg[key] !== undefined ? ui.cfg[key] : Schema.defaults[key]
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
        return (item.label + " " + item.hint).toLowerCase().indexOf(f) >= 0
    }

    // the rows to show: the chosen group, or every match while searching
    readonly property var rows: {
        var out = []
        var searching = filter.trim() !== ""
        for (var g = 0; g < Schema.groups.length; g++) {
            if (!searching && g !== group) continue
            var items = Schema.groups[g].items
            for (var i = 0; i < items.length; i++)
                if (matches(items[i])) out.push(items[i])
        }
        return out
    }

    function resetAll() {
        if (!root.confirmReset) { root.confirmReset = true; confirmTimer.restart(); return }
        root.confirmReset = false
        if (ui.store) ui.store.resetAll(Schema.defaults)
    }
    Timer { id: confirmTimer; interval: 2500; onTriggered: root.confirmReset = false }

    RowLayout {
        anchors.fill: parent
        spacing: ui.px(14)

        // groups
        ColumnLayout {
            Layout.fillWidth: false
            Layout.minimumWidth: ui.px(170)
            Layout.preferredWidth: ui.px(170)
            Layout.maximumWidth: ui.px(170)
            Layout.fillHeight: true
            spacing: ui.px(6)

            Repeater {
                model: Schema.groups
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: ui.px(32)
                    radius: Math.max(2, ui.radius * 0.6)
                    readonly property bool on: index === root.group && root.filter.trim() === ""
                    color: on ? ui.accentTint(0.22) : ui.tint(gArea.containsMouse ? 0.10 : 0.04)
                    border.width: on ? 1 : 0
                    border.color: ui.accent
                    Txt {
                        ui: root.ui
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: ui.px(12)
                        text: modelData.title
                        color: parent.on ? ui.onText(ui.accent) : ui.fg
                        font.pixelSize: ui.fs(12)
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: gArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.group = index; root.filter = ""; searchBox.text = "" }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Btn {
                ui: root.ui
                Layout.fillWidth: true
                kind: root.confirmReset ? "primary" : "normal"
                text: root.confirmReset ? "Really reset?" : "Reset all settings"
                onClicked: root.resetAll()
            }
            Txt {
                ui: root.ui
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: ui.fs(10)
                opacity: 0.45
                text: "Changes apply instantly."
            }
        }

        // rows
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: ui.px(10)

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: ui.px(30)
                radius: Math.max(2, ui.radius * 0.6)
                color: ui.tint(0.06)
                border.width: 1
                border.color: searchBox.activeFocus ? ui.accent : ui.tint(0.12)
                TextInput {
                    id: searchBox
                    anchors.fill: parent
                    anchors.leftMargin: ui.px(10)
                    anchors.rightMargin: ui.px(10)
                    verticalAlignment: TextInput.AlignVCenter
                    color: ui.fg
                    selectionColor: ui.accent
                    selectedTextColor: ui.accentText
                    font.family: ui.fontName
                    font.pixelSize: ui.fs(12)
                    maximumLength: 80
                    selectByMouse: true
                    onTextChanged: root.filter = text
                    Keys.onEscapePressed: { text = ""; focus = false }
                    Txt {
                        ui: root.ui
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        visible: searchBox.text === "" && !searchBox.activeFocus
                        text: "Search settings\u2026"
                        opacity: 0.4
                    }
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: rowsCol.implicitHeight + ui.px(12)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: rowsCol
                    width: flick.width - ui.px(10)
                    spacing: 0

                    Txt {
                        ui: root.ui
                        visible: root.rows.length === 0
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
                            SettingRow {
                                Layout.fillWidth: true
                                Layout.topMargin: ui.px(12)
                                Layout.bottomMargin: ui.px(12)
                                ui: root.ui
                                label: modelData.label
                                hint: modelData.hint || ""
                                kind: modelData.kind
                                options: modelData.options || []
                                labels: modelData.labels || ({})
                                presets: modelData.presets || []
                                min: modelData.min !== undefined ? modelData.min : 0
                                max: modelData.max !== undefined ? modelData.max : 100
                                step: modelData.step !== undefined ? modelData.step : 1
                                divisor: modelData.divisor !== undefined ? modelData.divisor : 1
                                decimals: modelData.decimals !== undefined ? modelData.decimals : 0
                                defaultValue: modelData.fallback
                                dimmed: root.dimmed(modelData)
                                value: root.val(modelData.key)
                                onEdited: function(v) {
                                    if (modelData.key === "viewMode") ui.setView(v)
                                    else if (ui.store) ui.store.set(modelData.key, v)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
