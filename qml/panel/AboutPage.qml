import QtQuick
import QtQuick.Layouts
import "../controls"

// The About tab: the logo, the name and version, who made it, and where to find
// more plugins by the same author.
Item {
    id: root

    property var ui: null

    readonly property string version: {
        const m = ui && ui.service ? ui.service.manifest : null
        return m && m.version ? String(m.version) : ""
    }
    // the author's plugins, in one place
    readonly property string moreUrl: "https://github.com/qempexe?tab=repositories&q=omarchy"

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -ui.px(16)
        spacing: ui.px(6)

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: ui.px(96)
            Layout.preferredHeight: ui.px(96)
            // the light logo on a dark window, the dark one on a light window
            source: Qt.resolvedUrl(root.ui.lightText ? "../../assets/logo.png" : "../../assets/logo-dark.png")
            sourceSize.width: 192
            sourceSize.height: 192
            smooth: true
            mipmap: true
        }

        Txt {
            ui: root.ui
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: ui.px(8)
            text: "OMANAGER"
            font.pixelSize: ui.fs(19)
            font.weight: Font.DemiBold
            font.letterSpacing: 4
        }

        Txt {
            ui: root.ui
            Layout.alignment: Qt.AlignHCenter
            visible: root.version !== ""
            text: "Version " + root.version
            color: ui.accent
            font.pixelSize: ui.fs(11)
            font.letterSpacing: 1.5
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: ui.px(12)
            Txt { ui: root.ui; text: "made with "; opacity: 0.75; font.pixelSize: ui.fs(12) }
            Txt { ui: root.ui; text: "♥"; color: ui.accent; font.pixelSize: ui.fs(13); anchors.verticalCenter: parent.verticalCenter }
            Txt { ui: root.ui; text: " by qempexe"; opacity: 0.75; font.pixelSize: ui.fs(12) }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: ui.px(10)
            implicitWidth: moreText.implicitWidth + ui.px(28)
            implicitHeight: ui.px(30)
            radius: ui.r(1.5)
            color: moreArea.containsMouse ? ui.accentTint(0.22) : ui.tint(0.07)
            border.width: 1
            border.color: ui.accentTint(moreArea.containsMouse ? 0.8 : 0.35)
            Behavior on color { enabled: ui.animations; ColorAnimation { duration: 100 } }

            Txt {
                id: moreText
                ui: root.ui
                anchors.centerIn: parent
                text: "Check out my other plugins ↗"
                font.pixelSize: ui.fs(11)
            }
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.ui.service) root.ui.service.openUrl(root.moreUrl)
            }
        }
    }
}
