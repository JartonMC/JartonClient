import QtQuick
import Jarton

// Open tickets queue (read) — click a row to open the ticket channel in Discord.
Item {
    id: root
    property var tickets: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property bool loadedOnce: false

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/tickets") }
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
            if (id !== root.reqList) return
            root.loading = false
            if (ok) { try { root.tickets = JSON.parse(body).tickets || [] } catch (e) { root.tickets = [] } }
            else root.error = "Couldn't load tickets."
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Open tickets"; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 6
            model: root.tickets
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 10
                color: tArea.containsMouse ? "#221a0f" : "#16110a"
                border.color: tArea.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1
                Image {
                    id: tHead; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; fillMode: Image.PreserveAspectFit; smooth: false
                    visible: !!modelData.openerAvatar
                    source: modelData.openerAvatar ? modelData.openerAvatar : ""
                }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: modelData.openerAvatar ? 52 : 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.openerName ? modelData.openerName : "Unknown"; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            visible: modelData.claimed === true
                            width: cl.width + 14; height: 17; radius: 8; color: "#23311f"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: cl; anchors.centerIn: parent; text: "claimed"; color: "#5ad17a"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Text { text: (modelData.category ? modelData.category : "ticket") + "   ·   " + root.relTime(modelData.createdAt); color: "#8a7a56"; font.pixelSize: 12 }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "open ↗"; color: "#6b5d3f"; font.pixelSize: 12 }
                MouseArea {
                    id: tArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (modelData.deepLink) Qt.openUrlExternally(modelData.deepLink)
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.tickets.length === 0; text: "No open tickets."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
