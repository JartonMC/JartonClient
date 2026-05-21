import QtQuick

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
        }
    }
}
