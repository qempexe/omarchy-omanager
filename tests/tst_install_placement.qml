import QtQuick
import QtTest
import "../qml/core"
import "../qml/js/Model.js" as Model

TestCase {
    name: "InstallPlacement"
    when: windowShown
    width: 300
    height: 200

    UiState {
        id: managerState
        service: QtObject {
            property bool installedReady: false
            property var catalog: []
            property var installed: []
            property var installedMap: ({})
            property var bookmarks: ({})
            property var health: []
            property int healthCount: 0
            property var updateIds: []
            property var sets: []
            property var themePalette: []
            property var borderColors: []
            property real borderAngle: 0
            property real prevVisit: 0
            property string catalogState: "ready"
            property string catalogError: ""
            function perform() {}
            function note() {}
        }
    }

    function test_catalog_bar_widget_without_kinds() {
        // The Browse catalog uses the human-readable kind, unlike installed manifests.
        var p = Model.normalizeCatalog([{
            id: "io.github.jotenakis2.myweather",
            name: "MyWeather",
            kind: "Bar widget",
            repo: "https://github.com/jotenakis2/MyWeather",
            verified: true
        }])[0]
        managerState.requestAction("install", p)
        verify(managerState.confirm !== null)
        compare(managerState.confirm.placement, true, "install must offer a bar placement")
        managerState.confirm = null
    }

    function test_manifest_kinds_and_full_bar() {
        var widget = Model.normalizeCatalog([{
            id: "example.widget", kinds: ["bar-widget"],
            repo: "https://github.com/example/widget", verified: true
        }])[0]
        managerState.requestAction("install", widget)
        compare(managerState.confirm.placement, true)
        managerState.confirm = null

        var fullBar = Model.normalizeCatalog([{
            id: "example.bar", kind: "Bar", kinds: ["bar", "bar-widget"],
            repo: "https://github.com/example/bar", verified: true
        }])[0]
        managerState.requestAction("install", fullBar)
        compare(managerState.confirm.placement, false)
        managerState.confirm = null
    }
}
