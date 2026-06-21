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
        spacing: 12
        visible: StaffAuth.panelKeyConnected && view.detailId === ""

        Item {
            width: parent.width; height: 38
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Servers"; color: "#FFFFFF"; font.pixelSize: 21; font.bold: true }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ServerListModel.totalOnline >= 0
                    width: onlineTxt.width + 18; height: 22; radius: 11
                    color: Qt.rgba(1, 0.72, 0.2, 0.14)
                    Text {
                        id: onlineTxt; anchors.centerIn: parent
                        text: ServerListModel.totalOnline + " online"
                        color: "#FFB833"; font.pixelSize: 12; font.bold: true
                    }
                }
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
            height: parent.height - 52
            clip: true
            spacing: 10
            model: ServerListModel
            delegate: Rectangle {
                id: card
                width: ListView.view.width
                height: 84
                radius: 18
                color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
                Behavior on color { ColorAnimation { duration: 120 } }
                border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                readonly property bool isUp: model.state === "running"
                readonly property bool isTransition: model.state === "starting" || model.state === "stopping"
                readonly property color stateColor: isUp ? "#5ad17a" : isTransition ? "#FFB833" : "#7a6f63"

                MouseArea {
                    id: rowArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.detailId = serverId
                        PteroServer.open(serverId, name)
                    }
                }

                // pulsing status dot
                Item {
                    id: dot
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    Rectangle {
                        anchors.centerIn: parent; width: 10; height: 10; radius: 5
                        color: card.stateColor
                    }
                    Rectangle {
                        id: pulse
                        anchors.centerIn: parent; width: 10; height: 10; radius: width / 2
                        color: "transparent"; border.width: 2; border.color: card.stateColor
                        visible: card.isUp || card.isTransition
                        SequentialAnimation on opacity {
                            running: card.isUp || card.isTransition; loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 200 }
                        }
                        ParallelAnimation {
                            running: card.isUp || card.isTransition; loops: Animation.Infinite
                            NumberAnimation { target: pulse; property: "scale"; from: 1.0; to: 2.6; duration: 1600; easing.type: Easing.OutQuad }
                        }
                    }
                }
                Column {
                    anchors.left: dot.right; anchors.leftMargin: 16
                    anchors.right: rightRow.left; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9
                    Item {
                        width: parent.width; height: nameTxt.height
                        Text {
                            id: nameTxt
                            anchors.left: parent.left; anchors.right: nodeTxt.left; anchors.rightMargin: 8
                            text: name; color: "#FFFFFF"; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight
                        }
                        Text {
                            id: nodeTxt
                            anchors.right: parent.right; anchors.verticalCenter: nameTxt.verticalCenter
                            text: node; color: Qt.rgba(1, 1, 1, 0.32); font.pixelSize: 11; font.family: "Menlo"
                        }
                    }
                    Row {
                        spacing: 18
                        Row {
                            spacing: 7
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "CPU"; color: "#8a7a56"; font.pixelSize: 9; font.bold: true }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72; height: 5; radius: 2; color: Qt.rgba(1, 1, 1, 0.09)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, cpu / 100)); height: parent.height; radius: 2
                                    color: cpu > 85 ? "#e06c6c" : "#FFB833"
                                }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(cpu) + "%"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.family: "Menlo" }
                        }
                        Row {
                            id: ramRow
                            spacing: 7
                            readonly property real frac: memLimitMb > 0 ? (memBytes / 1048576) / memLimitMb : 0
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "RAM"; color: "#8a7a56"; font.pixelSize: 9; font.bold: true }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72; height: 5; radius: 2; color: Qt.rgba(1, 1, 1, 0.09)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, ramRow.frac)); height: parent.height; radius: 2
                                    color: ramRow.frac > 0.9 ? "#e06c6c" : "#FFB833"
                                }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(memBytes / 1048576) + "/" + memLimitMb + " MB"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.family: "Menlo" }
                        }
                    }
                }
                Row {
                    id: rightRow
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: pcTxt.width + 18; height: 24; radius: 12
                        color: Qt.rgba(1, 0.72, 0.2, 0.14)
                        Text {
                            id: pcTxt; anchors.centerIn: parent
                            text: playersOnline + "/" + playersMax
                            color: "#FFB833"; font.pixelSize: 13; font.bold: true; font.family: "Menlo"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 20
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
