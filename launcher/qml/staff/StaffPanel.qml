import QtQuick
import Jarton

// Staff panel — Phase 0 shell. Logged-out: a Proctor login form. Logged-in: a
// placeholder with the three section buttons (Pterodactyl / Staff / Swifty, wired
// in later phases) plus pop-out and sign-out. The ProctorClient singleton is shared
// across every engine, so a docked panel and a popped-out window stay in lockstep.
Rectangle {
    id: panel
    color: "#0f0a06"
    focus: true

    signal popOutRequested()

    // ---- logged-out: login ----
    Column {
        anchors.centerIn: parent
        width: 300
        spacing: 14
        visible: !ProctorClient.connected

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Jarton Staff"
            color: "#FFE082"
            font.pixelSize: 22
            font.bold: true
        }

        Rectangle {
            width: parent.width; height: 42; radius: 9
            color: "#1a140e"
            border.color: userInput.activeFocus ? "#FFB81C" : "#332a14"
            border.width: 1
            TextInput {
                id: userInput
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: "#FFFFFF"
                font.pixelSize: 15
                clip: true
                onAccepted: passInput.forceActiveFocus()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Username"
                    color: "#6b5d3f"
                    font.pixelSize: 15
                    visible: userInput.text.length === 0 && !userInput.activeFocus
                }
            }
        }

        Rectangle {
            width: parent.width; height: 42; radius: 9
            color: "#1a140e"
            border.color: passInput.activeFocus ? "#FFB81C" : "#332a14"
            border.width: 1
            TextInput {
                id: passInput
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: "#FFFFFF"
                font.pixelSize: 15
                echoMode: TextInput.Password
                clip: true
                onAccepted: panel.doSignIn()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    color: "#6b5d3f"
                    font.pixelSize: 15
                    visible: passInput.text.length === 0 && !passInput.activeFocus
                }
            }
        }

        Text {
            width: parent.width
            text: ProctorClient.loginError
            color: "#e06c6c"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            visible: ProctorClient.loginError.length > 0
        }

        Rectangle {
            width: parent.width; height: 44; radius: 9
            color: signInArea.containsMouse ? "#FFC93C" : "#FFB81C"
            opacity: ProctorClient.signingIn ? 0.6 : 1.0
            Text {
                anchors.centerIn: parent
                text: ProctorClient.signingIn ? "Signing in…" : "Sign in"
                color: "#1a140e"
                font.pixelSize: 15
                font.bold: true
            }
            MouseArea {
                id: signInArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !ProctorClient.signingIn
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.doSignIn()
            }
        }
    }

    function doSignIn() {
        if (userInput.text.length === 0 || passInput.text.length === 0)
            return
        ProctorClient.signIn(userInput.text, passInput.text)
    }

    // ---- logged-in: section placeholder ----
    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 28
        width: 320
        spacing: 12
        visible: ProctorClient.connected

        Text {
            width: parent.width
            text: "Signed in as " + ProctorClient.displayName +
                  (ProctorClient.rank.length > 0 ? "  ·  " + ProctorClient.rank : "")
            color: "#FFE082"
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: ["Pterodactyl", "Staff", "Swifty"]
            Rectangle {
                width: 320; height: 52; radius: 10
                color: secHover.containsMouse ? "#221a0f" : "#16110a"
                border.color: "#332a14"; border.width: 1
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: "#FFFFFF"; font.pixelSize: 16
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "soon"
                    color: "#6b5d3f"; font.pixelSize: 12
                }
                MouseArea { id: secHover; anchors.fill: parent; hoverEnabled: true }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            topPadding: 6

            Rectangle {
                width: 150; height: 40; radius: 9
                color: popArea.containsMouse ? "#221a0f" : "transparent"
                border.color: "#8B6F2A"; border.width: 1
                Text { anchors.centerIn: parent; text: "Pop out ⧉"; color: "#FFE082"; font.pixelSize: 14 }
                MouseArea {
                    id: popArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.popOutRequested()
                }
            }
            Rectangle {
                width: 150; height: 40; radius: 9
                color: outArea.containsMouse ? "#2a1414" : "transparent"
                border.color: "#5c3a3a"; border.width: 1
                Text { anchors.centerIn: parent; text: "Sign out"; color: "#e0a0a0"; font.pixelSize: 14 }
                MouseArea {
                    id: outArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ProctorClient.signOut()
                }
            }
        }
    }
}
