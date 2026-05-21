import QtQuick

Rectangle {
    id: tab

    property string glyph: ""
    property bool active: false

    signal clicked()

    width: 44
    height: 44
    radius: 10

    color: active ? "transparent" : "#2a1f10"
    border.color: active ? "#8B6F2A" : "transparent"
    border.width: active ? 1 : 0

    gradient: active ? activeGradient : null

    Gradient {
        id: activeGradient
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: "#FFE082" }
        GradientStop { position: 1.0; color: "#FFB81C" }
    }

    Text {
        anchors.centerIn: parent
        text: tab.glyph
        color: tab.active ? "#1a1a1a" : "#FFE082"
        font.pixelSize: 22
        font.weight: tab.active ? Font.Bold : Font.Medium
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tab.clicked()
        cursorShape: Qt.PointingHandCursor
    }
}
