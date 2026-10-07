import QtQuick
import QtQuick.Layouts

// All the filters. Every control writes straight into the panel's filter state
// (ui.*), and the panel recomputes the results.
Flickable {
    id: root

    property var ui: null

    readonly property bool onBrowse: ui.tabName === "browse"
    readonly property bool onInstalled: ui.tabName === "installed"

    contentWidth: width
    contentHeight: col.implicitHeight + ui.px(16)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function toggleTag(t) {
        var cur = ui.tags.slice()
        var i = cur.indexOf(t)
        if (i >= 0) cur.splice(i, 1)
        else cur.push(t)
        ui.tags = cur
    }

    ColumnLayout {
        id: col
        width: root.width - ui.px(4)
        spacing: ui.px(16)

        RowLayout {
            Layout.fillWidth: true
            Txt { ui: root.ui; Layout.fillWidth: true; text: ui.items.length + " of " + ui.poolSize; font.pixelSize: ui.fs(11); opacity: 0.6 }
            Btn { ui: root.ui; visible: ui.filtersActive; text: "Reset"; implicitHeight: ui.px(22); onClicked: ui.resetFilters() }
        }

        Section {
            ui: root.ui
            title: "Show"
            visible: root.onBrowse
            Chip { ui: root.ui; label: "Community"; on: ui.source === "community"; onClicked: ui.source = "community" }
            Chip { ui: root.ui; label: "Built-in"; on: ui.source === "builtin"; onClicked: ui.source = "builtin" }
            Chip { ui: root.ui; label: "All"; on: ui.source === "all"; onClicked: ui.source = "all" }
        }

        Section {
            ui: root.ui
            title: "Sort by"
            Repeater {
                model: ui.sortOptions
                delegate: Chip {
                    ui: root.ui
                    label: modelData.label
                    on: ui.sortKey === modelData.key
                    onClicked: ui.sortKey = modelData.key
                }
            }
        }

        Section {
            ui: root.ui
            title: "Uploaded / upgraded"
            // only used together with "Within the last"
            opacity: ui.days > 0 ? 1.0 : 0.4
            Chip { ui: root.ui; label: "Either"; on: ui.scope === "either"; onClicked: ui.scope = "either" }
            Chip { ui: root.ui; label: "Uploaded"; on: ui.scope === "added"; onClicked: ui.scope = "added" }
            Chip { ui: root.ui; label: "Upgraded"; on: ui.scope === "updated"; onClicked: ui.scope = "updated" }
        }

        Section {
            ui: root.ui
            title: "Within the last"
            Chip { ui: root.ui; label: "Any time"; on: ui.days === 0; onClicked: ui.days = 0 }
            Chip { ui: root.ui; label: "Week"; on: ui.days === 7; onClicked: ui.days = 7 }
            Chip { ui: root.ui; label: "Month"; on: ui.days === 30; onClicked: ui.days = 30 }
            Chip { ui: root.ui; label: "3 months"; on: ui.days === 90; onClicked: ui.days = 90 }
            Chip { ui: root.ui; label: "Year"; on: ui.days === 365; onClicked: ui.days = 365 }
        }

        Section {
            ui: root.ui
            title: "Status"
            visible: root.onBrowse
            Chip { ui: root.ui; label: "Any"; on: ui.status === "any"; onClicked: ui.status = "any" }
            Chip { ui: root.ui; label: "Installed"; on: ui.status === "installed"; onClicked: ui.status = "installed" }
            Chip { ui: root.ui; label: "Not installed"; on: ui.status === "notinstalled"; onClicked: ui.status = "notinstalled" }
            Chip { ui: root.ui; label: "Has update"; on: ui.status === "updates"; onClicked: ui.status = "updates" }
            Chip { ui: root.ui; label: "Saved"; on: ui.status === "saved"; onClicked: ui.status = "saved" }
            Chip { ui: root.ui; label: "New since last visit"; on: ui.status === "new"; onClicked: ui.status = "new" }
        }

        Section {
            ui: root.ui
            title: "Status"
            visible: root.onInstalled
            Chip { ui: root.ui; label: "All installed"; on: ui.status !== "enabled" && ui.status !== "disabled"; onClicked: ui.status = "any" }
            Chip { ui: root.ui; label: "Enabled"; on: ui.status === "enabled"; onClicked: ui.status = "enabled" }
            Chip { ui: root.ui; label: "Disabled"; on: ui.status === "disabled"; onClicked: ui.status = "disabled" }
        }

        Section {
            ui: root.ui
            title: "Trust"
            Chip { ui: root.ui; label: "\u2713 Verified only"; on: ui.verifiedOnly; tone: ui.good; onClicked: ui.verifiedOnly = !ui.verifiedOnly }
            Chip { ui: root.ui; visible: root.onBrowse; label: "Hide installed"; on: ui.hideInstalled; onClicked: ui.hideInstalled = !ui.hideInstalled }
        }

        Section {
            ui: root.ui
            title: "Category"
            visible: ui.facets.categories.length > 0
            Chip { ui: root.ui; label: "All"; on: ui.category === ""; onClicked: ui.category = "" }
            Repeater {
                model: ui.facets.categories
                delegate: Chip {
                    ui: root.ui
                    label: modelData.name
                    count: modelData.count
                    on: ui.category === modelData.name
                    tone: ui.tone(modelData.name)
                    dot: ui.cfgSafe.colorMode === "category"
                    onClicked: ui.category = ui.category === modelData.name ? "" : modelData.name
                }
            }
        }

        Section {
            ui: root.ui
            title: "Tags"
            visible: ui.facets.tags.length > 0
            Repeater {
                model: ui.facets.tags.slice(0, 24)
                delegate: Chip {
                    ui: root.ui
                    label: modelData.name
                    count: modelData.count
                    on: ui.tags.indexOf(modelData.name) >= 0
                    onClicked: root.toggleTag(modelData.name)
                }
            }
        }
    }
}
