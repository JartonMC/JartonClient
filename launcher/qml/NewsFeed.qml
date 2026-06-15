import QtQuick
import Jarton

// JartonMC Changelog right panel. Drifts continuously; pauses only while
// the user actively drags the scroller, resumes from current position.
Item {
    id: panel

    // Glassy translucent panel — single layer, rounded.
    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "#331a140e"
        border.color: "#44FFB81C"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 16
        anchors.topMargin: 20
        anchors.bottomMargin: 20
        spacing: 12

        Text {
            text: qsTr("JARTONMC CHANGELOG")
            color: "#FFE082"
            font.pixelSize: 13
            font.weight: Font.Black
            font.letterSpacing: 1.8
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#44FFB81C"
        }

        Flickable {
            id: scroller
            width: parent.width
            height: parent.height - parent.spacing * 2 - 13 - 1
            contentHeight: changelog.implicitHeight + 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: changelog
                width: scroller.width - 6
                text: ChangelogService.ready
                    ? ChangelogService.markdown
                    : qsTr("_Loading the latest changelog…_")
                color: "#D8D8D8"
                font.pixelSize: 13
                lineHeight: 1.55
                wrapMode: Text.WordWrap
                textFormat: Text.MarkdownText
                onLinkActivated: function(link) { Qt.openUrlExternally(link) }
            }
        }
    }

    // Drift driver: bumps contentY a few pixels per tick. Stops while
    // dragging or flicking so the user can read freely; resumes from the
    // current scroll position once they release.
    Timer {
        id: drift
        interval: 60
        repeat: true
        running: panel.visible
            && ChangelogService.ready
            && scroller.contentHeight > scroller.height
            && !scroller.dragging
            && !scroller.flicking
        onTriggered: {
            const max = scroller.contentHeight - scroller.height
            if (scroller.contentY >= max) {
                if (pauseTimer.running) return
                pauseTimer.restart()
            } else {
                scroller.contentY = Math.min(max, scroller.contentY + 1.2)
            }
        }
    }

    // After hitting the bottom, pause a bit, then ease back to the top.
    Timer {
        id: pauseTimer
        interval: 3500
        repeat: false
        onTriggered: returnToTop.start()
    }
    NumberAnimation {
        id: returnToTop
        target: scroller
        property: "contentY"
        from: scroller.contentHeight - scroller.height
        to: 0
        duration: 1600
        easing.type: Easing.InOutQuad
    }
}
