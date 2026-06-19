import QtQuick
import Jarton

// Pterodactyl databases: list + rotate password + delete, over StaffApi.
Item {
    id: root
    property string serverId: ""
    property var databases: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property string loadedServer: ""

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/databases")
    }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.databases = JSON.parse(body).databases || [] } catch (e) { root.databases = [] } }
                else root.error = "Couldn't load databases."
                return
            }
            root.load()
        }
    }

    Column {
        anchors.fill: parent; spacing: 12
        Item {
            width: parent.width; height: 36
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Databases"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 50; clip: true; spacing: 6
            model: root.databases
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 11
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: modelData.name; color: "#F2E8D0"; font.family: "Menlo"; font.pixelSize: 14; font.bold: true }
                    Text { text: modelData.username + "   ·   from " + (modelData.remote && modelData.remote.length ? modelData.remote : "%"); color: "#8a7a56"; font.family: "Menlo"; font.pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                    SButton { text: "Rotate password"; variant: "secondary"; onClicked: StaffApi.send("POST", "/servers/" + root.serverId + "/databases/" + modelData.id + "/rotate-password", "{}") }
                    SButton { text: "Delete"; variant: "danger"; onClicked: StaffApi.send("DELETE", "/servers/" + root.serverId + "/databases/" + modelData.id) }
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.databases.length === 0; text: "No databases."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
