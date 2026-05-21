import QtQuick
import Jarton

Rectangle {
    id: btn

    readonly property int srvState: DefaultInstanceService.state
    readonly property bool ready: srvState === 1
    readonly property bool launching: srvState === 2

    implicitWidth: 220
    implicitHeight: 56
    radius: 28

    gradient: Gradient {
        GradientStop { position: 0.0; color: ready ? "#FFE082" : "#5C4516" }
        GradientStop { position: 1.0; color: ready ? "#FFB81C" : "#3A2A14" }
    }

    border.color: ready ? "#FFC845" : "#3A2A14"
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: btn.launching ? qsTr("Launching…")
                            : btn.ready ? qsTr("Play")
                                        : qsTr("Set up JartonMC")
        color: btn.ready ? "#1a1a1a" : "#C9C9C9"
        font.pixelSize: 20
        font.weight: Font.Bold
        font.letterSpacing: 1.2
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: btn.launching ? Qt.ArrowCursor : Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            if (btn.launching) return
            if (btn.ready) {
                DefaultInstanceService.play()
            } else {
                DefaultInstanceService.requestSetup()
            }
        }
        onEntered: btn.scale = 1.02
        onExited: btn.scale = 1.0
    }

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
    }
}
