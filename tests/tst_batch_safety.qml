import QtQuick
import QtTest
import "../qml/core"

TestCase {
    name: "BatchSafety"
    when: windowShown
    width: 320
    height: 200

    UiState {
        id: managerState
        service: QtObject {
            property bool installedReady: true
            property var catalog: []
            property var installed: []
            property var installedMap: ({})
            property var busyIds: ({})
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
            property var performed: []
            property bool acceptJobs: true
            function perform(kind, id, name, repo) {
                if (!acceptJobs) return false
                performed = performed.concat(id)
                return true
            }
        }
    }

    function test_large_batch_requires_chunk_confirmation() {
        var selection = Object.create(null)
        for (var i = 0; i < 52; i++) {
            var id = "example.widget" + i
            selection[id] = { id: id, name: id, repo: "https://github.com/example/widgets",
                              verified: true, installable: true, builtin: false, local: false }
        }
        managerState.selection = selection
        managerState.requestBatch("install")
        compare(managerState.confirm.kind, "batchLimit")
        compare(managerState.confirm.count, 52)
        compare(managerState.confirm.list.length, 50)
        compare(managerState.service.performed.length, 0)
        managerState.runBatch(managerState.confirm.action, managerState.confirm.list)
        compare(managerState.service.performed.length, 50)
        compare(managerState.selCount, 2)
        managerState.confirm = null
        managerState.clearSelection()
    }

    function test_rejected_jobs_remain_selected() {
        managerState.selection = ({
            "example.one": { id: "example.one", name: "One",
                             repo: "https://github.com/example/one", verified: true, installable: true }
        })
        managerState.service.acceptJobs = false
        managerState.requestBatch("install")
        compare(managerState.confirm.kind, "install")
        managerState.runBatch("install", managerState.confirm.list)
        compare(managerState.selCount, 1)
        managerState.service.acceptJobs = true
        managerState.confirm = null
        managerState.clearSelection()
    }
}
