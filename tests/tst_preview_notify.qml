import QtQuick
import QtTest
import "../qml/core"

TestCase {
    name: "PreviewNotify"
    when: windowShown
    width: 200
    height: 100

    ImageNotifier { id: notifier }

    function test_bursts_coalesce() {
        compare(notifier.tick, 0)
        for (var i = 0; i < 12; i++) notifier.notify()
        compare(notifier.tick, 0)
        tryCompare(notifier, "tick", 1, 1000)
        notifier.notify()
        tryCompare(notifier, "tick", 2, 1000)
    }
}
