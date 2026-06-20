import QtQuick
import Jarton

// Player reports queue — resolve clears them. Heads via crafatar.
Item {
    id: root
    property var reports: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property bool loadedOnce: false

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/reports") }
    function relTime(ms) {
        if (!ms || ms <= 0) return ""
        var d = Date.now() - Number(ms)
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.reports = JSON.parse(body).reports || [] } catch (e) { root.reports = [] } }
                else root.error = "Couldn't load reports."
                return
            }
            root.load()  // a resolve finished — refresh
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Reports"; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 6
            model: root.reports
            delegate: Rectangle {
                width: ListView.view.width; height: 64; radius: 10
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Avatar {
                    id: rHead; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    size: 30; uuid: modelData.targetUuid ? modelData.targetUuid : ""
                    visible: !!modelData.targetUuid
                }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: modelData.targetUuid ? 54 : 14
                    anchors.right: resolveBtn.left; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.targetName; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Text { text: modelData.category; color: "#FFB81C"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.relTime(modelData.timestamp); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: modelData.reason; color: "#cfc3a6"; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                    Text { text: "by " + modelData.reporterName; color: "#6b5d3f"; font.pixelSize: 11 }
                }
                SButton {
                    id: resolveBtn
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: "Resolve"; variant: "secondary"
                    onClicked: ProctorApi.send("POST", "/proctor/reports/" + modelData.id + "/resolve", "{}")
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.reports.length === 0; text: "No open reports."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
