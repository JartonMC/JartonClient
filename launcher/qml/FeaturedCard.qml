import QtQuick
import Jarton

Rectangle {
    id: card

    // Wired by parent against the manifest; QML reads the values lazily so a
    // null featured_card naturally collapses the card.
    property string title: ""
    property string imageUrl: ""
    property string ctaUrl: ""

    visible: title.length > 0
    implicitWidth: 320
    implicitHeight: 160
    radius: 14
    clip: true

    color: "#221911"
    border.color: "#FFB81C66"
    border.width: 1

    Image {
        id: bg
        anchors.fill: parent
        source: card.imageUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        opacity: 0.55
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#aa1a140e" }
            GradientStop { position: 1.0; color: "#ee0f0a06" }
        }
    }

    // Top accent stripe.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 3
        color: "#FFB81C"
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        spacing: 6

        Text {
            text: qsTr("FEATURED")
            color: "#FFB81C"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 2
        }

        Text {
            text: card.title
            color: "#FFE082"
            font.pixelSize: 22
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (card.ctaUrl.length > 0) Qt.openUrlExternally(card.ctaUrl)
    }
}
