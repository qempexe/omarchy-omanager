import QtQuick
import QtQuick.Layouts

// Titled group of chips / controls in the sidebar.
ColumnLayout {
    id: root

    property var ui: null
    property string title: ""
    default property alias content: box.data

    Layout.fillWidth: true
    spacing: ui.px(6)

    Txt {
        ui: root.ui
        text: root.title.toUpperCase()
        font.pixelSize: ui.fs(9)
        font.letterSpacing: 1
        font.weight: Font.DemiBold
        opacity: 0.45
    }
    Flow {
        id: box
        Layout.fillWidth: true
        spacing: ui.px(6)
    }
}
