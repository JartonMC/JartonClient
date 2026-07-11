import QtQuick

// Shared staff button — quiet chrome: primary is the only filled (honey) CTA,
// everything else is tonal/borderless. Hover is a colour ease plus a 1px lift
// with a soft halo on primary — no scale pop. variant: primary | secondary
// (tonal) | danger | ghost. icon: name from icons/ui, tinted per variant.
Rectangle {
    id: btn
    property string text: ""
    property string icon: ""
    property string variant: "secondary"
    property bool busy: false
    property bool compact: false   // 28h density for crowded card rows
    signal clicked()

    implicitHeight: compact ? 28 : 32
    implicitWidth: row.implicitWidth + (compact ? 22 : 26)
    radius: 8
    antialiasing: true

    readonly property bool hovered: ma.containsMouse && !busy
    readonly property bool pressed: ma.pressed && !busy
    readonly property color restColor: variant === "primary" ? "#FFB81C"
        : variant === "danger" ? "#2a1414" : variant === "ghost" ? "transparent" : "#1b150e"
    readonly property color hoverColor: variant === "primary" ? "#FFC93C"
        : variant === "danger" ? "#3d1c1c" : variant === "ghost" ? "#1a140e" : "#26200f"
    readonly property color pressColor: variant === "primary" ? "#E8A410"
        : variant === "danger" ? "#4a2222" : variant === "ghost" ? "#221a10" : "#2e2712"
    readonly property color fg: variant === "primary" ? "#1a140e"
        : variant === "danger" ? "#ff9b9b"
        : hovered ? "#FFEFB0" : "#FFE082"
    readonly property string iconTint: variant === "primary" ? "dark"
        : variant === "danger" ? "red" : "cream"

    color: pressed ? pressColor : hovered ? hoverColor : restColor
    opacity: !enabled ? 0.35 : busy ? 0.55 : 1.0

    Behavior on color { ColorAnimation { duration: 120 } }

    transform: Translate {
        y: btn.variant === "primary" && btn.hovered && !btn.pressed ? -1 : 0
        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    // soft halo standing in for a drop shadow — no render effects needed
    Rectangle {
        z: -1
        anchors.fill: parent; anchors.margins: -3
        radius: btn.radius + 3
        color: "transparent"
        border.width: 3
        border.color: btn.variant === "primary" && btn.hovered ? "#40FFB81C" : "transparent"
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Image {
            visible: btn.icon.length > 0
            source: btn.icon.length > 0
                ? "qrc:/jarton/staff/icons/ui/" + btn.icon + "-" + btn.iconTint + ".svg" : ""
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: btn.text; color: btn.fg
            font.pixelSize: 13
            font.weight: btn.variant === "primary" ? 600 : 500
            font.letterSpacing: 0.2
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
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
