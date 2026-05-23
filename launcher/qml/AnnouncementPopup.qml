import QtQuick
import Jarton

Item {
    id: root

    signal closeRequested()

    function showIndex(index) {
        NewsService.selectedIndex = Math.max(0, index)
    }

    // The QFrame parent paints the brown card; QML just fills it with content.
    Item {
        id: dialog
        anchors.fill: parent

        // Side list (right).
        Item {
            id: sideList
            width: 260
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 22
            anchors.bottomMargin: 22
            anchors.rightMargin: 22

            Text {
                id: sideHeader
                text: qsTr("MORE ANNOUNCEMENTS")
                color: "#FFB81C"
                font.pixelSize: 10
                font.weight: Font.Black
                font.letterSpacing: 1.6
            }

            ListView {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sideHeader.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 10
                spacing: 6
                clip: true
                model: NewsService
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: NewsService.selectedIndex

                delegate: Rectangle {
                    required property int index
                    required property string title
                    required property var posted

                    width: ListView.view.width
                    implicitHeight: 58
                    radius: 10
                    color: index === NewsService.selectedIndex
                        ? "#33FFB81C"
                        : (entryHover.containsMouse ? "#2a1f10" : "#15100a")
                    border.color: index === NewsService.selectedIndex ? "#FFB81C" : "#3a2a14"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        Text {
                            text: title
                            color: "#E8E8E8"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            width: parent.width
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: posted && !isNaN(posted)
                            text: posted ? Qt.formatDate(posted, "MMM d") : ""
                            color: "#888"
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: entryHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NewsService.selectedIndex = index
                    }
                }
            }
        }

        // Featured area (left).
        Item {
            id: featured
            anchors.left: parent.left
            anchors.right: sideList.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 26
            anchors.topMargin: 22
            anchors.bottomMargin: 22
            anchors.rightMargin: 22

            Row {
                id: featuredHeader
                anchors.left: parent.left
                anchors.top: parent.top
                spacing: 10
                Text {
                    text: qsTr("ANNOUNCEMENT")
                    color: "#FFB81C"
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 2
                }
                Text {
                    visible: NewsService.selectedPosted && !isNaN(NewsService.selectedPosted)
                    text: NewsService.selectedPosted
                        ? Qt.formatDate(NewsService.selectedPosted, "MMMM d, yyyy")
                        : ""
                    color: "#888"
                    font.pixelSize: 10
                }
            }

            Text {
                id: featuredTitle
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: featuredHeader.bottom
                anchors.topMargin: 10
                text: NewsService.selectedTitle
                color: "#FFE082"
                font.pixelSize: 22
                font.weight: Font.Black
                wrapMode: Text.WordWrap
            }

            Image {
                id: heroImage
                visible: NewsService.selectedImageUrl.length > 0
                source: NewsService.selectedImageUrl
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: featuredTitle.bottom
                anchors.topMargin: 12
                height: visible ? Math.min(220, width * 9 / 16) : 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                clip: true
            }

            Rectangle {
                id: openButton
                visible: NewsService.selectedUrl.length > 0
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                implicitWidth: 180
                implicitHeight: 36
                radius: 18
                color: openHover.containsMouse ? "#FFE082" : "#FFB81C"
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Open in Discord →")
                    color: "#1a1a1a"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: openHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(NewsService.selectedUrl)
                }
            }

            Flickable {
                id: bodyScroller
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: heroImage.visible ? heroImage.bottom : featuredTitle.bottom
                anchors.bottom: openButton.visible ? openButton.top : parent.bottom
                anchors.topMargin: 14
                anchors.bottomMargin: openButton.visible ? 14 : 0
                contentHeight: bodyText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: bodyText
                    width: bodyScroller.width - 6
                    text: NewsService.selectedBody
                    color: "#E8E8E8"
                    font.pixelSize: 14
                    lineHeight: 1.55
                    wrapMode: Text.WordWrap
                    textFormat: Text.MarkdownText
                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                }
            }
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            text: "×"
            color: closeHover.containsMouse ? "#FFE082" : "#888"
            font.pixelSize: 24
            z: 100
            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.closeRequested() }
            }
        }
    }
}
