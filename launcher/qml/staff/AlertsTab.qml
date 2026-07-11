import QtQuick
import Jarton

// The staffer's alert inbox — the same per-recipient feed that drives pushes
// (tickets, applications, reports, punishments, evaders, server alerts), so
// what buzzed the phone is answerable here. Server alerts fan into this feed
// for admin+panel staff, so one list carries everything.
Item {
    id: root

    property var notifs: []
    property bool loading: false
    property string error: ""
    property int reqInbox: -1

    onVisibleChanged: if (visible) { loadInbox() }

    function loadInbox() {
        loading = true; error = ""
        reqInbox = ProctorApi.send("GET", "/proctor/notifications?limit=100")
        // opening the tab is reading it — clear the unread state broker-side
        ProctorApi.send("POST", "/proctor/notifications/read-all", "{}")
    }
    function reload() { loadInbox() }

    // background refresh: silent + change-gated; rows arriving while the tab
    // is frontmost count as read (one read-all per change, not per tick)
    readonly property int autoRefreshMs: 20000
    property int quietReq: -1
    property string lastPayload: ""
    function quietLoad() {
        if (loading || quietReq !== -1) return
        quietReq = ProctorApi.send("GET", "/proctor/notifications?limit=100")
    }
    Timer { interval: root.autoRefreshMs; repeat: true; running: root.visible; onTriggered: root.quietLoad() }

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

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.quietReq) {
                root.quietReq = -1
                if (!ok || body === root.lastPayload) return
                root.lastPayload = body
                var y = list.contentY
                var hadUnread = false
                try {
                    var rows = JSON.parse(body).notifications || []
                    for (var i = 0; i < rows.length; i++) if (!rows[i].readAt) { hadUnread = true; break }
                    root.notifs = rows
                } catch (e) { return }
                Qt.callLater(function () { list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height)) })
                if (hadUnread && root.visible) ProctorApi.send("POST", "/proctor/notifications/read-all", "{}")
                return
            }
            if (id === root.reqInbox) {
                root.loading = false
                if (ok) {
                    root.lastPayload = body
                    try { root.notifs = JSON.parse(body).notifications || [] } catch (e) { root.notifs = [] }
                } else root.error = "Couldn't load alerts."
            }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Alerts"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: root.reload() }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }

        ListView {
            id: list
            width: parent.width; height: parent.height - 44; clip: true; spacing: 8
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
    }
}
