import QtQuick
import Jarton

// Server/crash alert history (read): crashes, recoveries, bridge up/down, mass-disconnects.
Item {
    id: root
    property var alerts: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property bool loadedOnce: false

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/crash-alerts?limit=150") }
    function relTime(s) {
        if (!s) return ""
        var iso = (("" + s).indexOf("T") === -1) ? ("" + s).replace(" ", "T") + "Z" : s
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }
    function label(type) {
        switch (type) {
        case "crash": return "Crash"
        case "out-of-memory": return "Out of memory"
        case "watchdog-hang": return "Watchdog hang"
        case "crash-report": return "Crash report"
        case "tick-exception": return "Tick exception"
        case "startup-failure": return "Startup failure"
        case "error-spike": return "Error spike"
        case "recovered": return "Recovered"
        case "mass-disconnect": return "Mass disconnect"
        case "bridge-offline": return "Bridge offline"
        case "bridge-online": return "Bridge back"
        default: return type
        }
    }
    function sevColor(s) { return s === "high" ? "#e06c6c" : "#FFB81C" }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id !== root.reqList) return
            root.loading = false
            if (ok) { try { root.alerts = JSON.parse(body).alerts || [] } catch (e) { root.alerts = [] } }
            else root.error = "Couldn't load alerts."
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Server alerts"; color: "#F2E8D0"; font.pixelSize: 16; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 6
            model: root.alerts
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 10
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Rectangle {
                    id: sevDot; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 9; height: 9; radius: 5; color: root.sevColor(modelData.severity)
                }
                Column {
                    anchors.left: sevDot.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: root.label(modelData.type); color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Text { text: modelData.server_name; color: "#FFB81C"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.relTime(modelData.created_at); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: modelData.detail ? modelData.detail : ""; color: "#8a7a56"; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width; visible: text.length > 0 }
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.alerts.length === 0; text: "No alerts."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
