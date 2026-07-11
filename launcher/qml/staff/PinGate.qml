import QtQuick
import Jarton

// PIN unlock for the Staff section. Non-admin accounts create a 4-8 digit pin on
// first open (POST /proctor/me/pin) and re-enter it on launch or after 3h idle
// (POST /proctor/me/pin/verify). ProctorClient.pinLocked drives which view the
// panel Loader shows; this gate replaces the section content entirely while locked.
Item {
    id: gate
    property bool forceVerify: false   // a 409 on create means a pin exists elsewhere
    readonly property bool creating: !ProctorClient.pinSet && !gate.forceVerify
    property bool confirmStage: false
    property string firstPin: ""
    property string error: ""
    property bool busy: false
    property bool cooling: false       // 429 backoff — input disabled while true
    property var pending: ({})         // request id -> "set" | "verify"

    function submit() {
        if (gate.busy || gate.cooling) return
        var pin = pinIn.text
        if (pin.length < 4) { gate.error = "At least 4 digits."; return }
        if (gate.creating) {
            if (!gate.confirmStage) {
                gate.firstPin = pin
                pinIn.text = ""
                gate.confirmStage = true
                gate.error = ""
                return
            }
            if (pin !== gate.firstPin) {
                gate.error = "Those didn't match. Start over."
                gate.firstPin = ""; pinIn.text = ""; gate.confirmStage = false
                shake.restart()
                return
            }
            gate.busy = true; gate.error = ""
            gate.pending[ProctorApi.send("POST", "/proctor/me/pin", JSON.stringify({ pin: pin }))] = "set"
        } else {
            gate.busy = true; gate.error = ""
            gate.pending[ProctorApi.send("POST", "/proctor/me/pin/verify", JSON.stringify({ pin: pin }))] = "verify"
        }
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            var kind = gate.pending[id]
            if (kind === undefined) return
            delete gate.pending[id]
            gate.busy = false
            if (ok) {
                if (kind === "set") ProctorClient.pinCreated()
                else ProctorClient.unlock()
                return
            }
            pinIn.text = ""
            if (status === 429) {
                gate.error = "Too many attempts. Try again in a bit."
                gate.cooling = true
                coolTimer.restart()
            } else if (status === 401) {
                gate.error = "Wrong PIN."
                shake.restart()
            } else if (status === 409 && kind === "set") {
                // pin appeared on the account since /me loaded (set from another device)
                gate.forceVerify = true
                gate.confirmStage = false
                gate.error = "This account already has a PIN. Enter it."
            } else {
                gate.error = "Something went wrong (" + status + ")."
            }
        }
    }

    Timer { id: coolTimer; interval: 30000; onTriggered: { gate.cooling = false; gate.error = "" } }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 340; height: col.height + 52
        radius: 16; color: "#15100a"; border.color: "#241c12"; border.width: 1

        Column {
            id: col
            anchors.top: parent.top; anchors.topMargin: 26
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 26; anchors.rightMargin: 26
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: gate.creating ? (gate.confirmStage ? "Confirm your PIN" : "Create your PIN") : "Enter your PIN"
                color: "#FFE082"; font.pixelSize: 20; font.bold: true
            }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: gate.creating ? "4-8 digits. You'll enter it to open the Staff section."
                                    : (ProctorClient.displayName.length ? "Welcome back, " + ProctorClient.displayName + "." : "Unlock the Staff section.")
                color: "#8a7a56"; font.pixelSize: 12
            }
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: "#0f0a06"; border.color: pinIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
                opacity: gate.cooling ? 0.45 : 1
                TextInput {
                    id: pinIn
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                    color: "#F2E8D0"; font.pixelSize: 24; font.family: "Menlo"; font.letterSpacing: 8
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: RegularExpressionValidator { regularExpression: /[0-9]{0,8}/ }
                    enabled: !gate.cooling && !gate.busy
                    clip: true
                    onAccepted: gate.submit()
                }
            }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                visible: gate.error.length > 0
                text: gate.error; color: "#e06c6c"; font.pixelSize: 12; wrapMode: Text.WordWrap
            }
            SButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: gate.busy ? "…" : gate.creating ? (gate.confirmStage ? "Confirm" : "Continue") : "Unlock"
                variant: "primary"
                enabled: !gate.cooling && !gate.busy && pinIn.text.length >= 4
                onClicked: gate.submit()
            }
        }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 8; duration: 70 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -5; duration: 60 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }
    }

    Component.onCompleted: pinIn.forceActiveFocus()
}
