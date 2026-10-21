import QtQuick
import Quickshell

// The same manager, as a normal window you can move, resize and tile.
// BarWidget.qml creates it on "Pop out" and destroys it on "Dock".
//
// To make Hyprland float and center it (it tiles by default), add window rules
// that match the title "Omanager"; see the README.
FloatingWindow {
    id: win

    property var ui: null

    title: "Omanager"
    visible: false
    color: "transparent"
    implicitWidth: ui ? ui.cfgSafe.windowWidth : 560
    implicitHeight: ui ? ui.cfgSafe.windowHeight : 680

    Loader {
        anchors.fill: parent
        active: win.ui !== null
        sourceComponent: Component { ManagerView { ui: win.ui; focus: true } }
    }
}
