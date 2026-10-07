import QtQuick
import QtQuick.Layouts
import "Model.js" as Model

// Slide-in details for one plugin, with every action that applies to it.
Rectangle {
    id: root

    property var ui: null
    property var p: null
    property bool inline: false          // true = the permanent stage, false = slide-in overlay

    readonly property var st: p ? ui.stateOf(p) : ({ installed: false, enabled: false, update: false, version: "" })
    readonly property bool working: p && ui.service && ui.service.busyIds[p.id] !== undefined
    readonly property bool saved: p && ui.service && ui.service.bookmarks[p.id] === true
    readonly property string cmd: p ? Model.installCommand(p) : ""

    color: inline ? "transparent" : ui.surface
    border.width: inline ? 0 : 1
    border.color: ui.tint(0.16)
    radius: ui.radius

    MouseArea { anchors.fill: parent; enabled: !root.inline; acceptedButtons: Qt.AllButtons; onWheel: function(w) { w.accepted = true } }

    Txt {
        ui: root.ui
        anchors.centerIn: parent
        visible: !root.p
        text: "Nothing to show."
        opacity: 0.4
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: root.inline ? ui.px(4) : ui.px(14)
        visible: root.p !== null
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: flick.width
            spacing: ui.px(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: ui.px(8)
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: root.p ? root.p.name : ""
                    font.pixelSize: ui.fs(18)
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Btn { ui: root.ui; visible: !root.inline; text: "\u2715"; implicitWidth: ui.px(28); onClicked: ui.selected = null }
            }

            Txt {
                ui: root.ui
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: 0.6
                text: root.p ? ((root.p.author !== "" ? "by " + root.p.author + "  \u00B7  " : "") + root.p.category
                                + (root.p.version !== "" ? "  \u00B7  v" + root.p.version : "")) : ""
            }

            Row {
                spacing: ui.px(8)
                Txt { ui: root.ui; visible: root.p && root.p.verified; text: "\u2713 Verified"; color: ui.good }
                Txt { ui: root.ui; visible: root.p && !root.p.verified && !root.p.builtin && !root.p.local; text: "Unverified"; color: ui.warn }
                Txt { ui: root.ui; visible: root.st.installed; text: root.st.enabled ? "\u25CF Enabled" : "\u25CB Disabled" }
                Txt { ui: root.ui; visible: root.st.update; text: "Update: v" + root.st.version + " \u2192 v" + (root.p ? root.p.version : ""); color: ui.warn }
            }

            // preview: 16:9, the large image; falls back to the thumbnail, then an initial
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(ui.px(root.inline ? 330 : 200), width * 9 / 16)
                visible: ui.cfgSafe.showPreviews
                radius: Math.max(2, ui.radius)
                color: root.p ? Qt.rgba(ui.tone(root.p.category).r, ui.tone(root.p.category).g, ui.tone(root.p.category).b, 0.12) : ui.tint(0.05)
                border.width: 1
                border.color: ui.tint(0.10)
                clip: true
                Image {
                    id: bigImg
                    anchors.fill: parent
                    source: (ui.cfgSafe.showPreviews && root.p) ? root.p.previewFull : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 1280
                    sourceSize.height: 720
                    visible: status === Image.Ready
                }
                Txt {
                    ui: root.ui
                    anchors.centerIn: parent
                    visible: bigImg.status !== Image.Ready
                    text: bigImg.status === Image.Loading ? "Loading preview\u2026"
                          : (root.p ? root.p.name.charAt(0).toUpperCase() : "")
                    font.pixelSize: bigImg.status === Image.Loading ? ui.fs(11) : ui.fs(54)
                    font.weight: Font.Light
                    opacity: 0.4
                }
            }

            Txt {
                ui: root.ui
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: ui.fs(12)
                text: root.p && root.p.description !== "" ? root.p.description : "No description."
            }

            // actions
            Flow {
                Layout.fillWidth: true
                spacing: ui.px(6)
                Btn {
                    ui: root.ui; kind: "primary"; text: "Install"
                    visible: root.p && !root.st.installed && !root.p.builtin && root.p.repo !== "" && root.p.installable
                    enabled: !root.working
                    onClicked: ui.requestAction("install", root.p)
                }
                Btn {
                    ui: root.ui; kind: "primary"; text: "Update"
                    visible: root.st.update
                    enabled: !root.working
                    onClicked: ui.requestAction("update", root.p)
                }
                Btn {
                    ui: root.ui; text: root.st.enabled ? "Disable" : "Enable"
                    visible: root.st.installed
                    enabled: !root.working
                    onClicked: ui.requestAction(root.st.enabled ? "disable" : "enable", root.p)
                }
                Btn {
                    ui: root.ui; kind: "danger"; text: "Remove"
                    visible: root.st.installed && root.p && !root.p.builtin
                    enabled: !root.working
                    onClicked: ui.requestAction("remove", root.p)
                }
                Btn {
                    ui: root.ui; text: root.saved ? "\u2605 Saved" : "\u2606 Save"
                    active: root.saved
                    onClicked: ui.service.toggleBookmark(root.p.id)
                }
                Btn {
                    ui: root.ui; text: "Copy install command"
                    visible: root.cmd !== ""
                    onClicked: ui.service.copyText(root.cmd)
                }
                Btn {
                    ui: root.ui; text: "Open repository"
                    visible: root.p && root.p.repo !== ""
                    onClicked: ui.service.openUrl(root.p.repo)
                }
            }

            Txt {
                ui: root.ui
                visible: root.working
                text: root.working ? ui.service.busyIds[root.p.id] + "\u2026" : ""
                opacity: 0.7
            }

            // numbers
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: ui.px(12)
                rowSpacing: ui.px(4)
                visible: root.p && !root.p.builtin && !root.p.local

                Txt { ui: root.ui; text: "Uploaded"; opacity: 0.5 }
                Txt { ui: root.ui; text: root.p ? Model.relTime(root.p.addedAt, ui.now) : "" }
                Txt { ui: root.ui; text: "Upgraded"; opacity: 0.5 }
                Txt { ui: root.ui; text: root.p ? Model.relTime(root.p.updatedAt, ui.now) : "" }
                Txt { ui: root.ui; text: "Stars"; opacity: 0.5 }
                Txt { ui: root.ui; text: root.p ? Model.fmtCount(root.p.stars) : "" }
                Txt { ui: root.ui; text: "Hearts"; opacity: 0.5 }
                Txt { ui: root.ui; text: root.p ? Model.fmtCount(root.p.hearts) : "" }
                Txt { ui: root.ui; text: "Views"; opacity: 0.5 }
                Txt { ui: root.ui; text: root.p ? Model.fmtCount(root.p.views) : "" }
                Txt { ui: root.ui; text: "Copied"; opacity: 0.5 }
                Txt { ui: root.ui; text: root.p ? Model.fmtCount(root.p.copies) : "" }
                Txt { ui: root.ui; text: "Id"; opacity: 0.5 }
                Txt { ui: root.ui; Layout.fillWidth: true; text: root.p ? root.p.id : ""; elide: Text.ElideRight }
            }

            Flow {
                Layout.fillWidth: true
                spacing: ui.px(6)
                visible: root.p && root.p.tags.length > 0
                Repeater {
                    model: root.p ? root.p.tags : []
                    delegate: Chip {
                        ui: root.ui
                        label: "#" + modelData
                        onClicked: { ui.tags = [modelData]; ui.selected = null }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: ui.cfgSafe.showSecurityNote && root.p && !root.p.builtin
                implicitHeight: note.implicitHeight + ui.px(20)
                radius: Math.max(2, ui.radius * 0.6)
                color: ui.tint(0.05)
                border.width: 1
                border.color: ui.tint(0.10)
                Txt {
                    id: note
                    ui: root.ui
                    anchors.fill: parent
                    anchors.margins: ui.px(10)
                    wrapMode: Text.Wrap
                    font.pixelSize: ui.fs(10)
                    opacity: 0.7
                    text: "Plugins run as unsandboxed code inside your shell. The Verified badge describes the exact snapshot that was checked, but installing fetches the plugin's current upstream code. Read the source first."
                }
            }
        }
    }
}
