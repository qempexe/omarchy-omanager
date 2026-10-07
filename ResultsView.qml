import QtQuick
import QtQuick.Layouts

// The scrolling grid / list of plugins, plus the empty / loading / error states.
Item {
    id: root

    property var ui: null

    readonly property bool asList: ui.viewMode !== "grid"
    readonly property bool shots: !asList && ui.cfgSafe.showPreviews
    // Auto columns: as many ~300px cards as fit (1 in the docked panel, more in a wide window).
    readonly property int cols: asList ? 1
        : (ui.cfgSafe.columns === "auto" ? Math.max(1, Math.floor(width / ui.px(300))) : Number(ui.cfgSafe.columns))
    // Screenshot height follows the card width (16:9), capped so wide cards don't get huge.
    readonly property real shotH: Math.min(ui.px(150), Math.max(ui.px(64), (width / cols - ui.px(10)) * 9 / 16))

    function focusGrid() { grid.forceActiveFocus() }

    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        model: ui.items
        cellWidth: Math.floor(width / root.cols)
        cellHeight: root.asList ? ui.px(74) : (root.shots ? root.shotH + ui.px(188) : ui.px(176))
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        cacheBuffer: 400

        delegate: PluginCard {
            width: grid.cellWidth
            height: grid.cellHeight
            ui: root.ui
            p: modelData
            list: root.asList
            shotHeight: root.shotH
            current: ui.selected !== null && ui.selected.id === modelData.id
            onOpened: ui.openDetail(modelData)
        }

        Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < ui.items.length) ui.openDetail(ui.items[currentIndex])
        Keys.onEnterPressed: if (currentIndex >= 0 && currentIndex < ui.items.length) ui.openDetail(ui.items[currentIndex])

        // slim scroll indicator
        Rectangle {
            visible: grid.contentHeight > grid.height
            anchors.right: parent.right
            width: 3; radius: 2
            color: ui.tint(0.28)
            y: grid.height * grid.visibleArea.yPosition
            height: Math.max(24, grid.height * grid.visibleArea.heightRatio)
        }
    }

    // empty / loading / error
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 420)
        spacing: ui.px(10)
        visible: ui.items.length === 0

        Txt {
            ui: root.ui
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: ui.fs(14)
            text: ui.emptyTitle
        }
        Txt {
            ui: root.ui
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            opacity: 0.55
            text: ui.emptyHint
            visible: text !== ""
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: ui.px(8)
            Btn {
                ui: root.ui
                visible: ui.filtersActive
                text: "Reset filters"
                onClicked: ui.resetFilters()
            }
            Btn {
                ui: root.ui
                visible: ui.service && ui.service.catalogState === "error"
                kind: "primary"
                text: "Try again"
                onClicked: ui.service.refresh(true)
            }
        }
    }
}
