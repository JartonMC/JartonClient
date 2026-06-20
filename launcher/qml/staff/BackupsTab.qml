import QtQuick
import Jarton

// Pterodactyl backups: list + create / download / restore / delete, over StaffApi.
Item {
    id: root
    property string serverId: ""
    property var backups: []
    property bool loading: false
    property bool creating: false
    property string error: ""
    property int reqList: -1
    property string loadedServer: ""
    property var pending: ({})   // ids of writes this tab issued; only these trigger a reload

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/backups")
    }
    function act(method, path, body) { root.pending[StaffApi.send(method, path, body)] = true }
    function fmtBytes(b) {
        if (!b || b <= 0) return "0 MB"
        var mb = b / 1048576
        return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
    }
    function relTime(iso) {
        if (!iso) return ""
        var t = Date.parse(iso)
        if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        var m = Math.floor(d / 60000); return Math.max(1, m) + "m ago"
    }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false; root.creating = false
                if (ok) { try { root.backups = JSON.parse(body).backups || [] } catch (e) { root.backups = [] } }
                else root.error = "Couldn't load backups."
                return
            }
            // an action THIS tab issued finished — open a download url if present, then refresh
            if (root.pending[id] === undefined) return
            delete root.pending[id]
            if (ok && body.indexOf("\"url\"") !== -1) {
                try { Qt.openUrlExternally(JSON.parse(body).url) } catch (e) {}
            }
            root.load()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 12

        Item {
            width: parent.width; height: 36
            Text {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: "Backups"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton { text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
                SButton {
                    text: root.creating ? "Creating…" : "New backup"; glyph: "＋"; variant: "primary"; busy: root.creating
                    onClicked: { root.creating = true; root.act("POST", "/servers/" + root.serverId + "/backups", "{}") }
                }
            }
        }

        Text {
            width: parent.width; visible: root.error.length > 0
            text: root.error; color: "#e06c6c"; font.pixelSize: 13
        }

        ListView {
            width: parent.width; height: parent.height - 50
            clip: true; spacing: 6
            model: root.backups
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 11
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.name; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            visible: modelData.completedAt === null || modelData.completedAt === undefined
                            width: ipTxt.width + 14; height: 17; radius: 8; color: "#3a2f14"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: ipTxt; anchors.centerIn: parent; text: "creating"; color: "#FFB81C"; font.pixelSize: 9; font.bold: true }
                        }
                        Rectangle {
                            visible: modelData.locked === true
                            width: lkTxt.width + 14; height: 17; radius: 8; color: "#23311f"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: lkTxt; anchors.centerIn: parent; text: "locked"; color: "#5ad17a"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Text {
                        text: root.fmtBytes(modelData.bytes) + "  ·  " + root.relTime(modelData.createdAt)
                        color: "#8a7a56"; font.pixelSize: 12
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 7
                    SButton {
                        text: "Download"; variant: "secondary"
                        onClicked: root.act("GET", "/servers/" + root.serverId + "/backups/" + modelData.uuid + "/download")
                    }
                    SButton {
                        text: "Restore"; variant: "secondary"
                        onClicked: root.act("POST", "/servers/" + root.serverId + "/backups/" + modelData.uuid + "/restore", "{}")
                    }
                    SButton {
                        text: "Delete"; variant: "danger"
                        onClicked: root.act("DELETE", "/servers/" + root.serverId + "/backups/" + modelData.uuid)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.loading && root.backups.length === 0
                text: "No backups yet."; color: "#6b5d3f"; font.pixelSize: 14
            }
        }
    }
}
