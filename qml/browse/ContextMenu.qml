import QtQuick
import QtQuick.Layouts
import "../js/Model.js" as Model
import "../controls"

// Right-click menu for a plugin. Hand-rolled (the shell draws no native menus):
// a full-size catcher that closes on any outside click, and a small card of
// actions anchored near the pointer and clamped inside the panel. The action set
// is whatever applies to the plugin's current state, so it stays short.
Item {
    id: root

    property var ui: null
    readonly property var menu: ui ? ui.menu : null
    readonly property var p: menu !== null ? menu.p : null
    readonly property bool busy: !!(ui.service && p && ui.service.busyIds[p.id])

    visible: menu !== null

    // whole-panel catcher: any click closes the menu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: ui.closeMenu()
        onWheel: function(w) { w.accepted = true }
    }

    // Each action keeps its own copy of the plugin and its state: closing the menu
    // clears ui.menu (and with it root.p), so reading root.p when the action runs
    // would find nothing. The action runs first, and the menu closes after it.
    readonly property var actions: {
        const plugin = root.p
        if (!plugin || !ui) return []
        const state = ui.stateOf(plugin)
        const svc = ui.service
        const act = fn => () => { fn(); ui.closeMenu() }
        const list = []
        if (state.update)
            list.push({ label: "Update", tone: "accent", run: act(() => ui.requestAction("update", plugin)) })
        else if (!state.installed && !plugin.builtin && plugin.repo !== "" && plugin.installable)
            list.push({ label: "Install", tone: "accent", run: act(() => ui.requestAction("install", plugin)) })
        if (state.installed)
            list.push({ label: state.enabled ? "Disable" : "Enable",
                        run: act(() => ui.requestAction(state.enabled ? "disable" : "enable", plugin)) })
        list.push({ label: svc && svc.bookmarks[plugin.id] ? "Unsave" : "Save", run: act(() => svc.toggleBookmark(plugin.id)) })
        if (state.installed && state.dir !== "")
            list.push({ label: "Open folder", run: act(() => svc.openPluginDir(state.dir)) })
        if (plugin.repo !== "")
            list.push({ label: "Open repository", run: act(() => svc.openUrl(plugin.repo)) })
        if (plugin.repo !== "" && !state.installed && !plugin.builtin)
            list.push({ label: "Copy install command", run: act(() => svc.copyText(Model.installCommand(plugin))) })
        list.push({ label: "Show details", run: act(() => ui.openDetail(plugin)) })
        if (state.installed && !plugin.builtin)
            list.push({ label: "Remove", tone: "danger", run: act(() => ui.requestAction("remove", plugin)) })
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
