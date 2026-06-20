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
    property int openIdx: -1

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
    function sevColor(s) { return s === "high" ? "#ff6b6b" : "#FFB833" }

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
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Server alerts"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 8
            model: root.alerts
            delegate: Rectangle {
                id: aCard
                required property var modelData
                required property int index
                readonly property bool open: root.openIdx === index
                width: ListView.view.width; height: aCol.height + 22; radius: 12; color: Qt.rgba(1, 1, 1, 0.04)
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Rectangle {
                    id: sevDot; anchors.left: parent.left; anchors.leftMargin: 16; anchors.top: parent.top; anchors.topMargin: 18
                    width: 9; height: 9; radius: 5; color: root.sevColor(modelData.severity)
                }
                Column {
                    id: aCol
                    anchors.left: sevDot.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.top: parent.top; anchors.topMargin: 11; spacing: 4
                    Row {
                        spacing: 8
                        Text { text: root.label(modelData.type); color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
                        Text { text: modelData.server_name; color: "#FFB833"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.relTime(modelData.created_at); color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: modelData.detail ? modelData.detail : ""
                        color: Qt.rgba(1, 1, 1, aCard.open ? 0.75 : 0.45); font.pixelSize: 12
                        width: parent.width; visible: text.length > 0
                        elide: aCard.open ? Text.ElideNone : Text.ElideRight
                        wrapMode: aCard.open ? Text.WrapAnywhere : Text.NoWrap
                        font.family: aCard.open ? "Menlo" : "sans-serif"
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openIdx = aCard.open ? -1 : index }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.alerts.length === 0; text: "No alerts."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
        }
    }
}
