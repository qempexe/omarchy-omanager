import QtQuick
import QtQuick.Layouts
import "Model.js" as Model

// One plugin, as a card (grid), a row (list) or a dense table row (compact).
// Everything shown here comes from the catalog and is treated as plain text.
Item {
    id: root

    property var ui: null
    property var p: null
    property bool list: false
    property bool compact: false
    property bool current: false
    property real shotHeight: ui.px(150)
    readonly property bool narrow: width < ui.px(230)

    signal opened()

    readonly property var st: ui.stateOf(p)
    readonly property color tone: ui.tone(p.category)
    readonly property bool isNew: p.addedAt > 0 && (ui.now - p.addedAt) < ui.cfgSafe.newBadgeDays * 86400000
    readonly property bool showShot: !list && !compact && ui.cfgSafe.showPreviews
    readonly property bool gridShotShown: showShot && p.preview !== "" && gridImg.status !== Image.Error
    readonly property bool listShotShown: list && ui.cfgSafe.showPreviews && p.preview !== "" && listImg.status !== Image.Error
    readonly property string action: st.update ? "update" : (!st.installed && !p.builtin && p.repo !== "" && p.installable ? "install" : "")
    readonly property bool saved: ui.service && ui.service.bookmarks[p.id] === true
    readonly property string stats: (p.builtin || p.local) ? "" : [
        "\u2605 " + Model.fmtCount(p.stars), "\u2665 " + Model.fmtCount(p.hearts),
        "\u25CE " + Model.fmtCount(p.views), "\u2750 " + Model.fmtCount(p.copies)
    ].join("   ")
    readonly property string when: p.updatedAt > 0 ? "upgraded " + Model.relTime(p.updatedAt, ui.now)
                                 : (p.addedAt > 0 ? "added " + Model.relTime(p.addedAt, ui.now) : "")
    readonly property string meta: stats !== "" && when !== "" ? stats + "   " + when : stats + when

    // ---- card chrome ---------------------------------------------------------
    Rectangle {
        id: body
        anchors.fill: parent
        anchors.margins: root.compact ? 0 : ui.px(5)
        radius: root.compact ? 0 : ui.radius
        clip: true
        color: root.compact
            ? (area.containsMouse ? ui.tint(0.08) : "transparent")
            : (ui.cardStyle === "soft" ? ui.tint(area.containsMouse ? 0.09 : 0.045) : (area.containsMouse ? ui.tint(0.04) : "transparent"))
        border.width: root.compact ? 0 : (root.current ? 2 : (ui.cardStyle === "flat" ? 0 : 1))
        border.color: root.compact ? "transparent"
            : (root.current ? ui.accent : ui.tint(area.containsMouse ? 0.25 : 0.10))
        Behavior on color { enabled: ui.animations; ColorAnimation { duration: 100 } }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }

        // ---------- grid layout ----------
        ColumnLayout {
            visible: !root.list && !root.compact
            anchors.fill: parent
            spacing: 0

            Rectangle {
                visible: root.showShot
                Layout.fillWidth: true
                Layout.preferredHeight: root.shotHeight
                color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.12)
                clip: true

                Image {
                    id: gridImg
                    anchors.fill: parent
                    source: root.showShot ? p.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 480
                    sourceSize.height: 270
                    visible: status === Image.Ready
                    opacity: ui.cfgSafe.colorMode === "mono" ? 0.85 : 1.0
                }
                Txt {
                    ui: root.ui
                    anchors.centerIn: parent
                    visible: !root.gridShotShown
                    text: p.name.charAt(0).toUpperCase()
                    color: root.tone
                    font.pixelSize: ui.fs(40)
                    font.weight: Font.Light
                    opacity: 0.55
                }
                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: ui.px(6)
                    spacing: ui.px(4)
                    Rectangle {
                        visible: root.isNew
                        implicitWidth: newLbl.implicitWidth + ui.px(10); implicitHeight: ui.px(16); radius: 3
                        color: ui.accent
                        Txt { id: newLbl; ui: root.ui; anchors.centerIn: parent; text: "NEW"; color: ui.accentText; font.pixelSize: ui.fs(9); font.weight: Font.Bold }
                    }
                    Rectangle {
                        visible: root.st.update
                        implicitWidth: updLbl.implicitWidth + ui.px(10); implicitHeight: ui.px(16); radius: 3
                        color: ui.warn
                        Txt { id: updLbl; ui: root.ui; anchors.centerIn: parent; text: "UPDATE"; color: ui.warnText; font.pixelSize: ui.fs(9); font.weight: Font.Bold }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: ui.px(10)
                spacing: ui.px(3)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(6)
                    Txt {
                        ui: root.ui
                        Layout.fillWidth: true
                        text: p.name
                        font.pixelSize: ui.fs(13)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Txt {
                        ui: root.ui
                        visible: p.verified
                        text: root.narrow ? "\u2713" : "\u2713 Verified"
                        color: ui.good
                        font.pixelSize: ui.fs(9)
                    }
                    Txt {
                        ui: root.ui
                        text: root.saved ? "\u2605" : "\u2606"
                        color: root.saved ? ui.accent : ui.fg
                        opacity: root.saved ? 1 : 0.4
                        font.pixelSize: ui.fs(14)
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ui.service.toggleBookmark(p.id)
                        }
                    }
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: (p.author !== "" ? "by " + p.author : "") + (p.author !== "" ? " \u00B7 " : "") + p.category
                    font.pixelSize: ui.fs(10)
                    opacity: 0.55
                    elide: Text.ElideRight
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: p.description
                    font.pixelSize: ui.fs(11)
                    opacity: 0.8
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.showShot ? 2 : 4
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(6)
                    Txt {
                        id: gridStats
                        ui: root.ui
                        Layout.fillWidth: true
                        text: root.stats
                        font.pixelSize: ui.fs(10)
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                    Txt {
                        ui: root.ui
                        visible: root.st.installed
                        text: ui.service && ui.service.busyIds[p.id] ? ui.service.busyIds[p.id] + "\u2026"
                              : (root.st.enabled ? "\u25CF Enabled" : "\u25CB Disabled")
                        font.pixelSize: ui.fs(10)
                        opacity: 0.8
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(6)
                    Txt {
                        ui: root.ui
                        Layout.fillWidth: true
                        text: root.when
                        font.pixelSize: ui.fs(10)
                        opacity: 0.5
                        elide: Text.ElideRight
                    }
                    Btn {
                        ui: root.ui
                        visible: root.action !== "" && !(ui.service && ui.service.busyIds[p.id])
                        kind: "primary"
                        text: root.action === "update" ? "Update" : "Install"
                        implicitHeight: ui.px(24)
                        onClicked: ui.requestAction(root.action, p)
                    }
                }
            }
        }

        // ---------- list layout (also the left column of "List + stage") ----------
        RowLayout {
            visible: root.list && !root.compact
            anchors.fill: parent
            anchors.margins: ui.px(8)
            spacing: ui.px(10)

            Rectangle {
                Layout.preferredWidth: ui.px(72)
                Layout.preferredHeight: ui.px(40)
                Layout.alignment: Qt.AlignVCenter
                radius: Math.max(2, ui.radius * 0.6)
                color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.14)
                clip: true
                Image {
                    id: listImg
                    anchors.fill: parent
                    source: (root.list && ui.cfgSafe.showPreviews) ? p.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 288
                    sourceSize.height: 160
                    visible: status === Image.Ready
                }
                Txt {
                    ui: root.ui
                    anchors.centerIn: parent
                    visible: !root.listShotShown
                    text: p.name.charAt(0).toUpperCase()
                    color: root.tone
                    font.pixelSize: ui.fs(18)
                    font.weight: Font.Light
                    opacity: 0.7
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(6)
                    Txt { ui: root.ui; Layout.fillWidth: true; text: p.name; font.pixelSize: ui.fs(12); font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Txt { ui: root.ui; visible: p.verified; text: "\u2713"; color: ui.good; font.pixelSize: ui.fs(11) }
                    Txt { ui: root.ui; visible: root.isNew; text: "NEW"; color: ui.accent; font.pixelSize: ui.fs(9); font.weight: Font.Bold }
                    Txt { ui: root.ui; visible: root.st.update; text: "UPDATE"; color: ui.warn; font.pixelSize: ui.fs(9); font.weight: Font.Bold }
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: p.category + (p.author !== "" ? "  \u00B7  " + p.author : "")
                    font.pixelSize: ui.fs(10)
                    opacity: 0.55
                    elide: Text.ElideRight
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    visible: root.meta !== ""
                    text: root.meta
                    font.pixelSize: ui.fs(10)
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }
            Txt {
                ui: root.ui
                visible: root.st.installed && root.width > ui.px(420)
                text: root.st.enabled ? "\u25CF Enabled" : "\u25CB Disabled"
                font.pixelSize: ui.fs(10)
                opacity: 0.8
            }
            Btn {
                ui: root.ui
                visible: root.action !== "" && !(ui.service && ui.service.busyIds[p.id])
                kind: "primary"
                text: root.action === "update" ? "Update" : "Install"
                implicitHeight: ui.px(24)
                onClicked: ui.requestAction(root.action, p)
            }
            Txt {
                ui: root.ui
                text: root.saved ? "\u2605" : "\u2606"
                color: root.saved ? ui.accent : ui.fg
                opacity: root.saved ? 1 : 0.4
                font.pixelSize: ui.fs(15)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ui.service.toggleBookmark(p.id)
                }
            }
        }

        // ---------- compact layout (dense table row) ----------
        RowLayout {
            visible: root.compact
            anchors.fill: parent
            anchors.leftMargin: ui.px(8)
            anchors.rightMargin: ui.px(8)
            spacing: ui.px(8)

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: ui.px(6); height: width; radius: width / 2
                color: root.tone
            }

            Txt {
                ui: root.ui
                Layout.fillWidth: true
                Layout.minimumWidth: ui.px(60)
                text: p.name
                font.pixelSize: ui.fs(11)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Txt {
                ui: root.ui
                visible: root.width > ui.px(360)
                Layout.preferredWidth: ui.px(80)
                text: p.category
                font.pixelSize: ui.fs(10)
                opacity: 0.55
                elide: Text.ElideRight
            }

            Txt {
                ui: root.ui
                visible: root.width > ui.px(500)
                Layout.preferredWidth: ui.px(90)
                text: p.author !== "" ? "by " + p.author : ""
                font.pixelSize: ui.fs(10)
                opacity: 0.55
                elide: Text.ElideRight
            }

            Txt {
                ui: root.ui
                visible: root.width > ui.px(700)
                Layout.preferredWidth: ui.px(160)
                text: root.stats
                font.pixelSize: ui.fs(9)
                opacity: 0.6
                elide: Text.ElideRight
            }

            Txt {
                ui: root.ui
                visible: p.verified
                text: "\u2713"
                color: ui.good
                font.pixelSize: ui.fs(11)
            }

            Txt {
                ui: root.ui
                visible: root.isNew
                text: "NEW"
                color: ui.accent
                font.pixelSize: ui.fs(9)
                font.weight: Font.Bold
            }

            Txt {
                ui: root.ui
                visible: root.st.update
                text: "UPDATE"
                color: ui.warn
                font.pixelSize: ui.fs(9)
                font.weight: Font.Bold
            }

            Txt {
                ui: root.ui
                visible: root.st.installed
                text: root.st.enabled ? "\u25CF" : "\u25CB"
                color: root.st.enabled ? ui.good : ui.fg
                font.pixelSize: ui.fs(10)
                opacity: 0.8
            }

            Txt {
                ui: root.ui
                visible: root.width > ui.px(500)
                Layout.preferredWidth: ui.px(74)
                text: root.when
                font.pixelSize: ui.fs(9)
                opacity: 0.5
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            Txt {
                ui: root.ui
                text: root.saved ? "\u2605" : "\u2606"
                color: root.saved ? ui.accent : ui.fg
                opacity: root.saved ? 1 : 0.4
                font.pixelSize: ui.fs(13)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ui.service.toggleBookmark(p.id)
                }
            }

            Btn {
                ui: root.ui
                visible: root.action !== "" && !(ui.service && ui.service.busyIds[p.id])
                kind: "primary"
                text: root.action === "update" ? "Update" : "Install"
                implicitHeight: ui.px(20)
                implicitWidth: ui.px(58)
                onClicked: ui.requestAction(root.action, p)
            }
        }

        // thin separator between compact rows
        Rectangle {
            visible: root.compact
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: ui.tint(0.06)
        }
    }
}
