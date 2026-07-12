import QtQuick
import Jarton

// Unified inbox — one feed across every source that can notify a staffer:
// Swifty board activity, proctor staff alerts (tickets/apps/reports/punishments),
// and Pterodactyl/server alerts. Mirrors the Companion app: proctor rows split
// into Staff vs Pterodactyl by type (crash -> servers), Swifty rows ride the
// SwiftyClient token and only appear when that session is connected. Source chips
// show whenever more than one source is present. Marking read on view clears the
// unread badge broker-side per source.
Item {
    id: root

    property string filter: ""            // "" = all, else "swifty" | "staff" | "servers"
    property var proctorRows: []          // normalized {key,source,title,body,ts,unread,icon,pid}
    property var swiftyRows: []           // normalized {..., sid}
    property var notifs: []               // merged + sorted + filtered (the ListView model)
    property bool loading: false
    property string error: ""
    property int reqProctor: -1
    property int reqSwifty: -1
    property var markedSwifty: ({})       // swifty ids we've already POSTed read for

    readonly property bool swiftyOn: (typeof SwiftyClient !== "undefined") && SwiftyClient.connected

    onVisibleChanged: if (visible) loadInbox()

    function loadInbox() {
        loading = true; error = ""
        reqProctor = ProctorApi.send("GET", "/proctor/notifications?limit=100")
        ProctorApi.send("POST", "/proctor/notifications/read-all", "{}")
        if (swiftyOn) reqSwifty = SwiftyApi.send("GET", "/notifications?limit=100")
        else { swiftyRows = []; recompute() }
    }
    function reload() { loadInbox() }

    // ---- normalization: both sources -> one row shape ----
    function tsOf(s) {
        if (!s) return 0
        var iso = (("" + s).indexOf("T") === -1) ? ("" + s).replace(" ", "T") + "Z" : s
        var t = Date.parse(iso); return isNaN(t) ? 0 : t
    }
    function normProctor(rows) {
        var out = []
        for (var i = 0; i < rows.length; i++) {
            var n = rows[i]
            out.push({ key: "p" + n.id, pid: n.id, source: (n.type === "crash" ? "servers" : "staff"),
                       title: n.title || "Alert", body: n.body || "", ts: tsOf(n.createdAt),
                       unread: !n.readAt, icon: typeIcon(n.type) })
        }
        return out
    }
    function normSwifty(rows) {
        var out = []
        for (var i = 0; i < rows.length; i++) {
            var n = rows[i]
            out.push({ key: "s" + n.id, sid: n.id, source: "swifty",
                       title: n.title || "Notification", body: n.body || "", ts: tsOf(n.createdAt),
                       unread: !n.readAt, icon: "bell" })
        }
        return out
    }

    function recompute() {
        var all = root.proctorRows.concat(root.swiftyRows)
        all.sort(function (a, b) { return b.ts - a.ts })
        if (root.filter.length > 0) all = all.filter(function (r) { return r.source === root.filter })
        root.notifs = all
    }

    // sources present right now (own rows) or reachable (connected) — drives the chip bar
    function hasSource(src) {
        if (src === "swifty") { if (root.swiftyOn) return true }
        else if (ProctorClient.connected) return true
        for (var i = 0; i < root.proctorRows.length; i++) if (root.proctorRows[i].source === src) return true
        for (var j = 0; j < root.swiftyRows.length; j++) if (root.swiftyRows[j].source === src) return true
        return false
    }
    readonly property var sourceDefs: [
        { id: "swifty",  label: "Swifty",      icon: "external-link" },
        { id: "staff",   label: "Staff",       icon: "shield" },
        { id: "servers", label: "Pterodactyl", icon: "terminal" }
    ]
    function shownSources() {
        var out = []
        for (var i = 0; i < sourceDefs.length; i++) if (hasSource(sourceDefs[i].id)) out.push(sourceDefs[i])
        return out
    }

    function relTime(ts) {
        if (!ts) return ""
        var d = Date.now() - ts
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
    function sourceLabel(src) {
        return src === "swifty" ? "SWIFTY" : src === "servers" ? "PTERODACTYL" : "STAFF"
    }

    // mark any currently-unread swifty rows read (once each), proctor is bulk read-all
    function markSwiftyRead() {
        if (!swiftyOn) return
        for (var i = 0; i < root.swiftyRows.length; i++) {
            var r = root.swiftyRows[i]
            if (r.unread && root.markedSwifty[r.sid] === undefined) {
                root.markedSwifty[r.sid] = true
                SwiftyApi.send("POST", "/notifications/" + r.sid + "/read", "{}")
            }
        }
    }

    // ---- background refresh: silent, change-gated, scroll-preserving ----
    readonly property int autoRefreshMs: 20000
    property int quietProctor: -1
    property int quietSwifty: -1
    property string lastProctorBody: ""
    property string lastSwiftyBody: ""
    function quietLoad() {
        if (loading) return
        if (quietProctor === -1) quietProctor = ProctorApi.send("GET", "/proctor/notifications?limit=100")
        if (swiftyOn && quietSwifty === -1) quietSwifty = SwiftyApi.send("GET", "/notifications?limit=100")
    }
    Timer { interval: root.autoRefreshMs; repeat: true; running: root.visible; onTriggered: root.quietLoad() }

    function applyProctor(body, quiet) {
        try { root.proctorRows = normProctor(JSON.parse(body).notifications || []) } catch (e) { return false }
        return true
    }
    function applySwifty(body, quiet) {
        // swifty /notifications returns a bare array
        try { var arr = JSON.parse(body); root.swiftyRows = normSwifty(Array.isArray(arr) ? arr : (arr.notifications || [])) } catch (e) { return false }
        return true
    }
    function anyUnread() {
        for (var i = 0; i < root.proctorRows.length; i++) if (root.proctorRows[i].unread) return true
        for (var j = 0; j < root.swiftyRows.length; j++) if (root.swiftyRows[j].unread) return true
        return false
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.quietProctor) {
                root.quietProctor = -1
                if (!ok || body === root.lastProctorBody) return
                root.lastProctorBody = body
                var y = list.contentY
                if (!applyProctor(body, true)) return
                recompute()
                Qt.callLater(function () { list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height)) })
                if (root.visible && anyUnread()) { ProctorApi.send("POST", "/proctor/notifications/read-all", "{}"); markSwiftyRead() }
                return
            }
            if (id === root.reqProctor) {
                root.loading = false
                if (ok) { root.lastProctorBody = body; applyProctor(body, false); recompute(); markSwiftyRead() }
                else root.error = "Couldn't load alerts."
            }
        }
    }
    Connections {
        target: (typeof SwiftyApi !== "undefined") ? SwiftyApi : null
        ignoreUnknownSignals: true
        function onResponse(id, ok, status, body) {
            if (id === root.quietSwifty) {
                root.quietSwifty = -1
                if (!ok || body === root.lastSwiftyBody) return
                root.lastSwiftyBody = body
                var y = list.contentY
                if (!applySwifty(body, true)) return
                recompute()
                Qt.callLater(function () { list.contentY = Math.max(0, Math.min(y, list.contentHeight - list.height)) })
                if (root.visible) markSwiftyRead()
                return
            }
            if (id === root.reqSwifty) {
                if (ok) { root.lastSwiftyBody = body; applySwifty(body, false); recompute(); markSwiftyRead() }
            }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Inbox"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: root.reload() }
        }

        // source filter chips — only when more than one source is in play
        Flow {
            id: chipRow
            width: parent.width; spacing: 8
            readonly property var srcs: root.shownSources()
            visible: srcs.length > 1

            component Chip: Rectangle {
                property string cid: ""
                property string label: ""
                property string icon: ""
                readonly property bool active: root.filter === cid
                height: 28; radius: 14
                width: cRow.width + 22
                color: active ? "#2a2114" : "transparent"
                border.color: active ? "#FFB81C" : "#2a2114"; border.width: 1
                Row {
                    id: cRow; anchors.centerIn: parent; spacing: 6
                    Image {
                        visible: icon.length > 0
                        source: icon.length > 0 ? ("qrc:/jarton/staff/icons/ui/" + icon + (active ? "-active.svg" : "-rest.svg")) : ""
                        width: 13; height: 13; sourceSize: Qt.size(26, 26); anchors.verticalCenter: parent.verticalCenter
                    }
                    Text { text: label; color: active ? "#FFE082" : "#9a8a66"; font.pixelSize: 12; font.bold: active; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.filter = parent.cid; root.recompute() } }
            }

            Chip { cid: ""; label: "All" }
            Repeater {
                model: chipRow.srcs
                Chip { cid: modelData.id; label: modelData.label; icon: modelData.icon }
            }
        }

        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 44 - (chipRow.visible ? 40 : 0)
            clip: true; spacing: 8
            model: root.notifs
            delegate: Rectangle {
                id: nCard
                required property var modelData
                readonly property bool unread: modelData.unread
                width: ListView.view.width; height: nCol.height + 22; radius: 12
                color: "#16110a"; border.color: unread ? "#3a2f14" : "#241c12"; border.width: 1
                Image {
                    id: nIcon
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.top: parent.top; anchors.topMargin: 14
                    source: "qrc:/jarton/staff/icons/ui/" + modelData.icon + (nCard.unread ? "-active.svg" : "-rest.svg")
                    width: 16; height: 16; sourceSize: Qt.size(32, 32)
                }
                Column {
                    id: nCol
                    anchors.left: nIcon.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 30
                    anchors.top: parent.top; anchors.topMargin: 11; spacing: 4
                    Row {
                        spacing: 8
                        Text { text: root.sourceLabel(modelData.source); color: "#8a7a56"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.6; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.title; color: nCard.unread ? "#FFFFFF" : "#F2E8D0"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                        Text { text: root.relTime(modelData.ts); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
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
            Text { anchors.centerIn: parent; visible: !root.loading && root.notifs.length === 0; text: "Nothing yet — Swifty, ticket, report and server alerts land here."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
        }
    }
}
