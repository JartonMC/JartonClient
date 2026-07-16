import QtQuick

// Shared sub-tab bar — quiet icon+label chips with one sliding honey underline
// instead of filled pills. model: [{id, label, icon}] where icon names a file
// in icons/ui (rest/active tints); current/selected drive the active chip.
// The chip row lives in a horizontal Flickable so a thin window (or pop-out)
// can still reach every tab — trailing chips used to clip off with no way in.
Item {
    id: bar
    property var model: []
    property string current: ""
    signal selected(string id)

    implicitHeight: 30
    height: implicitHeight

    function sync() {
        for (var i = 0; i < rep.count; i++) {
            var c = rep.itemAt(i)
            if (c && c.tabId === bar.current) {
                underline.x = c.x + 10
                underline.width = c.width - 20
                reveal(c)
                return
            }
        }
        underline.width = 0
    }

    // nudge the flickable so the active chip is fully on screen
    function reveal(c) {
        if (flick.contentWidth <= flick.width) {
            flick.contentX = 0
            return
        }
        if (c.x < flick.contentX)
            flick.contentX = Math.max(0, c.x - 10)
        else if (c.x + c.width > flick.contentX + flick.width)
            flick.contentX = Math.min(flick.contentWidth - flick.width, c.x + c.width - flick.width + 10)
    }

    onCurrentChanged: sync()
    onModelChanged: Qt.callLater(sync)
    onWidthChanged: Qt.callLater(sync)
    Component.onCompleted: Qt.callLater(sync)

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: chipsRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: contentWidth > width

        Row {
            id: chipsRow
            spacing: 14
            Repeater {
                id: rep
                model: bar.model
                delegate: Item {
                    id: chip
                    readonly property string tabId: modelData.id
                    readonly property bool active: bar.current === modelData.id
                    width: chipRow.implicitWidth + 24; height: 30
                    onXChanged: if (active) bar.sync()
                    onWidthChanged: if (active) bar.sync()

                    Rectangle {
                        anchors.fill: parent; radius: 8
                        color: chipMa.containsMouse && !chip.active ? "#1a140e" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent; spacing: 6
                        Image {
                            visible: (modelData.icon || "") !== ""
                            source: modelData.icon
                                ? "qrc:/jarton/staff/icons/ui/" + modelData.icon + (chip.active ? "-active" : "-rest") + ".svg" : ""
                            width: 14; height: 14
                            sourceSize: Qt.size(28, 28)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: chip.active ? "#FFE082" : chipMa.containsMouse ? "#C9B98A" : "#9a8a66"
                            font.pixelSize: 13
                            font.weight: chip.active ? 600 : 500
                            font.letterSpacing: 0.2
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.selected(modelData.id)
                    }
                }
            }
        }

        // faint glow behind the indicator, then the indicator itself — inside the
        // flickable so they track their chip while the row scrolls
        Rectangle {
            y: bar.height - 4
            x: underline.x - 4; width: underline.width + 8; height: 6; radius: 3
            color: "#1AFFB81C"
            visible: underline.width > 0
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            id: underline
            y: bar.height - 2
            height: 2; radius: 1
            width: 0
            color: "#FFB81C"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    // soft edge fades hint that more tabs are off-screen
    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 18
        visible: flick.contentX > 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#E60f0a06" }
            GradientStop { position: 1.0; color: "#000f0a06" }
        }
    }
    Rectangle {
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 18
        visible: flick.contentWidth > flick.width && flick.contentX < flick.contentWidth - flick.width - 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#000f0a06" }
            GradientStop { position: 1.0; color: "#E60f0a06" }
        }
    }
}
