import QtQuick
import Jarton

// Admin / ownership analytics — read-only oversight feeds (active staff, sessions, the
// command firehose, join/leave presence, the audit trail, abuse alerts). Crashes live in
// the Inbox, not here. All routes are proctorAdminGuard. Rendered two ways: standalone with
// its own sub-tab bar, or embedded (forceView set) as a single drill-in feed under Staff.
Item {
    id: root
    property string view: "active"
    property string forceView: ""            // when set: show only this feed, no bar
    property bool embedded: forceView.length > 0
    // displayName / username → { name, uuid } fallback so faces resolve even before the
    // broker mc_name join lands; supplied by the host (the staff roster it already has)
    property var staffMap: ({})

    readonly property string current: embedded ? forceView : view

    // ---- time: everything routes through the shared TimeFmt singleton (UTC-correct parse,
    //      rendered in the viewer's own local zone). tzDep is a harmless constant kept so the
    //      comma-dependency bindings below read cleanly; the 25s refresh re-renders "Xm ago". ----
    readonly property string tzDep: ""
    function relTime(v) { return TimeFmt.rel(v) }
    function whenLine(v) { return TimeFmt.when(v) }
    function sevColor(s) { return s === "high" ? "#e06c6c" : "#FFB833" }

    // ---- face resolution: mc name/uuid off the row, else the roster fallback map ----
    function headKey(row) {
        if (!row) return ""
        if (row.mc_uuid) return row.mc_uuid
        if (row.mcUuid) return row.mcUuid
        if (row.mc_name) return row.mc_name
        if (row.mcName) return row.mcName
        var k = row.display_name || row.displayName || row.username || row.actor || row.staff_name || ""
        var m = root.staffMap[k]
        return m ? (m.uuid || m.name || "") : ""
    }

    // ---- audit humanizer: plain-English sentences, never raw JSON or a bare UUID ----
    function detailObj(row) {
        var s = String(row.detail || "")
        if (s.charAt(0) === "{") { try { return JSON.parse(s) } catch (e) {} }
        return null
    }
    function onServer(sv) { return sv ? " on " + tidyServer(sv) : "" }
    function tidyServer(sv) { sv = String(sv || ""); return sv.charAt(0).toUpperCase() + sv.slice(1) }
    function punishVerb(a) {
        switch (String(a || "").toLowerCase()) {
        case "ban": return "banned"; case "tempban": return "temp-banned"
        case "mute": return "muted"; case "tempmute": return "temp-muted"
        case "kick": return "kicked"; case "warn": return "warned"
        case "freeze": return "froze"; case "shadowban": return "shadow-banned"
        case "shadowmute": return "shadow-muted"
        case "unban": return "unbanned"; case "unmute": return "unmuted"
        case "unfreeze": return "unfroze"; case "unshadowban": return "un-shadow-banned"
        case "unshadowmute": return "un-shadow-muted"
        default: return a ? String(a) + "ed" : "actioned"
        }
    }
    function tidyAction(a) {
        var p = String(a || "").split(".")
        var v = p[p.length - 1].replace(/-/g, " ")
        return v.charAt(0).toUpperCase() + v.slice(1)
    }
    function auditLine(row) {
        var actor = row.actor || "Someone"
        var action = String(row.action || "")
        var d = detailObj(row)
        var det = String(row.detail || "")

        if (action === "guard.punish" || action === "guard.unpunish") {
            var sub = d ? (d.action || d.type || "") : ""
            var tgt = d ? (d.targetName || "") : ""
            var reason = d && d.reason ? " — " + d.reason : ""
            return actor + " " + punishVerb(sub) + (tgt ? " " + tgt : "") + onServer(d && d.server) + reason
        }
        if (action === "guard.note-add" || action === "guard.note-remove") {
            var who = d ? (d.targetName || "") : ""
            return actor + (action.indexOf("remove") >= 0 ? " removed a note" : " added a note") + (who ? " on " + who : "")
        }
        if (action.indexOf("guard.") === 0) {
            var t2 = d ? (d.targetName || "") : ""
            return actor + " " + punishVerb(action.slice(6)) + (t2 ? " " + t2 : "") + onServer(d && d.server)
        }
        if (action === "staff.create")  return actor + " created staff account " + (det.split(" ")[0] || "")
        if (action === "staff.update")  return actor + " updated " + (det.split(":")[0] || "a staff account")
        if (action === "staff.delete")  return actor + " removed staff account " + det
        if (action === "staff.reset-password") return actor + " reset " + det + "'s password"
        if (action === "application.resolve") return actor + " resolved " + det
        if (action === "report.resolve") return actor + " resolved " + det
        if (action === "auth.pin-set") return actor + " set their PIN"
        if (action === "auth.pin-reset") return actor + " reset " + det.replace("target=", "") + "'s PIN"
        if (action === "auth.login") return actor + " signed in"
        if (action === "auth.change-password") return actor + " changed their password"
        if (action === "settings.notify") return actor + " updated notification settings"
        if (action === "history.delete") return actor + " deleted a punishment record"
        if (action === "history.clear") return actor + " cleared a player's history"
        // fallback: tidy verb, human fields only — never the raw JSON/UUID
        var extra = d ? (d.targetName || "") : (det.charAt(0) === "{" ? "" : det)
        return actor + " " + tidyAction(action).toLowerCase() + (extra ? " " + extra : "")
    }

    // ---- sub-tab bar (hidden when embedded) ----
    STabBar {
        id: bar
        visible: !root.embedded
        height: root.embedded ? 0 : implicitHeight
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        current: root.view
        onSelected: (id) => root.view = id
        model: [
            { id: "active",   label: "Active",   icon: "users" },
            { id: "sessions", label: "Sessions", icon: "clock" },
            { id: "commands", label: "Commands", icon: "terminal" },
            { id: "presence", label: "Presence", icon: "network" },
            { id: "audit",    label: "Audit",    icon: "file-text" },
            { id: "abuse",    label: "Abuse",    icon: "flag" }
        ]
    }

    Item {
        anchors.top: root.embedded ? parent.top : bar.bottom; anchors.topMargin: root.embedded ? 0 : 12
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom

        // ---- a generic admin feed: header + refresh + card list, quiet auto-refresh,
        //      optional before-cursor paging. delegate is supplied per-view. ----
        component Feed: Item {
            id: feed
            property string path
            property string key
            property string title
            property string emptyText: "Nothing here yet."
            property int limit: 100
            property bool paged: false
            property bool zoneNote: false               // dim "times shown in your local time" line
            property bool showHeader: !root.embedded   // the drill-in host draws its own header
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
                    width: parent.width; height: feed.showHeader ? 30 : 0; visible: feed.showHeader
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: feed.title; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
                    SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: feed.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: feed.load() }
                }
                Text {
                    width: parent.width; visible: feed.zoneNote && feed.items.length > 0
                    height: visible ? 14 : 0
                    text: "Times shown in your local time (" + TimeFmt.zoneLabel + ")"
                    color: "#6b5d3f"; font.pixelSize: 11
                }
                ListView {
                    id: list
                    width: parent.width; height: parent.height - (feed.showHeader ? 42 : 0) - (feed.zoneNote && feed.items.length > 0 ? 26 : 0)
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
            anchors.fill: parent; visible: root.current === "active"
            path: "/proctor/active"; key: "active"; title: "Active Staff"; emptyText: "No staff are clocked in."; zoneNote: true
            row: Card {
                height: 60
                Avatar {
                    id: av; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 36; uuid: root.headKey(modelData); url: modelData.avatarUrl || ""
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
                    Text { text: (root.tzDep, "since " + root.whenLine(modelData.activeSince)); color: "#6b5d3f"; font.pixelSize: 11 }
                }
                Text { id: rankT; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.rank || ""; color: "#FFB81C"; font.pixelSize: 11; font.bold: true }
            }
        }

        // ---- Session history ----
        Feed {
            anchors.fill: parent; visible: root.current === "sessions"
            path: "/proctor/sessions"; key: "sessions"; title: "Session History"; emptyText: "No sessions yet."; paged: true; zoneNote: true
            row: Card {
                height: 62
                Avatar { id: sAv; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 34; uuid: root.headKey(modelData) }
                Column {
                    anchors.left: sAv.right; anchors.leftMargin: 12; anchors.right: stT.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: modelData.display_name || modelData.username || ""; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                    Text { text: (modelData.player_name || "") + " · " + (modelData.server_name || "") + (modelData.opped === 1 ? " · op" : ""); color: "#9a8a66"; font.pixelSize: 12 }
                    Text { text: (root.tzDep, root.whenLine(modelData.active_since)) + (modelData.closed_reason ? "  (" + modelData.closed_reason + ")" : ""); color: "#6b5d3f"; font.pixelSize: 11 }
                }
                Text { id: stT; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.closed_at ? "closed" : "active"
                    color: modelData.closed_at ? "#7a6f63" : "#5ad17a"; font.pixelSize: 11; font.bold: true }
            }
        }

        // ---- Command logs ----
        Feed {
            anchors.fill: parent; visible: root.current === "commands"
            path: "/proctor/commands"; key: "commands"; title: "Command Logs"; emptyText: "No commands logged."; paged: true
            row: Card {
                height: 52
                Avatar { id: cAv; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 30; uuid: root.headKey(modelData) }
                Text { id: cTime; anchors.right: parent.right; anchors.rightMargin: 14; anchors.top: parent.top; anchors.topMargin: 9
                    text: (root.tzDep, root.relTime(modelData.executed_at)); color: "#6b5d3f"; font.pixelSize: 11 }
                Column {
                    anchors.left: cAv.right; anchors.leftMargin: 12; anchors.right: cTime.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: modelData.display_name || modelData.username || ""; color: "#FFB81C"; font.pixelSize: 12; font.bold: true }
                    Text { width: parent.width; text: modelData.command || ""; color: "#d9ccae"; font.pixelSize: 12; font.family: "Menlo"; elide: Text.ElideRight }
                }
            }
        }

        // ---- Join / leave presence ----
        Feed {
            anchors.fill: parent; visible: root.current === "presence"
            path: "/proctor/presence"; key: "presence"; title: "Join / Leave"; emptyText: "No presence events yet."; paged: true; zoneNote: true
            row: Card {
                height: 48
                Avatar { id: pAv; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 28; uuid: root.headKey(modelData) }
                Rectangle {
                    id: evc; anchors.left: pAv.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: (modelData.event_type === "join") ? "#5ad17a" : "#e06c6c"
                }
                Text { anchors.left: evc.right; anchors.leftMargin: 9; anchors.right: pTime.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: (modelData.display_name || modelData.username || "") + "  " + (modelData.event_type === "join" ? "joined" : "left") + "  " + (modelData.server_name || "")
                    color: "#F2E8D0"; font.pixelSize: 13 }
                Text { id: pTime; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: (root.tzDep, root.whenLine(modelData.created_at)); color: "#6b5d3f"; font.pixelSize: 11 }
            }
        }

        // ---- Audit log (humanized) ----
        Feed {
            anchors.fill: parent; visible: root.current === "audit"
            path: "/proctor/audit"; key: "audit"; title: "Audit Log"; emptyText: "Nothing logged yet."; limit: 150
            row: Card {
                height: 50
                Avatar { id: aAv; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 30; uuid: root.headKey(modelData) }
                Text { id: aTime; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: (root.tzDep, root.relTime(modelData.created_at)); color: "#6b5d3f"; font.pixelSize: 11 }
                Text {
                    anchors.left: aAv.right; anchors.leftMargin: 12; anchors.right: aTime.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.auditLine(modelData); color: "#e6dcc2"; font.pixelSize: 13; elide: Text.ElideRight
                }
            }
        }

        // ---- Abuse alerts (dedicated) ----
        Feed {
            anchors.fill: parent; visible: root.current === "abuse"
            path: "/proctor/alerts"; key: "alerts"; title: "Abuse Alerts"; emptyText: "No flagged staff actions. Clean."; limit: 150
            row: Card {
                height: 58
                Rectangle { anchors.left: parent.left; width: 3; height: parent.height - 2; anchors.verticalCenter: parent.verticalCenter
                    color: root.sevColor(modelData.severity); radius: 2; anchors.leftMargin: 1 }
                Avatar { id: abAv; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    size: 32; uuid: root.headKey(modelData) }
                Text { id: abTime; anchors.right: parent.right; anchors.rightMargin: 14; anchors.top: parent.top; anchors.topMargin: 10
                    text: (root.tzDep, root.relTime(modelData.created_at)); color: "#6b5d3f"; font.pixelSize: 11 }
                Column {
                    anchors.left: abAv.right; anchors.leftMargin: 12; anchors.right: abTime.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row { spacing: 8
                        Text { text: (modelData.flag || "flag") + (modelData.severity === "high" ? "  HIGH" : ""); color: root.sevColor(modelData.severity); font.pixelSize: 12; font.bold: true }
                        Text { text: modelData.staff_name || ""; color: "#F2E8D0"; font.pixelSize: 12 }
                    }
                    Text { width: parent.width; text: (modelData.command || "") + (modelData.detail ? "  — " + modelData.detail : ""); color: "#d9ccae"; font.pixelSize: 11; font.family: "Menlo"; elide: Text.ElideRight }
                }
            }
        }
    }
}
