import QtQuick
import Jarton

// Thin bar pinned to the footer above the status bar. Shows latest title;
// click → C++ side opens the AnnouncementPopup overlay.
Rectangle {
    id: bar

    signal openRequested()

    implicitHeight: 38
    color: "#0f0a06"
    border.color: "#332a14"
    border.width: 1

    Row {
        anchors.left: parent.left
        anchors.right: moreLabel.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: NewsService.ready ? "#FFB81C" : "#5C5C5C"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("ANNOUNCEMENTS")
            color: "#FFB81C"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.4
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: NewsService.ready
                ? NewsService.latestTitle
                : qsTr("Waiting for the announcements feed…")
            color: hoverArea.containsMouse ? "#FFE082" : "#C9C9C9"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: Math.min(implicitWidth, bar.width - 280)
        }
    }

    Text {
        id: moreLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 16
        text: qsTr("More news →")
        color: "#FFB81C"
        font.pixelSize: 11
        font.weight: Font.Bold
        opacity: hoverArea.containsMouse ? 1.0 : 0.75
        visible: NewsService.ready
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: NewsService.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (NewsService.ready) bar.openRequested()
    }
}
