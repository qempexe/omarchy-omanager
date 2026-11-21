import QtQuick

// Coalesce thumbnail completions into one image-binding update per short window.
Item {
    id: root
    visible: false
    property int tick: 0

    function notify() { if (!pulse.running) pulse.start() }
    Timer { id: pulse; interval: 120; onTriggered: root.tick++ }
}
