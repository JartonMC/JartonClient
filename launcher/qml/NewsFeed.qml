import QtQuick
import Jarton

Rectangle {
    id: feed

    implicitWidth: 360
    radius: 14

    color: "#cc1a140e"
    border.color: "#3a2a14"
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            text: qsTr("News")
            color: "#FFE082"
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 1.4
            font.capitalization: Font.AllUppercase
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - parent.spacing - 22
            contentHeight: listColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listColumn
                width: parent.width
                spacing: 10

                Repeater {
                    model: NewsService

                    delegate: Rectangle {
                        required property string title
                        required property string published
                        required property string bodyMd
                        required property string url

                        width: listColumn.width
                        implicitHeight: cardCol.implicitHeight + 24
                        radius: 10
                        color: "#221911"
                        border.color: "#3a2a14"
                        border.width: 1

                        Column {
                            id: cardCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Text {
                                text: title
                                color: "#FFE082"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Text {
                                text: published
                                color: "#888"
                                font.pixelSize: 10
                            }

                            Text {
                                text: bodyMd
                                color: "#C9C9C9"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                width: parent.width
                                visible: bodyMd.length > 0
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (url.length > 0) Qt.openUrlExternally(url)
                        }
                    }
                }

                Text {
                    visible: NewsService.rowCount() === 0
                    text: qsTr("No news yet. Check back soon.")
                    color: "#5C5C5C"
                    font.pixelSize: 12
                    font.italic: true
                }
            }
        }
    }
}
