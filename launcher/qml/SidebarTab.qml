import QtQuick
import QtQuick.Controls

Rectangle {
    id: tab

    property string iconSource: ""
    property string label: ""
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

    Image {
        anchors.centerIn: parent
        source: tab.iconSource
        width: 22
        height: 22
        opacity: active ? 1.0 : 0.55
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tab.clicked()
        cursorShape: Qt.PointingHandCursor
    }

    ToolTip.text: label
    ToolTip.visible: hoverArea.containsMouse && label !== ""
    ToolTip.delay: 400
}
