import QtQuick
import Jarton

// Docked staff area. You reach it already signed into Discord (the sidebar only shows
// a section's tab once StaffAuth resolves the matching capability), so Pterodactyl and
// Swifty need no further login. The Staff section is hybrid: it additionally requires
// the separate Proctor username/password session, so the login form below is scoped to
// that section only. The active section is ProctorClient.currentSection (a shared
// singleton property — the sidebar and this panel are separate QML engines).
Rectangle {
    id: panel
    color: "#0f0a06"
    focus: true

    readonly property string section: ProctorClient.currentSection
    readonly property bool needsProctorLogin: section === "staff" && !ProctorClient.connected && !ProctorClient.restoring
    readonly property bool sectionPopped: section === "ptero" ? ProctorClient.pteroPopped
                                        : section === "staff" ? ProctorClient.staffPopped
                                        : section === "swifty" ? ProctorClient.swiftyPopped : false

    function sectionTitle(s) {
        return s === "ptero" ? "Pterodactyl" : s === "staff" ? "Staff" : s === "swifty" ? "Swifty" : ""
    }

    // ---- Staff section: Proctor login (hybrid second factor) ----
    Column {
        anchors.centerIn: parent
        width: 300
        spacing: 14
        visible: panel.needsProctorLogin

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

    // ---- the selected section ----
    Item {
        anchors.fill: parent
        visible: !panel.needsProctorLogin

        // No section content loads here: every section lives in its own QQuickView
        // that MainWindow stacks over this panel while docked (Swifty's native
        // webview can't attach to this QQuickWidget's offscreen scene, and hosting
        // ptero/staff the same way keeps their views warm across section hops).
        // This panel is just the docked backdrop, the proctor login gate above,
        // and the placeholder below while a section is popped out into its own window.
        Column {
            anchors.centerIn: parent
            spacing: 14
            visible: panel.sectionPopped && (panel.section !== "staff" || ProctorClient.connected)
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "qrc:/jarton/staff/icons/ui/external-link-rest.svg"
                width: 28; height: 28; sourceSize: Qt.size(56, 56)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.sectionTitle(panel.section) + " is open in its own window"
                color: "#FFE082"; font.pixelSize: 16; font.bold: true
            }
            SButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bring back"; icon: "corner-down-left"; variant: "secondary"
                onClicked: ProctorClient.requestSectionPop(panel.section, false)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: panel.section === "staff" && ProctorClient.restoring
            text: "Connecting…"
            color: "#9a8a66"; font.pixelSize: 14
        }

        Text {
            anchors.centerIn: parent
            visible: panel.section !== "ptero" && panel.section !== "staff" && panel.section !== "swifty"
            text: panel.section === "" ? "Select a staff tab from the sidebar."
                                       : panel.sectionTitle(panel.section) + " — coming soon"
            color: "#9a8a66"; font.pixelSize: 16
        }
    }
}
