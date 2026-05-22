import QtQuick
import Jarton

Item {
    id: feed

    signal entryClicked(int index)

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#881a140e"
        border.color: "#332a14"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 14
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        spacing: 14

        Row {
            spacing: 10
            Text {
                text: qsTr("NEWS")
                color: "#FFB81C"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.6
            }
            Rectangle {
                width: 1
                height: 11
                color: "#3a2a14"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: qsTr("JartonMC announcements")
                color: "#888"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.0
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - parent.spacing - 22
            clip: true
            spacing: 10
            model: NewsService
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property int index
                required property string title
                required property string body
                required property var posted
                required property string imageUrl
                required property string url

                width: list.width
                implicitHeight: cardCol.implicitHeight + 24
                radius: 10
                color: cardHover.containsMouse ? "#2a1f10" : "#22150c"
                border.color: cardHover.containsMouse ? "#8B6F2A" : "#3a2a14"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Column {
                    id: cardCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    Text {
                        text: title
                        color: "#FFE082"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Text {
                        visible: posted && !isNaN(posted)
                        text: Qt.formatDate(posted, "MMM d, yyyy")
                        color: "#888"
                        font.pixelSize: 11
                    }

                    Text {
                        text: body
                        color: "#C9C9C9"
                        font.pixelSize: 12
                        lineHeight: 1.45
                        wrapMode: Text.WordWrap
                        textFormat: Text.MarkdownText
                        width: parent.width
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: cardHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: feed.entryClicked(index)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: NewsService.count === 0
                text: qsTr("Loading announcements…")
                color: "#5C5C5C"
                font.pixelSize: 12
                font.italic: true
            }
        }
    }
}
