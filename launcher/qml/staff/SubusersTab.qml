import QtQuick
import Jarton

// Pterodactyl subusers: list + remove, over StaffApi. (Add/edit needs a permission
// picker — comes in a later pass; this covers viewing + removing access.)
Item {
    id: root
    property string serverId: ""
    property var users: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property string loadedServer: ""

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/users")
    }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.users = JSON.parse(body).users || [] } catch (e) { root.users = [] } }
                else root.error = "Couldn't load subusers."
                return
            }
            root.load()
        }
    }

    Column {
        anchors.fill: parent; spacing: 12
        Item {
            width: parent.width; height: 36
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Subusers"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 50; clip: true; spacing: 6
            model: root.users
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 11
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.email; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            visible: modelData.twoFactorEnabled === true
                            width: tf.width + 14; height: 17; radius: 8; color: "#23311f"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: tf; anchors.centerIn: parent; text: "2FA"; color: "#5ad17a"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Text { text: (modelData.username && modelData.username.length ? modelData.username + "   ·   " : "") + (modelData.permissions ? modelData.permissions.length : 0) + " permissions"; color: "#8a7a56"; font.pixelSize: 12 }
                }
                SButton {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: "Remove"; variant: "danger"
                    onClicked: StaffApi.send("DELETE", "/servers/" + root.serverId + "/users/" + modelData.uuid)
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.users.length === 0; text: "No subusers."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
