import QtQuick
import Jarton

Item {
    id: hero

    Column {
        id: stack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 48
        anchors.rightMargin: 48
        anchors.bottomMargin: 56
        spacing: 18

        Text {
            text: "JartonMC"
            color: "#FFE082"
            font.pixelSize: 56
            font.weight: Font.Black
            font.letterSpacing: 4
        }

        Text {
            text: qsTr("Honey-warm Towny survival, polished and pinned.")
            color: "#C9C9C9"
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        Item { width: 1; height: 12 }  // spacer

        Row {
            spacing: 16

            PlayButton { id: playBtn }
            StatusPill { anchors.verticalCenter: playBtn.verticalCenter }

            Rectangle {
                anchors.verticalCenter: playBtn.verticalCenter
                visible: JartonManifestService.consecutiveFailures >= 3
                implicitHeight: 28
                implicitWidth: stalRow.implicitWidth + 24
                radius: 14
                color: "#251a10"
                border.color: "#FFB81C66"
                border.width: 1

                Row {
                    id: stalRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Working offline")
                        color: "#FFB81C"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↻"
                        color: "#FFE082"
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: JartonManifestService.refreshNow()
                        }
                    }
                }
            }
        }
    }
}
