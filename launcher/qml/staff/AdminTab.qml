import QtQuick
import Jarton

// Admin / ownership analytics — the read-only oversight views (active staff, session
// history, command firehose, join/leave presence, audit trail) plus dedicated abuse and
// crash feeds. All routes are proctorAdminGuard; the tab only shows for ProctorClient.admin.
Item {
    id: root
    property string view: "active"

    // ---- shared time helpers (server sends MySQL datetime strings) ----
    function toMs(v) {
        if (v === null || v === undefined) return 0
        var s = String(v)
        var t = Date.parse(s.indexOf("T") >= 0 ? s : s.replace(" ", "T"))
        return isNaN(t) ? 0 : t
    }
    function relTime(v) {
        var ms = toMs(v); if (!ms) return ""
        var diff = Date.now() - ms
        var d = Math.floor(diff / 86400000); if (d > 0) return d + "d ago"
        var h = Math.floor(diff / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(diff / 60000)) + "m ago"
    }
    function fmtWhen(v) {
        var ms = toMs(v); if (!ms) return ""
        var d = new Date(ms)
        return d.toLocaleDateString(Qt.locale(), "dd MMM") + ", " + d.toLocaleTimeString(Qt.locale(), "HH:mm")
    }
    function whenLine(v) {
        var r = relTime(v), w = fmtWhen(v)
        return r && w ? r + " · " + w : (r || w)
    }
    function sevColor(s) { return s === "high" ? "#e06c6c" : "#FFB833" }

    STabBar {
        id: bar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        current: root.view
        onSelected: (id) => root.view = id
        model: [
            { id: "active",   label: "Active",   icon: "users" },
            { id: "sessions", label: "Sessions", icon: "clock" },
            { id: "commands", label: "Commands", icon: "terminal" },
            { id: "presence", label: "Presence", icon: "network" },
            { id: "audit",    label: "Audit",    icon: "file-text" },
            { id: "abuse",    label: "Abuse",    icon: "flag" },
            { id: "crash",    label: "Crashes",  icon: "zap" }
        ]
    }

    Item {
        anchors.top: bar.bottom; anchors.topMargin: 12
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom

        // ---- a generic admin feed: header + refresh + card list, quiet auto-refresh,
        //      optional before-cursor paging. delegate is supplied per-view. ----
        component Feed: Item {
            id: feed
            property string path            // base route, no query
            property string key             // response array key
            property string title
            property string emptyText: "Nothing here yet."
            property int limit: 100
            property bool paged: false       // before-cursor paging (id descending)
            property Component row
            property var items: []
            property bool loading: false
            property bool ended: false
            property int reqId: -1
            property int reqMore: -1
            property int reqQuiet: -1
            property string lastRaw: ""

            function url(before) {
                var q = "?limit=" + limit
                if (paged && before) q += "&before=" + before
                return path + q
            }
            function load() { loading = true; ended = false; reqId = ProctorApi.send("GET", url(0)) }
            function quiet() { if (loading) return; reqQuiet = ProctorApi.send("GET", url(0)) }
            function more() {
                if (!paged || ended || loading || items.length === 0) return
                var last = items[items.length - 1]
                if (last && last.id !== undefined) reqMore = ProctorApi.send("GET", url(last.id))
            }

            Component.onCompleted: load()
            Timer { interval: 25000; repeat: true; running: feed.visible; onTriggered: feed.quiet() }

            Connections {
                target: ProctorApi
                function onResponse(id, ok, status, body) {
                    if (id === feed.reqId) {
                        feed.loading = false
                        if (ok) { try { feed.items = JSON.parse(body)[feed.key] || []; feed.lastRaw = body } catch (e) { feed.items = [] }
                                  feed.ended = feed.items.length < feed.limit }
                        return
                    }
                    if (id === feed.reqQuiet) {
                        if (ok && body !== feed.lastRaw) {
                            var y = list.contentY
                            try { feed.items = JSON.parse(body)[feed.key] || []; feed.lastRaw = body } catch (e) {}
                            list.contentY = y
                        }
                        return
                    }
                    if (id === feed.reqMore) {
                        if (ok) { try {
                            var page = JSON.parse(body)[feed.key] || []
                            if (page.length === 0) { feed.ended = true }
                            else { feed.items = feed.items.concat(page); feed.ended = page.length < feed.limit }
                        } catch (e) {} }
                        return
                    }
                }
            }

            Column {
                anchors.fill: parent; spacing: 12
                Item {
                    width: parent.width; height: 30
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: feed.title; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
                    SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: feed.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: feed.load() }
                }
                ListView {
                    id: list
                    width: parent.width; height: parent.height - 42
                    clip: true; spacing: 6
                    model: feed.items
                    delegate: feed.row
                    onContentYChanged: if (feed.paged && contentY > 0 && contentY >= contentHeight - height - 400) feed.more()
                    footer: Item { width: 1; height: feed.loading && feed.items.length ? 30 : 1
                        Text { anchors.centerIn: parent; visible: feed.loading && feed.items.length > 0; text: "Loading…"; color: "#6b5d3f"; font.pixelSize: 12 } }
                    Text { anchors.centerIn: parent; visible: feed.loading && feed.items.length === 0; text: "Loading…"; color: "#6b5d3f"; font.pixelSize: 14 }
                    Text { anchors.centerIn: parent; visible: !feed.loading && feed.items.length === 0; text: feed.emptyText; color: "#6b5d3f"; font.pixelSize: 14 }
                }
            }
        }

        // ---- reusable card shell ----
        component Card: Rectangle {
            width: ListView.view ? ListView.view.width : parent.width
            radius: 11; color: "#16110a"; border.color: "#241c12"; border.width: 1
        }

        // ---- Active staff ----
        Feed {
            anchors.fill: parent; visible: root.view === "active"
            path: "/proctor/active"; key: "active"; title: "Active Staff"; emptyText: "No staff are clocked in."
            row: Card {
                height: 60
                Avatar {
                    id: av; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 36; uuid: modelData.mcUuid || ""; url: modelData.avatarUrl || ""
                }
                Column {
                    anchors.left: av.right; anchors.leftMargin: 12; anchors.right: rankT.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row { spacing: 8
                        Text { text: modelData.displayName || modelData.mcName || ""; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Rectangle { visible: modelData.opped === true; anchors.verticalCenter: parent.verticalCenter
                            width: opT.width + 12; height: 16; radius: 8; color: "#23311f"
                            Text { id: opT; anchors.centerIn: parent; text: "OP"; color: "#5ad17a"; font.pixelSize: 9; font.bold: true } }
                    }
                    Text { text: (modelData.playerName || "") + " · " + (modelData.server || ""); color: "#9a8a66"; font.pixelSize: 12 }
                    Text { text: "since " + root.whenLine(modelData.activeSince); color: "#6b5d3f"; font.pixelSize: 11 }
                }
                Text { id: rankT; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.rank || ""; color: "#FFB81C"; font.pixelSize: 11; font.bold: true }
            }
        }

        // ---- Session history ----
        Feed {
            anchors.fill: parent; visible: root.view === "sessions"
            path: "/proctor/sessions"; key: "sessions"; title: "Session History"; emptyText: "No sessions yet."; paged: true
            row: Card {
                height: 62
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: stT.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: modelData.display_name || modelData.username || ""; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                    Text { text: (modelData.player_name || "") + " · " + (modelData.server_name || "") + (modelData.opped === 1 ? " · op" : ""); color: "#9a8a66"; font.pixelSize: 12 }
                    Text { text: root.whenLine(modelData.active_since) + (modelData.closed_reason ? "  (" + modelData.closed_reason + ")" : ""); color: "#6b5d3f"; font.pixelSize: 11 }
                }
                Text { id: stT; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.closed_at ? "closed" : "active"
                    color: modelData.closed_at ? "#7a6f63" : "#5ad17a"; font.pixelSize: 11; font.bold: true }
            }
        }

        // ---- Command logs ----
        Feed {
            anchors.fill: parent; visible: root.view === "commands"
            path: "/proctor/commands"; key: "commands"; title: "Command Logs"; emptyText: "No commands logged."; paged: true
            row: Card {
                height: 52
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row { width: parent.width
                        Text { text: modelData.display_name || modelData.username || ""; color: "#FFB81C"; font.pixelSize: 12; font.bold: true }
                        Item { width: parent.width - implicitWidth; height: 1; Text { anchors.right: parent.right; text: root.relTime(modelData.executed_at); color: "#6b5d3f"; font.pixelSize: 11 } }
                    }
                    Text { width: parent.width; text: modelData.command || ""; color: "#d9ccae"; font.pixelSize: 12; font.family: "Menlo"; elide: Text.ElideRight }
                }
            }
        }

        // ---- Join / leave presence ----
        Feed {
            anchors.fill: parent; visible: root.view === "presence"
            path: "/proctor/presence"; key: "presence"; title: "Join / Leave"; emptyText: "No presence events yet."; paged: true
            row: Card {
                height: 48
                Rectangle {
                    id: evc; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: (modelData.event_type === "join") ? "#5ad17a" : "#e06c6c"
                }
                Text { anchors.left: evc.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.display_name || modelData.username || "") + "  " + (modelData.event_type === "join" ? "joined" : "left") + "  " + (modelData.server_name || "")
                    color: "#F2E8D0"; font.pixelSize: 13 }
                Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: root.whenLine(modelData.created_at); color: "#6b5d3f"; font.pixelSize: 11 }
            }
        }

        // ---- Audit log ----
        Feed {
            anchors.fill: parent; visible: root.view === "audit"
            path: "/proctor/audit"; key: "audit"; title: "Audit Log"; emptyText: "Nothing logged yet."; limit: 150
            row: Card {
                height: (modelData.detail && String(modelData.detail).length) ? 56 : 42
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row { width: parent.width; spacing: 8
                        Text { text: modelData.actor || ""; color: "#FFB81C"; font.pixelSize: 12; font.bold: true }
                        Text { text: modelData.action || ""; color: "#d9ccae"; font.pixelSize: 12; font.family: "Menlo" }
                        Item { width: parent.width - x; height: 1; Text { anchors.right: parent.right; text: root.relTime(modelData.created_at); color: "#6b5d3f"; font.pixelSize: 11 } }
                    }
                    Text { visible: modelData.detail && String(modelData.detail).length > 0; width: parent.width
                        text: modelData.detail || ""; color: "#8a7a56"; font.pixelSize: 11; elide: Text.ElideRight }
                }
            }
        }

        // ---- Abuse alerts (dedicated) ----
        Feed {
            anchors.fill: parent; visible: root.view === "abuse"
            path: "/proctor/alerts"; key: "alerts"; title: "Abuse Alerts"; emptyText: "No flagged staff actions. Clean."; limit: 150
            row: Card {
                height: 58
                Rectangle { anchors.left: parent.left; width: 3; height: parent.height - 2; anchors.verticalCenter: parent.verticalCenter
                    color: root.sevColor(modelData.severity); radius: 2; anchors.leftMargin: 1 }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row { width: parent.width; spacing: 8
                        Text { text: (modelData.flag || "flag") + (modelData.severity === "high" ? "  HIGH" : ""); color: root.sevColor(modelData.severity); font.pixelSize: 12; font.bold: true }
                        Text { text: modelData.staff_name || ""; color: "#F2E8D0"; font.pixelSize: 12 }
                        Item { width: parent.width - x; height: 1; Text { anchors.right: parent.right; text: root.relTime(modelData.created_at); color: "#6b5d3f"; font.pixelSize: 11 } }
                    }
                    Text { width: parent.width; text: (modelData.command || "") + (modelData.detail ? "  — " + modelData.detail : ""); color: "#d9ccae"; font.pixelSize: 11; font.family: "Menlo"; elide: Text.ElideRight }
                }
            }
        }

        // ---- Crash alerts (dedicated) ----
        Feed {
            anchors.fill: parent; visible: root.view === "crash"
            path: "/proctor/crash-alerts"; key: "alerts"; title: "Crash Alerts"; emptyText: "No crashes or errors logged. All quiet."; limit: 150
            row: Card {
                height: 58
                Rectangle { anchors.left: parent.left; width: 3; height: parent.height - 2; anchors.verticalCenter: parent.verticalCenter
                    color: root.sevColor(modelData.severity); radius: 2; anchors.leftMargin: 1 }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row { width: parent.width; spacing: 8
                        Text { text: modelData.type || "event"; color: root.sevColor(modelData.severity); font.pixelSize: 12; font.bold: true }
                        Text { text: modelData.server_name || ""; color: "#FFB81C"; font.pixelSize: 12 }
                        Item { width: parent.width - x; height: 1; Text { anchors.right: parent.right; text: root.relTime(modelData.created_at); color: "#6b5d3f"; font.pixelSize: 11 } }
                    }
                    Text { width: parent.width; text: modelData.detail || ""; color: "#d9ccae"; font.pixelSize: 11; elide: Text.ElideRight }
                }
            }
        }
    }
}
