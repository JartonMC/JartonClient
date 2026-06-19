import QtQuick
import Jarton

// Pending staff applications (read) — click to open the application thread in Discord.
Item {
    id: root
    property var apps: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property var pendingWrites: []
    property bool loadedOnce: false

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/applications") }
    function resolve(id) { var p = pendingWrites; p.push(ProctorApi.send("POST", "/proctor/applications/" + id + "/resolve", "")); pendingWrites = p }
    function relTime(s) {
        if (!s) return ""
        var iso = (("" + s).indexOf("T") === -1) ? ("" + s).replace(" ", "T") + "Z" : s
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.apps = JSON.parse(body).applications || [] } catch (e) { root.apps = [] } }
                else root.error = "Couldn't load applications."
                return
            }
            var idx = root.pendingWrites.indexOf(id)
            if (idx !== -1) { root.pendingWrites.splice(idx, 1); root.load() }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Applications"; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 6
            model: root.apps
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 10
                color: aArea.containsMouse ? "#221a0f" : "#16110a"
                border.color: aArea.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1
                Image {
                    id: aHead; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; fillMode: Image.PreserveAspectFit; smooth: false
                    visible: !!modelData.userAvatar
                    source: modelData.userAvatar ? modelData.userAvatar : ""
                }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: modelData.userAvatar ? 52 : 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: modelData.userName ? modelData.userName : "Unknown"; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                    Text { text: (modelData.role ? modelData.role : "applicant") + "   ·   " + root.relTime(modelData.submittedAt); color: "#8a7a56"; font.pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 7; z: 2
                    SButton { text: "Open ↗"; variant: "ghost"; onClicked: if (modelData.deepLink) Qt.openUrlExternally(modelData.deepLink) }
                    SButton { text: "Resolve"; variant: "primary"; onClicked: root.resolve(modelData.id) }
                }
                MouseArea {
                    id: aArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 1
                    onClicked: if (modelData.deepLink) Qt.openUrlExternally(modelData.deepLink)
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.apps.length === 0; text: "No pending applications."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
