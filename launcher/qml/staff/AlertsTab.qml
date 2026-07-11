import QtQuick
import Jarton

// The staffer's alert inbox — the same per-recipient feed that drives pushes
// (tickets, applications, reports, punishments, evaders, server alerts), so
// what buzzed the phone is answerable here. Admins with the panel role get a
// second "Server" filter over the raw crash-alert history.
Item {
    id: root
    property string mode: "all"   // "all" (inbox) | "server" (crash-alert history)
    readonly property bool canServer: ProctorClient.admin && StaffAuth.canPanel

    property var notifs: []
    property var alerts: []
    property bool loading: false
    property string error: ""
    property int reqInbox: -1
    property int reqServer: -1
    property bool serverLoaded: false
    property int openIdx: -1

    onVisibleChanged: if (visible) { loadInbox() }
    onModeChanged: { openIdx = -1; if (mode === "server" && !serverLoaded) { serverLoaded = true; loadServer() } }

    function loadInbox() {
        loading = true; error = ""
        reqInbox = ProctorApi.send("GET", "/proctor/notifications?limit=100")
        // opening the tab is reading it — clear the unread state broker-side
        ProctorApi.send("POST", "/proctor/notifications/read-all", "{}")
    }
    function loadServer() { loading = true; error = ""; reqServer = ProctorApi.send("GET", "/proctor/crash-alerts?limit=150") }
    function reload() { root.mode === "server" ? loadServer() : loadInbox() }

    function relTime(s) {
        if (!s) return ""
        var iso = (("" + s).indexOf("T") === -1) ? ("" + s).replace(" ", "T") + "Z" : s
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }
    function typeIcon(type) {
        switch (type) {
        case "ticket": return "ticket"
        case "application": return "file-text"
        case "report": return "flag"
        case "punishment": return "shield"
        case "ban-evader": return "users"
        case "crash": return "terminal"
        default: return "bell"
        }
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
            if (id === root.reqInbox) {
                root.loading = false
                if (ok) { try { root.notifs = JSON.parse(body).notifications || [] } catch (e) { root.notifs = [] } }
                else root.error = "Couldn't load alerts."
                return
            }
            if (id === root.reqServer) {
                root.loading = false
                if (ok) { try { root.alerts = JSON.parse(body).alerts || [] } catch (e) { root.alerts = [] } }
                else root.error = status === 403 ? "Admin only." : "Couldn't load server alerts."
            }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Alerts"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    visible: root.canServer
                    FilterChip { label: "All"; active: root.mode === "all"; onPicked: root.mode = "all" }
                    FilterChip { label: "Server"; active: root.mode === "server"; onPicked: root.mode = "server" }
                }
            }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: root.reload() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }

        // ---- inbox ----
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 8
            visible: root.mode === "all"
            model: root.notifs
            delegate: Rectangle {
                id: nCard
                required property var modelData
                readonly property bool unread: !modelData.readAt
                width: ListView.view.width; height: nCol.height + 22; radius: 12
                color: "#16110a"; border.color: unread ? "#3a2f14" : "#241c12"; border.width: 1
                Image {
                    id: nIcon
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.top: parent.top; anchors.topMargin: 14
                    source: "qrc:/jarton/staff/icons/ui/" + root.typeIcon(modelData.type) + (nCard.unread ? "-active.svg" : "-rest.svg")
                    width: 16; height: 16; sourceSize: Qt.size(32, 32)
                }
                Column {
                    id: nCol
                    anchors.left: nIcon.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 30
                    anchors.top: parent.top; anchors.topMargin: 11; spacing: 4
                    Row {
                        spacing: 8
                        Text { text: modelData.title; color: nCard.unread ? "#FFFFFF" : "#F2E8D0"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                        Text { text: root.relTime(modelData.createdAt); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: modelData.body ? modelData.body : ""
                        color: "#9a8a66"; font.pixelSize: 12
                        width: parent.width; visible: text.length > 0
                        wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                    }
                }
                Rectangle {
                    visible: nCard.unread
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.top: parent.top; anchors.topMargin: 16
                    width: 8; height: 8; radius: 4; color: "#FFB81C"
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.notifs.length === 0; text: "Nothing yet — ticket, report and server alerts land here."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
        }

        // ---- raw server-alert history (admin + panel role) ----
        ListView {
            width: parent.width; height: parent.height - 44; clip: true; spacing: 8
            visible: root.mode === "server"
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
            Text { anchors.centerIn: parent; visible: !root.loading && root.alerts.length === 0; text: "No server alerts."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
        }
    }

    component FilterChip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        signal picked()
        width: chipTxt.width + 20; height: 24; radius: 12
        color: active ? Qt.rgba(1, 0.72, 0.2, 0.16) : chipMa.containsMouse ? "#1a140e" : "transparent"
        border.color: active ? "#FFB81C" : "#2a2114"; border.width: 1
        Text { id: chipTxt; anchors.centerIn: parent; text: chip.label; color: chip.active ? "#FFE082" : "#9a8a66"; font.pixelSize: 11; font.bold: chip.active }
        MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.picked() }
    }
}
