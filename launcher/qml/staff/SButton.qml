import QtQuick

// Shared staff button — honey theme, modern feel: rounded, hover lift + colour ease,
// clear variant hierarchy. variant: primary (honey fill) | secondary (outline) |
// danger (red) | ghost (borderless).
Rectangle {
    id: btn
    property string text: ""
    property string glyph: ""
    property string variant: "secondary"
    property bool busy: false
    signal clicked()

    implicitHeight: 34
    implicitWidth: row.implicitWidth + 28
    radius: 9
    antialiasing: true

    readonly property bool hovered: ma.containsMouse && !busy
    readonly property color restColor: variant === "primary" ? "#FFB81C"
        : variant === "danger" ? "#2a1414" : variant === "ghost" ? "transparent" : "#1b150e"
    readonly property color hoverColor: variant === "primary" ? "#FFC93C"
        : variant === "danger" ? "#3d1c1c" : variant === "ghost" ? "#1a140e" : "#26200f"
    readonly property color fg: variant === "primary" ? "#1a140e"
        : variant === "danger" ? "#ff9b9b" : "#FFE082"

    color: hovered ? hoverColor : restColor
    border.width: variant === "primary" ? 0 : 1
    border.color: variant === "danger" ? "#5c2a2a" : variant === "ghost" ? "transparent" : "#3a2f1c"
    opacity: busy ? 0.55 : 1.0
    scale: hovered ? 1.03 : 1.0

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: btn.glyph.length > 0
            text: btn.glyph; color: btn.fg; font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: btn.text; color: btn.fg
            font.pixelSize: 13; font.bold: btn.variant === "primary"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: !btn.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
