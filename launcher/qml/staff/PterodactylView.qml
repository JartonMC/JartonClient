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
            width: parent.width; height: 42; radius: 9
            color: "#1a140e"
            border.color: keyInput.activeFocus ? "#FFB81C" : "#332a14"
            border.width: 1
            TextInput {
                id: keyInput
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: "#FFFFFF"; font.pixelSize: 14
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

        Rectangle {
            width: parent.width; height: 44; radius: 9
            color: connectArea.containsMouse ? "#FFC93C" : "#FFB81C"
            opacity: StaffAuth.panelKeyBusy ? 0.6 : 1.0
            Text {
                anchors.centerIn: parent
                text: StaffAuth.panelKeyBusy ? "Connecting…" : "Connect key"
                color: "#1a140e"; font.pixelSize: 15; font.bold: true
            }
            MouseArea {
                id: connectArea
                anchors.fill: parent; hoverEnabled: true
                enabled: !StaffAuth.panelKeyBusy
                cursorShape: Qt.PointingHandCursor
                onClicked: view.doConnect()
            }
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

        Row {
            width: parent.width
            Text {
                text: "Servers"
                color: "#FFE082"; font.pixelSize: 18; font.bold: true
            }
            Item { width: parent.width - 120; height: 1 }
            Rectangle {
                width: 80; height: 28; radius: 7
                color: refreshArea.containsMouse ? "#221a0f" : "transparent"
                border.color: "#8B6F2A"; border.width: 1
                Text { anchors.centerIn: parent; text: ServerListModel.loading ? "…" : "Refresh"; color: "#FFE082"; font.pixelSize: 12 }
                MouseArea {
                    id: refreshArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServerListModel.refresh()
                }
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
                height: 58
                radius: 10
                color: rowArea.containsMouse ? "#221a0f" : "#16110a"
                border.color: "#332a14"; border.width: 1

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
                    anchors.left: parent.left; anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: 5
                    color: state === "running" ? "#5ad17a" : (state === "starting" ? "#FFB81C" : "#e06c6c")
                }
                Column {
                    anchors.left: dot.right; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: name; color: "#FFFFFF"; font.pixelSize: 15; font.bold: true }
                    Text {
                        text: node + "  ·  " + state + "  ·  " + playersOnline + "/" + playersMax + " players"
                        color: "#9a8a66"; font.pixelSize: 12
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(cpu) + "%  ·  " + Math.round(memBytes / 1048576) + "/" + memLimitMb + " MB"
                    color: "#9a8a66"; font.pixelSize: 12
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
