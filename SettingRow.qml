import QtQuick
import QtQuick.Layouts

// One setting: label + plain-language hint on the left, current value and a
// reset arrow on the right, and a purpose-built control underneath.
//   kind  enum    chips (option names are friendly labels)
//         int     slider with - / + buttons
//         bool    switch
//         string  text field (+ optional preset chips)
//         color   swatches + hex field
Item {
    id: root

    property var ui: null
    property string label: ""
    property string hint: ""
    property string kind: "string"
    property var options: []
    property var labels: ({})
    property var presets: []
    property var value: null
    property var defaultValue: null
    property real min: 0
    property real max: 100
    property real step: 1
    property real divisor: 1
    property int decimals: 0
    property bool dimmed: false

    signal edited(var v)

    function str(v) { return (v === null || v === undefined) ? "" : String(v) }
    function same(a, b) { return str(a) === str(b) }
    function labelFor(opt) { return labels[opt] !== undefined ? labels[opt] : String(opt) }
    function show(v) {
        var n = Number(v) / divisor
        return isFinite(n) ? String(parseFloat(n.toFixed(decimals))) : "?"
    }
    function nudge(dir) {
        var cur = Number(value)
        var v = Math.max(min, Math.min(max, cur + dir * step))
        if (v !== cur) edited(v)
    }
    function validHex(s) { return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(s) }

    readonly property bool boolValue: value === true || value === "true"
    readonly property bool atDefault: same(value, defaultValue)
    readonly property real span: Math.max(1e-9, max - min)
    readonly property real frac: Math.max(0, Math.min(1, (Number(value) - min) / span))
    readonly property real defFrac: Math.max(0, Math.min(1, (Number(defaultValue) - min) / span))

    implicitWidth: 400
    implicitHeight: col.implicitHeight
    opacity: dimmed ? 0.4 : 1.0
    Behavior on opacity { enabled: ui.animations; NumberAnimation { duration: 140 } }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: ui.px(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: ui.px(10)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: root.label
                    font.pixelSize: ui.fs(12)
                    font.weight: Font.DemiBold
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    visible: root.hint !== ""
                    text: root.hint
                    font.pixelSize: ui.fs(10)
                    opacity: 0.55
                    wrapMode: Text.Wrap
                }
            }

            Txt {
                ui: root.ui
                visible: root.kind === "int"
                text: root.show(root.value)
                font.pixelSize: ui.fs(12)
                font.weight: Font.DemiBold
            }

            // reset arrow, only once it differs from the default
            Rectangle {
                visible: !root.atDefault
                implicitWidth: ui.px(22); implicitHeight: ui.px(22)
                radius: Math.max(2, ui.radius * 0.5)
                color: ui.tint(resetArea.containsMouse ? 0.18 : 0.08)
                Txt { ui: root.ui; anchors.centerIn: parent; text: "\u21BA"; font.pixelSize: ui.fs(12) }
                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.edited(root.defaultValue)
                }
            }

            // switch
            Rectangle {
                visible: root.kind === "bool"
                implicitWidth: ui.px(36); implicitHeight: ui.px(20); radius: height / 2
                color: root.boolValue ? ui.accent : ui.tint(0.18)
                Behavior on color { enabled: ui.animations; ColorAnimation { duration: 100 } }
                Rectangle {
                    width: parent.height - 6; height: width; radius: width / 2
                    y: 3
                    x: root.boolValue ? parent.width - width - 3 : 3
                    color: root.boolValue ? ui.accentText : ui.fg
                    Behavior on x { enabled: ui.animations; NumberAnimation { duration: 110 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.edited(!root.boolValue)
                }
            }
        }

        // enum chips
        Flow {
            Layout.fillWidth: true
            visible: root.kind === "enum"
            spacing: ui.px(6)
            Repeater {
                model: root.kind === "enum" ? root.options : []
                delegate: Chip {
                    ui: root.ui
                    label: root.labelFor(modelData)
                    on: root.same(root.value, modelData)
                    onClicked: root.edited(modelData)
                }
            }
        }

        // slider
        RowLayout {
            Layout.fillWidth: true
            visible: root.kind === "int"
            spacing: ui.px(8)

            Btn { ui: root.ui; text: "\u2212"; implicitWidth: ui.px(26); onClicked: root.nudge(-1) }

            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: ui.px(22)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2
                    color: ui.tint(0.14)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * root.frac; height: 4; radius: 2
                    color: ui.accent
                }
                Rectangle {   // notch at the default
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * root.defFrac - 1
                    width: 2; height: 10
                    color: ui.tint(0.45)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, parent.width * root.frac - width / 2))
                    width: ui.px(14); height: width; radius: width / 2
                    color: ui.accent
                    border.width: 2
                    border.color: ui.surface
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function apply(mx) {
                        var f = Math.max(0, Math.min(1, mx / width))
                        var raw = root.min + f * root.span
                        var snapped = root.min + Math.round((raw - root.min) / root.step) * root.step
                        snapped = Math.max(root.min, Math.min(root.max, snapped))
                        if (snapped !== Number(root.value)) root.edited(snapped)
                    }
                    onPressed: function(m) { apply(m.x) }
                    onPositionChanged: function(m) { if (pressed) apply(m.x) }
                }
            }

            Btn { ui: root.ui; text: "+"; implicitWidth: ui.px(26); onClicked: root.nudge(1) }
        }

        // text field
        Rectangle {
            Layout.fillWidth: true
            visible: root.kind === "string" || root.kind === "color"
            implicitHeight: ui.px(30)
            radius: Math.max(2, ui.radius * 0.6)
            color: ui.tint(0.06)
            border.width: 1
            border.color: field.activeFocus ? ui.accent : ui.tint(0.12)
            clip: true

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: ui.px(10)
                anchors.rightMargin: ui.px(10)
                verticalAlignment: TextInput.AlignVCenter
                color: ui.fg
                selectionColor: ui.accent
                selectedTextColor: ui.accentText
                font.family: ui.fontName
                font.pixelSize: ui.fs(12)
                text: root.str(root.value)
                maximumLength: 2048
                selectByMouse: true
                onEditingFinished: {
                    if (root.kind === "color" && !root.validHex(text)) { text = root.str(root.value); return }
                    if (text !== root.str(root.value)) root.edited(text)
                }
                Keys.onEscapePressed: { text = root.str(root.value); focus = false }
            }
        }

        // string presets
        Flow {
            Layout.fillWidth: true
            visible: root.kind === "string" && root.presets.length > 0
            spacing: ui.px(6)
            Repeater {
                model: root.kind === "string" ? root.presets : []
                delegate: Chip {
                    ui: root.ui
                    label: String(modelData).trim() === "" ? "(none)" : String(modelData)
                    on: root.same(root.value, modelData)
                    onClicked: root.edited(modelData)
                }
            }
        }

        // color swatches
        Flow {
            Layout.fillWidth: true
            visible: root.kind === "color"
            spacing: ui.px(8)
            Repeater {
                model: root.kind === "color" ? root.presets : []
                delegate: Rectangle {
                    width: ui.px(24); height: width; radius: width / 2
                    color: modelData
                    border.width: root.same(root.value, modelData) ? 2 : 1
                    border.color: root.same(root.value, modelData) ? ui.fg : ui.tint(0.25)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.edited(modelData)
                    }
                }
            }
        }
    }
}
