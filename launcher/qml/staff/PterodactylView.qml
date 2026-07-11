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
            syncStatus()
        } else {
            StaffAuth.checkPanelKey()
        }
    }

    // live stats: the broker snapshots /servers for ~3s, so a 10s quiet poll
    // keeps CPU/RAM/players moving without hammering anything. Runs in the
    // detail view too — its PLAYERS tile reads from this model.
    readonly property int listRefreshMs: 10000
    Timer {
        interval: view.listRefreshMs; repeat: true
        running: view.visible && StaffAuth.panelKeyConnected
        onTriggered: ServerListModel.refresh(true)
    }

    // main→test sync flags (consumed by the 4AM cycle on the box)
    property bool syncAvailable: false
    property bool syncPending: false
    property bool syncForce: false
    property bool syncConfirming: false
    property int reqSyncStatus: -1
    property var pendingSync: ({})
    readonly property bool syncQueued: syncPending || syncForce

    function syncStatus() { reqSyncStatus = StaffApi.send("GET", "/sync/status") }
    function syncAct(method, body) { pendingSync[StaffApi.send(method, "/sync/queue", body)] = true }
    function applySync(body) {
        try {
            var s = JSON.parse(body)
            syncPending = s.pending === true
            syncForce = s.force === true
            syncAvailable = true
        } catch (e) {}
    }
    Timer {
        interval: 30000; repeat: true
        running: view.visible && view.syncAvailable
        onTriggered: view.syncStatus()
    }
    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === view.reqSyncStatus) {
                if (ok) view.applySync(body)
                else view.syncAvailable = false   // 403/503: no button for this account/broker
                return
            }
            if (view.pendingSync[id] !== undefined) {
                delete view.pendingSync[id]
                if (ok) view.applySync(body)
            }
        }
    }
    onVisibleChanged: if (visible && StaffAuth.panelKeyConnected) syncStatus()

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
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: view.syncQueued
                    width: syncTxt.width + 18; height: 22; radius: 11
                    color: Qt.rgba(1, 0.72, 0.2, 0.14)
                    Text {
                        id: syncTxt; anchors.centerIn: parent
                        text: view.syncForce ? "force sync queued" : "sync queued"
                        color: "#FFB833"; font.pixelSize: 12; font.bold: true
                    }
                }
                SButton {
                    visible: view.syncAvailable
                    text: view.syncQueued ? "Cancel sync" : "Queue sync"
                    icon: view.syncQueued ? "x" : "clock"
                    variant: view.syncQueued ? "danger" : "secondary"
                    onClicked: {
                        if (view.syncQueued) view.syncAct("DELETE", "")
                        else view.syncConfirming = !view.syncConfirming
                    }
                }
                SButton {
                    text: ServerListModel.loading ? "Refreshing…" : "Refresh"
                    icon: "refresh"; variant: "secondary"
                    onClicked: ServerListModel.refresh()
                }
            }
        }

        // inline confirm for queueing the main→test sync
        Rectangle {
            width: parent.width; radius: 11; visible: view.syncConfirming && !view.syncQueued
            height: syncRow.height + 22
            color: "#15100a"; border.color: "#FFB81C"; border.width: 1
            Row {
                id: syncRow
                anchors.left: parent.left; anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Queue the main → test sync?"
                    color: "#FFE082"; font.pixelSize: 13
                }
                SButton {
                    text: "Next 4AM cycle"; variant: "primary"; compact: true
                    onClicked: { view.syncAct("POST", "{}"); view.syncConfirming = false }
                }
                SButton {
                    text: "Force now"; variant: "danger"; compact: true
                    onClicked: { view.syncAct("POST", JSON.stringify({ force: true })); view.syncConfirming = false }
                }
                SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: view.syncConfirming = false }
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
                            id: cpuRow
                            spacing: 7
                            // cpu_absolute is per-core cumulative (4 cores allowed = up to 400%);
                            // normalize the bar against the panel's cpu limit, 0 = unlimited
                            readonly property real ceil: cpuLimit > 0 ? cpuLimit : 100
                            readonly property real frac: cpu / ceil
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "CPU"; color: "#8a7a56"; font.pixelSize: 9; font.bold: true }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72; height: 5; radius: 2; color: Qt.rgba(1, 1, 1, 0.09)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, cpuRow.frac)); height: parent.height; radius: 2
                                    color: cpuRow.frac > 0.85 ? "#e06c6c" : "#FFB833"
                                }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(cpu) + "%"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.family: "Menlo" }
                        }
                        Row {
                            id: ramRow
                            spacing: 7
                            // limits.memory = 0 means unlimited on the panel — no meaningful fraction, so no bar
                            readonly property bool unlimited: memLimitMb <= 0
                            readonly property real frac: unlimited ? 0 : (memBytes / 1048576) / memLimitMb
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "RAM"; color: "#8a7a56"; font.pixelSize: 9; font.bold: true }
                            Rectangle {
                                visible: !ramRow.unlimited
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72; height: 5; radius: 2; color: Qt.rgba(1, 1, 1, 0.09)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, ramRow.frac)); height: parent.height; radius: 2
                                    color: ramRow.frac > 0.9 ? "#e06c6c" : "#FFB833"
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ramRow.unlimited ? Math.round(memBytes / 1048576) + " MB"
                                                       : Math.round(memBytes / 1048576) + "/" + memLimitMb + " MB"
                                color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.family: "Menlo"
                            }
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
