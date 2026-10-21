import QtQuick
import QtQuick.Layouts
import "../js/Model.js" as Model
import "../controls"

// Slide-in details for one plugin, with every action that applies to it.
Rectangle {
    id: root

    property var ui: null
    property var p: null
    property bool inline: false          // true = the permanent stage, false = slide-in overlay

    readonly property var st: p ? ui.stateOf(p) : ({ installed: false, enabled: false, update: false, version: "", dir: "", installedAt: 0 })
    readonly property bool working: p && ui.service && ui.service.busyIds[p.id] !== undefined
    readonly property bool saved: p && ui.service && ui.service.bookmarks[p.id] === true
    readonly property string cmd: p ? Model.installCommand(p) : ""
    readonly property var health: p ? ui.healthFor(p) : null
    readonly property var history: (p && ui.service) ? (ui.service.history[p.id] || null) : null
    // Load the read-only history the first time a plugin is shown, once we know
    // where it lives on disk.
    onPChanged: historyReload.restart()
    onStChanged: historyReload.restart()
    Timer {
        id: historyReload
        interval: 120
        onTriggered: {
            if (root.p && root.st.installed && root.st.dir !== "" && root.history === null)
                root.ui.service.loadHistory(root.p.id, root.st.dir, false)
        }
    }

    color: inline ? "transparent" : ui.surface
    border.width: inline ? 0 : 1
    border.color: ui.tint(0.16)
    radius: ui.r(2)

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

            RowLayout {
                Layout.fillWidth: true
                visible: root.health !== null
                spacing: ui.px(6)
                Txt { ui: root.ui; text: "\u26A0"; color: ui.warn }
                Txt { ui: root.ui; Layout.fillWidth: true; text: root.health ? root.health.text : ""; color: ui.warn; wrapMode: Text.Wrap }
            }

            // preview: 16:9, the large image; falls back to the thumbnail, then an initial
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(ui.px(root.inline ? 330 : 200), width * 9 / 16)
                visible: ui.cfgSafe.showPreviews
                radius: ui.r(2)
                color: root.p ? Qt.rgba(ui.tone(root.p.category).r, ui.tone(root.p.category).g, ui.tone(root.p.category).b, 0.12) : ui.tint(0.05)
                border.width: 1
                border.color: ui.tint(0.10)
                clip: true
                Image {
                    id: bigImg
                    anchors.fill: parent
                    source: (ui.cfgSafe.showPreviews && root.p) ? ui.service.imageFor(root.p.previewFull, ui.service.imageTick) : ""
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
                    text: (bigImg.status === Image.Loading || (root.p && ui.service.imageBusy(root.p.previewFull, ui.service.imageTick)))
                          ? "Loading preview\u2026"
                          : (root.p ? root.p.name.charAt(0).toUpperCase() : "")
                    font.pixelSize: text.length > 1 ? ui.fs(11) : ui.fs(54)
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
                Btn {
                    ui: root.ui; text: "Open folder"
                    visible: root.st.installed && root.st.dir !== ""
                    onClicked: ui.service.openPluginDir(root.st.dir)
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

            // Install facts: shown for any installed plugin, including built-in and
            // local ones the numbers above skip. The folder row only appears when it
            // differs from the id, which is the case an update has to get right.
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: ui.px(12)
                rowSpacing: ui.px(4)
                visible: root.st.installed

                Txt { ui: root.ui; visible: root.p && (root.p.local || root.p.builtin); text: "Id"; opacity: 0.5 }
                Txt { ui: root.ui; visible: root.p && (root.p.local || root.p.builtin); Layout.fillWidth: true; text: root.p ? root.p.id : ""; elide: Text.ElideRight }
                Txt { ui: root.ui; visible: root.st.dir !== "" && (!root.p || root.st.dir !== root.p.id); text: "Folder"; opacity: 0.5 }
                Txt { ui: root.ui; visible: root.st.dir !== "" && (!root.p || root.st.dir !== root.p.id); Layout.fillWidth: true; text: root.st.dir; elide: Text.ElideRight; color: ui.warn }
                Txt { ui: root.ui; visible: root.st.installedAt > 0; text: "Installed"; opacity: 0.5 }
                Txt { ui: root.ui; visible: root.st.installedAt > 0; Layout.fillWidth: true; text: root.st.installedAt > 0 ? Model.relTime(root.st.installedAt, ui.now) : "" }
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

            // recent commits, and (when an update is pending) what it would bring in
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.st.installed && root.st.dir !== ""
                spacing: ui.px(6)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(6)
                    Txt { ui: root.ui; Layout.fillWidth: true; text: root.history && root.history.incoming ? "Incoming changes" : "Recent changes"; font.pixelSize: ui.fs(11); font.weight: Font.DemiBold; opacity: 0.7 }
                    Btn {
                        ui: root.ui; text: "Recent"; implicitHeight: ui.px(22)
                        visible: root.st.installed && root.st.dir !== ""
                        onClicked: ui.service.loadHistory(root.p.id, root.st.dir, false)
                    }
                    Btn {
                        ui: root.ui; kind: "primary"; text: "Incoming"; implicitHeight: ui.px(22)
                        visible: root.st.update
                        enabled: !root.working
                        onClicked: ui.service.loadHistory(root.p.id, root.st.dir, true)
                    }
                }

                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    visible: root.history && root.history.state === "loading"
                    text: "Loading\u2026"
                    opacity: 0.5
                    font.pixelSize: ui.fs(10)
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    visible: root.history && root.history.state === "error"
                    text: root.history ? root.history.error : ""
                    color: ui.warn
                    wrapMode: Text.Wrap
                    font.pixelSize: ui.fs(10)
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    visible: root.history && root.history.state === "ready" && root.history.lines.length === 0
                    text: root.history && root.history.incoming ? "Already up to date." : "No history available."
                    opacity: 0.5
                    font.pixelSize: ui.fs(10)
                }
                Repeater {
                    model: (root.history && root.history.state === "ready") ? root.history.lines : []
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: ui.px(8)
                        Txt { ui: root.ui; text: modelData.hash; color: ui.accent; font.pixelSize: ui.fs(9); opacity: 0.85 }
                        Txt { ui: root.ui; text: modelData.date; font.pixelSize: ui.fs(9); opacity: 0.45 }
                        Txt { ui: root.ui; Layout.fillWidth: true; text: modelData.subject; font.pixelSize: ui.fs(10); elide: Text.ElideRight }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: ui.cfgSafe.showSecurityNote && root.p && !root.p.builtin
                implicitHeight: note.implicitHeight + ui.px(20)
                radius: ui.r(1.5)
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
