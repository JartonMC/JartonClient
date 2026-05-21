import QtQuick
import Jarton

Item {
    id: feed

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
        spacing: 12

        Row {
            spacing: 10

            Text {
                text: qsTr("CHANGELOG")
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
                text: qsTr("JartonMC")
                color: "#888"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.0
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Flickable {
            id: scroller
            width: parent.width
            height: parent.height - parent.spacing - 22
            contentHeight: changelog.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: changelog
                width: scroller.width - 6
                text: NewsService.ready ? NewsService.markdown : feed.placeholderMarkdown
                color: "#C9C9C9"
                font.pixelSize: 13
                lineHeight: 1.5
                wrapMode: Text.WordWrap
                textFormat: Text.MarkdownText
                onLinkActivated: function(link) { Qt.openUrlExternally(link) }
            }

            // Subtle fade at top/bottom so the scrolling text feels softer.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#cc1a140e" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    readonly property string placeholderMarkdown:
        "_Pulling the latest from jarton.me…_\n\n" +
        "Once changelog.md is live in jarton-launcher-cdn, every push updates this panel within 15 minutes."
}
