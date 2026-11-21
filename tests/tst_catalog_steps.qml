import QtQuick
import QtTest
import "../qml/js/Model.js" as Model

TestCase {
    name: "CatalogSteps"
    when: windowShown
    width: 300
    height: 180

    property var state: null
    property int steps: 0
    property int frames: 0
    property int maxStepMs: 0
    Timer { interval: 1; repeat: true; running: true; onTriggered: frames++ }
    Timer {
        id: stepper
        interval: 1
        repeat: true
        onTriggered: {
            var started = Date.now()
            steps++
            if (Model.normalizeCatalogStep(state, 100, 8)) running = false
            maxStepMs = Math.max(maxStepMs, Date.now() - started)
        }
    }
    function test_ui_responds_between_steps() {
        var plugins = []
        for (var i = 0; i < 2000; i++)
            plugins.push({ id: "example.p" + i, name: "Plugin " + i })
        state = Model.catalogNormalizer({plugins: plugins})
        steps = 0
        var before = frames
        stepper.running = true
        tryVerify(function() { return !stepper.running }, 10000)
        compare(state.list.length, 2000)
        verify(steps >= 20)
        verify(frames > before, "UI timer gets to run between normalization steps")
        verify(maxStepMs < 200, "normalization step took " + maxStepMs + "ms")
    }
}
