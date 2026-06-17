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

    property string section: ""
    function sectionTitle(s) {
        return s === "ptero" ? "Pterodactyl" : s === "staff" ? "Staff" : s === "swifty" ? "Swifty" : ""
    }

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

    // ---- logged-in: section navigation ----
    Item {
        anchors.fill: parent
        visible: ProctorClient.connected

        // header: back (in a section) + title
        Row {
            id: hdr
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: 34
            spacing: 10

            Rectangle {
                visible: panel.section !== ""
                width: 64; height: 32; radius: 8
                color: backArea.containsMouse ? "#221a0f" : "transparent"
                border.color: "#8B6F2A"; border.width: 1
                Text { anchors.centerIn: parent; text: "‹ Back"; color: "#FFE082"; font.pixelSize: 13 }
                MouseArea {
                    id: backArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.section = ""
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (panel.section !== "" ? 84 : 0)
                text: panel.section === ""
                      ? ("Signed in as " + ProctorClient.displayName +
                         (ProctorClient.rank.length > 0 ? "  ·  " + ProctorClient.rank : ""))
                      : panel.sectionTitle(panel.section)
                color: "#FFE082"; font.pixelSize: 15; font.bold: true
                elide: Text.ElideRight
            }
        }

        // content
        Item {
            anchors.top: hdr.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.topMargin: 6

            // section list
            Column {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 14
                width: 320
                spacing: 12
                visible: panel.section === ""

                Repeater {
                    model: [
                        { key: "ptero", label: "Pterodactyl", ready: true },
                        { key: "staff", label: "Staff", ready: false },
                        { key: "swifty", label: "Swifty", ready: false }
                    ]
                    Rectangle {
                        width: 320; height: 52; radius: 10
                        color: secHover.containsMouse && modelData.ready ? "#221a0f" : "#16110a"
                        border.color: "#332a14"; border.width: 1
                        opacity: modelData.ready ? 1.0 : 0.5
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: "#FFFFFF"; font.pixelSize: 16
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.ready ? "›" : "soon"
                            color: "#6b5d3f"; font.pixelSize: modelData.ready ? 18 : 12
                        }
                        MouseArea {
                            id: secHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: modelData.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (modelData.ready) panel.section = modelData.key
                        }
                    }
                }
            }

            // section view
            Loader {
                anchors.fill: parent
                active: panel.section !== ""
                source: panel.section === "ptero" ? "qrc:/jarton/staff/PterodactylView.qml" : ""
            }
        }

        // footer: pop out + sign out
        Row {
            id: footer
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 12
            spacing: 10

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
                    onClicked: { panel.section = ""; ProctorClient.signOut() }
                }
            }
        }
    }
}
