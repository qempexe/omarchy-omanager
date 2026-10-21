import QtQuick
import QtQuick.Layouts
import "Model.js" as Model

// Saved plugin sets (profiles): a named snapshot of the installed third-party
// plugins. "Restore" re-enables anything from the set that is installed but
// off, and reinstalls anything missing when its repo is known. Nothing already
// present is removed or downgraded, so restoring is always safe.
Item {
    id: root

    property var ui: null
    property int confirmDelete: -1

    function save() {
        var name = nameField.text.trim()
        if (name === "") { if (ui.service) ui.service.note("Give the set a name first", false); return }
        if (ui.saveSet(name)) {
            nameField.text = ""
            if (ui.service) ui.service.note("Saved set \u201C" + name + "\u201D", true)
        } else if (ui.service) {
            ui.service.note("Nothing to save: no third-party plugins installed", false)
        }
    }

    function restore(i) {
        var s = ui.sets[i]
        var n = ui.restoreSet(i)
        if (ui.service && s)
            ui.service.note(n === 0 ? "Set \u201C" + s.name + "\u201D is already in place"
                                    : "Restoring \u201C" + s.name + "\u201D: " + n + (n === 1 ? " action queued" : " actions queued"), true)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ui.px(10)
        spacing: ui.px(8)

        // ---- save the current install -------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: saveCol.implicitHeight + ui.px(20)
            radius: ui.r(2)
            color: ui.tint(0.03)
            border.width: 1
            border.color: ui.tint(0.07)

            ColumnLayout {
                id: saveCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: ui.px(12)
                anchors.rightMargin: ui.px(12)
                spacing: ui.px(8)

                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    text: "Save the current install"
                    font.pixelSize: ui.fs(12)
                    font.weight: Font.DemiBold
                }
                Txt {
                    ui: root.ui
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    opacity: 0.55
                    font.pixelSize: ui.fs(10)
                    text: "Keep a named list of the plugins you have now, so you can bring the same set to another machine or roll back after experimenting."
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ui.px(8)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: ui.px(80)
                        implicitHeight: ui.px(28)
                        radius: ui.r(1.5)
                        color: ui.tint(0.05)
                        border.width: 1
                        border.color: nameField.activeFocus ? ui.tint(0.28) : ui.tint(0.08)
                        clip: true

                        PasteInput {
                            id: nameField
                            key: "setname"
                            service: root.ui ? root.ui.service : null
                            anchors.fill: parent
                            anchors.leftMargin: ui.px(10)
                            anchors.rightMargin: ui.px(10)
                            color: ui.fg
                            font.family: ui.fontName
                            font.pixelSize: ui.fs(12)
                            maximumLength: 60
                            onEditingFinished: root.save()
                            Txt {
                                ui: root.ui
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                elide: Text.ElideRight
                                visible: nameField.text === "" && !nameField.activeFocus
                                text: "Name this set\u2026"
                                opacity: 0.4
                            }
                        }
                    }
                    Btn {
                        ui: root.ui
                        kind: "primary"
                        text: "Save"
                        enabled: nameField.text.trim() !== ""
                        onClicked: root.save()
                    }
                }
            }
        }

        // ---- the saved sets -----------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0

            Flickable {
                anchors.fill: parent
                visible: ui.sets.length > 0
                contentWidth: width
                contentHeight: setCol.implicitHeight + ui.px(4)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: setCol
                    width: parent.width
                    spacing: ui.px(8)

                    Repeater {
                        model: ui.sets

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: rowCol.implicitHeight + ui.px(20)
                            radius: ui.r(2)
                            color: ui.tint(0.03)
                            border.width: 1
                            border.color: root.confirmDelete === index ? ui.bad : ui.tint(0.07)

                            ColumnLayout {
                                id: rowCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: ui.px(12)
                                anchors.rightMargin: ui.px(12)
                                spacing: ui.px(6)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ui.px(8)
                                    Txt {
                                        ui: root.ui
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        font.pixelSize: ui.fs(12)
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Txt {
                                        ui: root.ui
                                        text: Model.relTime(modelData.savedAt, ui.now)
                                        font.pixelSize: ui.fs(10)
                                        opacity: 0.5
                                    }
                                }

                                Txt {
                                    ui: root.ui
                                    Layout.fillWidth: true
                                    opacity: 0.6
                                    font.pixelSize: ui.fs(10)
                                    elide: Text.ElideRight
                                    text: {
                                        var n = modelData.plugins ? modelData.plugins.length : 0
                                        var r = ui.setRepos(index)
                                        return n + (n === 1 ? " plugin" : " plugins") + "  \u00B7  "
                                            + r + " reinstatable" + (r < n ? ", the rest only re-enable" : "")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ui.px(6)

                                    Btn {
                                        ui: root.ui
                                        Layout.alignment: Qt.AlignRight
                                        kind: "primary"
                                        text: "Restore"
                                        onClicked: root.restore(index)
                                    }
                                    Btn {
                                        ui: root.ui
                                        kind: "danger"
                                        text: root.confirmDelete === index ? "Really delete?" : "Delete"
                                        onClicked: {
                                            if (root.confirmDelete === index) {
                                                root.confirmDelete = -1
                                                root.ui.deleteSet(index)
                                            } else {
                                                root.confirmDelete = index
                                                confirmTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Txt {
                ui: root.ui
                anchors.centerIn: parent
                visible: ui.sets.length === 0
                width: parent.width - ui.px(40)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                opacity: 0.5
                font.pixelSize: ui.fs(11)
                text: "No sets yet. Name one above to snapshot what you have installed."
            }
        }
    }

    Timer { id: confirmTimer; interval: 2500; onTriggered: root.confirmDelete = -1 }
}
