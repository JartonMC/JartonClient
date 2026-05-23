import QtQuick
import Jarton

// Two minimalist stat tiles. Sized to fit exactly within the parent QQuickWidget
// so no rectangular widget background extends past the rounded card edges.
Row {
    id: overlay
    spacing: 12
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    Rectangle {
        width: 200
        height: 76
        radius: 12
        color: "#aa221911"

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 0

            Text {
                text: qsTr("PLAYERS ONLINE")
                color: "#FFB81C"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.4
            }
            Text {
                text: ServerStatusService.state === 1
                    ? ServerStatusService.playersOnline + " / " + ServerStatusService.playersMax
                    : "—"
                color: "#FFE082"
                font.pixelSize: 24
                font.weight: Font.Black
            }
            Text {
                text: ServerStatusService.state === 1
                    ? qsTr("on mc.jarton.me")
                    : ServerStatusService.state === 0
                        ? qsTr("Status unknown")
                        : qsTr("Server offline")
                color: "#888"
                font.pixelSize: 11
            }
        }
    }

    Rectangle {
        visible: DiscordWidgetService.available
        width: 180
        height: 76
        radius: 12
        color: "#aa221911"

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 0

            Text {
                text: qsTr("DISCORD")
                color: "#FFB81C"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.4
            }
            Text {
                text: DiscordWidgetService.presenceCount
                color: "#FFE082"
                font.pixelSize: 24
                font.weight: Font.Black
            }
            Text {
                text: qsTr("online now")
                color: "#888"
                font.pixelSize: 11
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("https://discord.gg/JartonMC")
        }
    }
}
