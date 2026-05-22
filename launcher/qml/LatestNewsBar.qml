import QtQuick
import Jarton

Rectangle {
    id: bar

    signal clicked()

    visible: NewsService.ready
    implicitHeight: 38
    radius: 12
    color: hover.containsMouse ? "#33FFB81C" : "#22150c"
    border.color: hover.containsMouse ? "#FFB81C" : "#3a2a14"
    border.width: 1
    Behavior on color { ColorAnimation { duration: 140 } }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: "#FFB81C"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("LATEST")
            color: "#FFB81C"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.4
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: NewsService.latestTitle
            color: hover.containsMouse ? "#FFE082" : "#C9C9C9"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: bar.width - 200
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 14
        text: qsTr("More news →")
        color: "#FFB81C"
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 1.0
        opacity: hover.containsMouse ? 1.0 : 0.75
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.clicked()
    }
}
