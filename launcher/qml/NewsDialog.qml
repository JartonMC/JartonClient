import QtQuick
import Jarton

Item {
    id: root
    visible: false

    property int currentIndex: 0
    property var currentEntry: NewsService.entry(currentIndex)

    function showIndex(index) {
        currentIndex = index
        currentEntry = NewsService.entry(index)
        visible = true
    }

    // Dimmer
    Rectangle {
        anchors.fill: parent
        color: "#cc0f0a06"

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 760)
        height: Math.min(parent.height - 80, 640)
        radius: 16
        color: "#1a140e"
        border.color: "#3a2a14"
        border.width: 1

        // Catch clicks on the dialog body so they don't dismiss.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Row {
                spacing: 10
                Text {
                    text: qsTr("ANNOUNCEMENT")
                    color: "#FFB81C"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.6
                }
                Text {
                    visible: root.currentEntry.posted && !isNaN(root.currentEntry.posted)
                    text: Qt.formatDate(root.currentEntry.posted, "MMMM d, yyyy")
                    color: "#888"
                    font.pixelSize: 10
                }
            }

            Text {
                text: root.currentEntry.title || ""
                color: "#FFE082"
                font.pixelSize: 26
                font.weight: Font.Black
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Image {
                visible: (root.currentEntry.imageUrl || "").length > 0
                source: root.currentEntry.imageUrl || ""
                width: parent.width
                height: 180
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Flickable {
                id: bodyScroller
                width: parent.width
                height: parent.height - parent.spacing * 4 - 26 - 26 - 36
                    - (root.currentEntry.imageUrl && root.currentEntry.imageUrl.length > 0 ? 194 : 0)
                contentHeight: bodyText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: bodyText
                    width: bodyScroller.width - 6
                    text: root.currentEntry.body || ""
                    color: "#D8D8D8"
                    font.pixelSize: 14
                    lineHeight: 1.55
                    wrapMode: Text.WordWrap
                    textFormat: Text.MarkdownText
                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                }
            }

            Row {
                spacing: 10

                Rectangle {
                    visible: (root.currentEntry.url || "").length > 0
                    implicitWidth: 140
                    implicitHeight: 36
                    radius: 18
                    color: openHover.containsMouse ? "#FFE082" : "#FFB81C"
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Open link")
                        color: "#1a1a1a"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: openHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(root.currentEntry.url)
                    }
                }

                Rectangle {
                    implicitWidth: 100
                    implicitHeight: 36
                    radius: 18
                    color: "transparent"
                    border.color: "#3a2a14"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Close")
                        color: "#C9C9C9"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }
        }

        // Top-right close X.
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 16
            text: "×"
            color: "#888"
            font.pixelSize: 22
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.visible = false
            }
        }
    }
}
