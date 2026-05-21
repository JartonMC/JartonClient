import QtQuick
import Jarton

Rectangle {
    id: pill

    readonly property int statusState: ServerStatusService.state
    readonly property bool online: statusState === 1
    readonly property bool unknown: statusState === 0

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 28
    radius: 14

    color: online ? "#1a2814" : unknown ? "#1f1a14" : "#281414"
    border.color: online ? "#A9E673" : unknown ? "#5C5C5C" : "#E94B4B"
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: pill.online ? "#A9E673" : pill.unknown ? "#888" : "#E94B4B"

            SequentialAnimation on opacity {
                running: pill.online
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: "#E8E8E8"
            font.pixelSize: 13
            font.weight: Font.Medium
            text: pill.online
                ? qsTr("Online · %1 / %2 players").arg(ServerStatusService.playersOnline).arg(ServerStatusService.playersMax)
                : pill.unknown
                    ? qsTr("Status unknown")
                    : qsTr("Offline")
        }
    }
}
