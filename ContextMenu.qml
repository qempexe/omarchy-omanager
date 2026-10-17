import QtQuick
import QtQuick.Layouts
import "Model.js" as Model

// Right-click menu for a plugin. Hand-rolled (the shell draws no native menus):
// a full-size catcher that closes on any outside click, and a small card of
// actions anchored near the pointer and clamped inside the panel. The action set
// is whatever applies to the plugin's current state, so it stays short.
Item {
    id: root

    property var ui: null
    readonly property var menu: ui ? ui.menu : null
    readonly property var p: menu !== null ? menu.p : null
    readonly property var st: p !== null ? ui.stateOf(p) : null
    readonly property bool busy: !!(ui.service && p && ui.service.busyIds[p.id])

    visible: menu !== null

    // whole-panel catcher: any click closes the menu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: ui.closeMenu()
        onWheel: function(w) { w.accepted = true }
    }

    function act(fn) { return function() { ui.closeMenu(); fn() } }

    readonly property var actions: {
        var list = []
        if (!p) return list
        if (st.update) list.push({ label: "Update", tone: "accent", run: act(function() { ui.requestAction("update", p) }) })
        else if (!st.installed && !p.builtin && p.repo !== "" && p.installable)
            list.push({ label: "Install", tone: "accent", run: act(function() { ui.requestAction("install", p) }) })
        if (st.installed)
            list.push({ label: st.enabled ? "Disable" : "Enable", run: act(function() { ui.requestAction(st.enabled ? "disable" : "enable", p) }) })
        list.push({ label: ui.service && ui.service.bookmarks[p.id] ? "Unsave" : "Save", run: act(function() { ui.service.toggleBookmark(p.id) }) })
        if (st.installed && st.dir !== "")
            list.push({ label: "Open folder", run: act(function() { ui.service.openPluginDir(st.dir) }) })
        if (p.repo !== "")
            list.push({ label: "Open repository", run: act(function() { ui.service.openUrl(p.repo) }) })
        if (p.repo !== "" && !st.installed)
            list.push({ label: "Copy install command", run: act(function() { ui.service.copyText(Model.installCommand(p)) }) })
        list.push({ label: "Show details", run: act(function() { ui.openDetail(p) }) })
        if (st.installed && !p.builtin)
            list.push({ label: "Remove", tone: "danger", run: act(function() { ui.requestAction("remove", p) }) })
        return list
    }

    // Scene coordinates from the card's MouseArea, mapped into this overlay.
    readonly property var at: menu !== null ? root.mapFromItem(null, menu.x, menu.y) : Qt.point(0, 0)

    Rectangle {
        id: box
        visible: root.menu !== null
        width: ui.px(186)
        implicitHeight: col.implicitHeight + ui.px(10)
        radius: ui.r(1.5)
        color: ui.surface
        border.width: 1
        border.color: ui.tint(0.20)
        // keep the card inside the panel: slide it back in at the edges
        x: Math.max(ui.px(4), Math.min(root.at.x, root.width - width - ui.px(4)))
        y: Math.max(ui.px(4), Math.min(root.at.y, root.height - implicitHeight - ui.px(4)))
        opacity: 0.99

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: ui.px(5)
            spacing: 0

            Repeater {
                model: root.actions
                delegate: Rectangle {
                    width: col.width
                    height: ui.px(28)
                    color: rowArea.containsMouse ? ui.tint(0.08) : "transparent"
                    Txt {
                        ui: root.ui
                        anchors.left: parent.left
                        anchors.leftMargin: ui.px(12)
                        anchors.right: parent.right
                        anchors.rightMargin: ui.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        elide: Text.ElideRight
                        color: modelData.tone === "danger" ? ui.bad : (modelData.tone === "accent" ? ui.accent : ui.fg)
                        font.pixelSize: ui.fs(11)
                        font.weight: modelData.tone ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData.run) modelData.run()
                    }
                }
            }
        }
    }
}
