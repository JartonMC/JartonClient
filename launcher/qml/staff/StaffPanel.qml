import QtQuick
import Jarton

// Docked staff area. Logged-out: a Proctor login form. Logged-in: whichever section
// the sidebar selected (set via the `section` property from C++). One ProctorClient
// singleton backs every section + window. No internal section menu — the sidebar's
// separate Staff / Pterodactyl / Swifty buttons drive `section` directly.
Rectangle {
    id: panel
    color: "#0f0a06"
    focus: true

    // "staff" | "ptero" | "swifty" — set by the host when a sidebar tab is picked.
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
                color: "#FFFFFF"; font.pixelSize: 15
                clip: true
                onAccepted: passInput.forceActiveFocus()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Username"; color: "#6b5d3f"; font.pixelSize: 15
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
                color: "#FFFFFF"; font.pixelSize: 15
                echoMode: TextInput.Password
                clip: true
                onAccepted: panel.doSignIn()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"; color: "#6b5d3f"; font.pixelSize: 15
                    visible: passInput.text.length === 0 && !passInput.activeFocus
                }
            }
        }

        Text {
            width: parent.width
            text: ProctorClient.loginError
            color: "#e06c6c"; font.pixelSize: 13
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
                color: "#1a140e"; font.pixelSize: 15; font.bold: true
            }
            MouseArea {
                id: signInArea
                anchors.fill: parent; hoverEnabled: true
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

    // ---- logged-in: the selected section ----
    Item {
        anchors.fill: parent
        visible: ProctorClient.connected

        Loader {
            anchors.fill: parent
            active: ProctorClient.connected && (panel.section === "ptero" || panel.section === "staff")
            source: panel.section === "ptero" ? "qrc:/jarton/staff/PterodactylView.qml"
                  : panel.section === "staff" ? "qrc:/jarton/staff/StaffSectionView.qml" : ""
        }

        Text {
            anchors.centerIn: parent
            visible: panel.section !== "ptero" && panel.section !== "staff"
            text: panel.section === "" ? "Select a staff tab from the sidebar."
                                       : panel.sectionTitle(panel.section) + " — coming soon"
            color: "#9a8a66"; font.pixelSize: 16
        }

        // Minimal sign-out for now; account controls move to Settings later.
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 12
            width: 92; height: 28; radius: 8
            color: outArea.containsMouse ? "#2a1414" : "transparent"
            border.color: "#5c3a3a"; border.width: 1
            Text { anchors.centerIn: parent; text: "Sign out"; color: "#e0a0a0"; font.pixelSize: 12 }
            MouseArea {
                id: outArea
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ProctorClient.signOut()
            }
        }
    }
}
