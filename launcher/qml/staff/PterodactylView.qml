import QtQuick
import Jarton

// Pterodactyl section: panel-key connect gate -> server list -> server detail
// (power + live console + stats). Files / backups / schedules etc. land next.
Item {
    id: view

    property bool loadedOnce: false
    property string detailId: ""   // non-empty -> showing a single server's detail

    Component.onCompleted: {
        if (StaffAuth.panelKeyConnected) {
            loadedOnce = true
            ServerListModel.refresh()
        } else {
            StaffAuth.checkPanelKey()
        }
    }

    Connections {
        target: StaffAuth
        function onChanged() {
            if (StaffAuth.panelKeyConnected && !view.loadedOnce) {
                view.loadedOnce = true
                ServerListModel.refresh()
            }
        }
    }

    // ---- connect-key prompt ----
    Column {
        anchors.centerIn: parent
        width: 320
        spacing: 12
        visible: !StaffAuth.panelKeyConnected && view.detailId === ""

        Text {
            width: parent.width
            text: "Connect your Pterodactyl panel key to manage servers."
            color: "#FFE082"
            font.pixelSize: 15
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            width: parent.width; height: 44; radius: 11
            color: "#15100a"
            border.color: keyInput.activeFocus ? "#FFB81C" : "#2a2114"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
            TextInput {
                id: keyInput
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: "#F2E8D0"; font.pixelSize: 14
                echoMode: TextInput.Password
                clip: true
                onAccepted: view.doConnect()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ptlc_…"
                    color: "#6b5d3f"; font.pixelSize: 14
                    visible: keyInput.text.length === 0 && !keyInput.activeFocus
                }
            }
        }

        Text {
            width: parent.width
            text: StaffAuth.panelKeyError
            color: "#e06c6c"; font.pixelSize: 13
            wrapMode: Text.WordWrap
            visible: StaffAuth.panelKeyError.length > 0
        }

        SButton {
            width: parent.width; height: 44
            text: StaffAuth.panelKeyBusy ? "Connecting…" : "Connect key"
            variant: "primary"; busy: StaffAuth.panelKeyBusy
            onClicked: view.doConnect()
        }
    }

    function doConnect() {
        if (keyInput.text.length > 0)
            StaffAuth.connectPanelKey(keyInput.text)
    }

    // ---- server list ----
    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        visible: StaffAuth.panelKeyConnected && view.detailId === ""

        Item {
            width: parent.width; height: 36
            Text {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: "Servers"; color: "#F2E8D0"; font.pixelSize: 20; font.bold: true
            }
            SButton {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: ServerListModel.loading ? "Refreshing…" : "Refresh"
                glyph: "↻"; variant: "secondary"
                onClicked: ServerListModel.refresh()
            }
        }

        Text {
            width: parent.width
            text: ServerListModel.error
            color: "#e06c6c"; font.pixelSize: 13
            visible: ServerListModel.error.length > 0
        }

        ListView {
            width: parent.width
            height: parent.height - 50
            clip: true
            spacing: 8
            model: ServerListModel
            delegate: Rectangle {
                width: ListView.view.width
                height: 62
                radius: 12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: rowArea.containsMouse ? "#241c10" : "#1a140d" }
                    GradientStop { position: 1.0; color: rowArea.containsMouse ? "#1b150e" : "#140f09" }
                }
                border.color: rowArea.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1

                MouseArea {
                    id: rowArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.detailId = serverId
                        PteroServer.open(serverId, name)
                    }
                }

                Rectangle {
                    id: dot
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: 5
                    // model.state, not state — every QML element has a built-in `state`
                    // property that would otherwise shadow the model role and read empty
                    color: model.state === "running" ? "#5ad17a"
                         : (model.state === "starting" || model.state === "stopping") ? "#FFB81C" : "#e06c6c"
                    Rectangle {
                        anchors.centerIn: parent; width: 18; height: 18; radius: 9
                        color: "transparent"; border.width: 2
                        border.color: parent.color; opacity: 0.25
                    }
                }
                Column {
                    anchors.left: dot.right; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { text: name; color: "#F2E8D0"; font.pixelSize: 15; font.bold: true }
                    Text {
                        text: node + "  ·  " + model.state + "  ·  " + playersOnline + "/" + playersMax + " players"
                        color: "#8a7a56"; font.pixelSize: 12
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(cpu) + "%  ·  " + Math.round(memBytes / 1048576) + "/" + memLimitMb + " MB"
                        color: "#8a7a56"; font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"; color: "#4a3f24"; font.pixelSize: 18
                    }
                }
            }
        }
    }

    // ---- single-server detail (power + live console) ----
    ServerDetailView {
        anchors.fill: parent
        visible: view.detailId !== ""
        onBack: {
            PteroServer.close()
            view.detailId = ""
            ServerListModel.refresh()
        }
    }
}
