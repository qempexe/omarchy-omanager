import QtQuick
import QtQuick.Layouts
import QtTest

// Smoke-test the batch bar's Flow/RowLayout sizing at narrow and wide widths.
TestCase {
    name: "BatchFlow"
    when: windowShown
    width: 1500
    height: 400

    RowLayout {
        id: bar
        width: parent.width
        spacing: 6

        Flow {
            id: selectedChips
            Layout.fillWidth: true
            Layout.minimumWidth: 100
            spacing: 5

            Rectangle { width: 80; height: 24 } // count
            Repeater {
                id: names
                model: 19
                Rectangle { width: 120; height: 24 }
            }
        }
        Rectangle { width: 40; height: 24; Layout.alignment: Qt.AlignTop } // All
        Rectangle { width: 45; height: 24; Layout.alignment: Qt.AlignTop } // None
        Rectangle { width: 120; height: 24; Layout.alignment: Qt.AlignTop } // action
    }

    function test_wrap() {
        for (const width of [460, 1440]) {
            bar.width = width
            wait(30)
            verify(selectedChips.implicitHeight > 24, "names wrap at " + width + "px")
            verify(names.itemAt(18).y > names.itemAt(0).y, "last name remains on a later row")
            verify(bar.implicitHeight >= selectedChips.implicitHeight, "bar grows to show all names")
            verify(names.itemAt(18).x + names.itemAt(18).width <= selectedChips.width,
                   "last name remains before the action buttons")
        }
    }
}
