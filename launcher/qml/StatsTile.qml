import QtQuick

Rectangle {
    id: tile

    property string label: ""
    property string value: ""
    property string subtitle: ""

    implicitWidth: 180
    implicitHeight: 84
    radius: 14

    color: "#291f10"
    border.color: "#3a2a14"
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 4

        Text {
            text: tile.label
            color: "#FFB81C"
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 1.4
            font.capitalization: Font.AllUppercase
        }

        Text {
            text: tile.value
            color: "#FFE082"
            font.pixelSize: 26
            font.weight: Font.Black
        }

        Text {
            text: tile.subtitle
            color: "#888"
            font.pixelSize: 11
            visible: tile.subtitle.length > 0
        }
    }
}
