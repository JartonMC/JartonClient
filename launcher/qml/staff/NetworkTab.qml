import QtQuick
import Jarton

// Pterodactyl network allocations: list + set-primary, over StaffApi.
Item {
    id: root
    property string serverId: ""
    property var allocations: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property string loadedServer: ""

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/network")
    }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.allocations = JSON.parse(body).allocations || [] } catch (e) { root.allocations = [] } }
                else root.error = "Couldn't load allocations."
                return
            }
            root.load()
        }
    }

    Column {
        anchors.fill: parent; spacing: 12
        Item {
            width: parent.width; height: 36
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Network"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 50; clip: true; spacing: 6
            model: root.allocations
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 11
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.ip + ":" + modelData.port; color: "#F2E8D0"; font.family: "Menlo"; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            visible: modelData.isDefault === true
                            width: pTxt.width + 14; height: 17; radius: 8; color: "#3a2f14"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: pTxt; anchors.centerIn: parent; text: "primary"; color: "#FFB81C"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Text {
                        text: (modelData.alias && modelData.alias.length ? modelData.alias + "   ·   " : "") + (modelData.notes && modelData.notes.length ? modelData.notes : "no notes")
                        color: "#8a7a56"; font.pixelSize: 12; elide: Text.ElideRight; width: root.width - 220
                    }
                }
                SButton {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.isDefault !== true
                    text: "Make primary"; variant: "secondary"
                    onClicked: StaffApi.send("POST", "/servers/" + root.serverId + "/network/" + modelData.id + "/primary", "{}")
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.allocations.length === 0; text: "No allocations."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
