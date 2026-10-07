import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The bar-panel surface. Follows the Omarchy panel contract (Panel +
// KeyboardPanel + PanelKeyCatcher); BarWidget.qml forwards open/close/toggle.
// All real content is ManagerView.qml, which PopoutWindow.qml reuses.
Panel {
    id: root

    moduleName: "io.github.qempexe.omanager"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var ui: null          // shared UiState, injected by BarWidget.qml

    function open() { root.controller.show() }
    function close() { root.controller.hide() }
    // Our own toggle, so we never depend on a base-class toggle() we can't see.
    function toggle() { if (root.opened) root.close(); else root.open() }

    // Size helpers that cannot leave the panel at 0x0 if the shell helper is
    // missing or renamed: an unsized panel is invisible, which looks like
    // "nothing happens when I click the button".
    function scaled(v) {
        return (typeof Style.space === "function") ? Style.space(v) : v
    }
    function fitW(v) {
        var s = scaled(v)
        return (typeof panel.fittedContentWidth === "function") ? panel.fittedContentWidth(s) : s
    }
    function fitH(v) {
        var s = scaled(v)
        return (typeof panel.fittedContentHeight === "function") ? panel.fittedContentHeight(s) : s
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: root.fitW(root.ui ? root.ui.cfgSafe.windowWidth : 1040)
        contentHeight: root.fitH(root.ui ? root.ui.cfgSafe.windowHeight : 700)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: {
                // Esc first steps back out of dialogs / detail panes, then closes.
                if (!viewLoader.item || !viewLoader.item.stepBack()) root.close()
            }
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Loader {
                id: viewLoader
                anchors.fill: parent
                active: root.ui !== null
                sourceComponent: Component { ManagerView { ui: root.ui } }
            }
        }
    }
}
