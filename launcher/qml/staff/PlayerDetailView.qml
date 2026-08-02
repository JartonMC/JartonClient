import QtQuick
import Jarton

// One player's management screen, matching the Companion app: status + punish
// actions + offence ladder up top, then inventory snapshots (restore/adjust via
// the InvPlus routes on the cap session), linked Discord / playtime / join info,
// and finally history + notes. Instantiated per player via a Loader so state
// never leaks between lookups.
Item {
    id: root
    property string uuid: ""
    property string name: ""
    signal closed()

    // the broker refuses self-punishment too — this just keeps the buttons honest
    readonly property bool isSelf: ProctorClient.mcUuid.length > 0
        && uuid.replace(/-/g, "").toLowerCase() === ProctorClient.mcUuid.replace(/-/g, "").toLowerCase()

    // ---- punish state (live-bridge routed, mirrors the app) ----
    property string route: ""
    property var sections: []
    property var counts: ({})
    property var selected: []
    property var notes: []
    property string banner: ""
    property bool offencesOpen: false

    property string pendingAction: ""
    property string pendingNode: ""
    property bool pendingTemp: false
    property bool clearAllConfirm: false
    property bool offenceConfirm: false
    property bool offenceSilent: false
    readonly property var offSummary: offenceConfirm ? selectedRungs() : []
    readonly property var offStacked: offenceConfirm ? stackedActions() : []
    property bool clearHistoryConfirm: false
    // deleting the record log is owner/manager only — mirrors the broker's historyManagerGuard
    readonly property bool canManageHistory: ProctorClient.admin
        || ["manager", "owner", "founder"].indexOf((ProctorClient.rank || "").toLowerCase()) !== -1

    property int reqServers: -1
    property int reqGuide: -1
    property int reqCounts: -1
    property int reqNotes: -1
    property int reqNoteAdd: -1
    // punish/unpunish/offence writes this screen issued — only these refresh
    // history. The old catch-all reloaded on EVERY proctor response in the app
    // (poller included), which is what made History/Notes flicker.
    property var pendingWrites: ({})

    // ---- inventory (InvPlus over the cap session) ----
    property bool invOpen: false
    property bool invLoaded: false
    property string invError: ""
    property var snapshots: []
    property int reqSnaps: -1
    property int expandedSnap: -1
    property string confirmScope: ""
    property string confirmLabel: ""
    property bool invBusy: false
    property var pendingInv: ({})
    property string invDanger: ""

    // ---- adjust resources ----
    property bool adjOpen: false
    property int adjIndex: 0
    property int adjPending: 0
    property bool adjBusy: false
    property bool zeroConfirm: false
    readonly property var adjSpecs: [
        { key: "playtime", label: "Playtime", steps: [600, 3600, 86400] },
        { key: "gold", label: "Gold", steps: [100, 1000, 10000] },
        { key: "xp", label: "XP", steps: [1, 10, 50] },
        { key: "nectar", label: "Nectar", steps: [10, 100, 1000] }
    ]

    // ---- info (discord / playtime / join info) ----
    property string discordHandle: ""
    property var playtime: []
    property var joinInfo: null
    property int reqDiscord: -1
    property int reqPlaytime: -1
    property int reqInfo: -1

    // ---- reports filed against this player (jartonguard.player_reports) ----
    property var reports: []
    property int reqReports: -1
    property var reportPending: ({})   // resolve write ids

    readonly property var rawActions: [
        { label: "Ban",        action: "ban",       node: "ban",      color: "#ff6b6b", temp: false },
        { label: "Temp-ban",   action: "temp-ban",  node: "tempban",  color: "#ff6b6b", temp: true  },
        { label: "Ban IP",     action: "ban-ip",    node: "banip",    color: "#ff6b6b", temp: false },
        { label: "Mute",       action: "mute",      node: "mute",     color: "#f0a85a", temp: false },
        { label: "Temp-mute",  action: "temp-mute", node: "tempmute", color: "#f0a85a", temp: true  },
        { label: "Kick",       action: "kick",      node: "kick",     color: "#ffd24a", temp: false },
        { label: "Warn",       action: "warn",      node: "warn",     color: "#ffd24a", temp: false },
        { label: "Unban",      action: "unban",     node: "unban",    color: "#5ad17a", temp: false, un: true },
        { label: "Unmute",     action: "unmute",    node: "unmute",   color: "#5ad17a", temp: false, un: true },
        { label: "Revoke IP ban", action: "unban-ip", node: "unban",  color: "#5ad17a", temp: false, un: true },
        { label: "Shadowban",  action: "shadowban", node: "shadowban", color: "#8a7bff", temp: false, simple: true },
        { label: "Shadowmute", action: "shadowmute", node: "shadowmute", color: "#8a7bff", temp: false, simple: true },
        { label: "Unshadowban", action: "unshadowban", node: "unshadowban", color: "#5ad17a", temp: false, simple: true },
        { label: "Unshadowmute", action: "unshadowmute", node: "unshadowmute", color: "#5ad17a", temp: false, simple: true }
    ]

    Component.onCompleted: {
        PlayerHistoryModel.load(uuid, name)
        reqServers = ProctorApi.send("GET", "/proctor/servers")
        reqDiscord = ProctorApi.send("GET", "/proctor/players/discord?uuid=" + uuid)
        reqPlaytime = ProctorApi.send("GET", "/proctor/players/playtime?uuid=" + uuid)
        reqReports = ProctorApi.send("GET", "/proctor/players/reports?uuid=" + uuid)
        reqInfo = ProctorApi.send("GET", "/proctor/players/info?uuid=" + uuid)
    }

    function resolveReport(id) {
        reportPending[ProctorApi.send("POST", "/proctor/reports/" + id + "/resolve", "{}")] = id
    }

    function relTime(v) { return TimeFmt.rel(v) }
    function fmtWhen(v) { return TimeFmt.abs(v) }
    // player_reports.timestamp may be a MySQL DATETIME string or an epoch (s/ms) — normalize to ms
    function reportTs(t) {
        if (t === undefined || t === null) return 0
        if (typeof t === "number") return t > 1e12 ? t : t * 1000
        var s = "" + t
        var iso = (s.indexOf("T") === -1) ? s.replace(" ", "T") + "Z" : s
        var ms = Date.parse(iso); if (!isNaN(ms)) return ms
        var n = Number(s); return isNaN(n) ? 0 : (n > 1e12 ? n : n * 1000)
    }
    function fmtSeconds(s) {
        s = Number(s) || 0
        var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        var parts = []
        if (d > 0) parts.push(d + "d")
        if (h > 0) parts.push(h + "h")
        if (m > 0 || parts.length === 0) parts.push(m + "m")
        return parts.join(" ")
    }
    function fmtReason(r) {
        var words = String(r || "").split("_")
        for (var i = 0; i < words.length; i++) words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1)
        return words.join(" ")
    }
    function fmtGold(v) {
        if (v === undefined || v === null) return "—"
        return Math.round(v) === v ? String(v) : v.toFixed(2)
    }

    // ---- punish helpers ----
    function loadGuide() { reqGuide = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "guide", args: {} })) }
    function loadNotes() { reqNotes = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "notes", args: { target: uuid } })) }
    function addNote(text) {
        if (!text || !text.length) return
        reqNoteAdd = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "note-add", args: { target: uuid, targetName: name, text: text } }))
        banner = "Note added"
    }
    function removeNote(noteId) {
        reqNoteAdd = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "note-remove", args: { target: uuid, noteId: noteId } }))
        banner = "Note removed"
    }
    function allIds() {
        var ids = []
        for (var i = 0; i < sections.length; i++) for (var j = 0; j < sections[i].offenses.length; j++) ids.push(sections[i].offenses[j].id)
        return ids
    }
    function rung(off) {
        if (!off.ladder || !off.ladder.length) return null
        var n = counts[off.id] || 0
        return off.ladder[Math.min(n, off.ladder.length - 1)]
    }
    function rungLabel(off) { var r = rung(off); return r ? ("next: " + r.label) : "" }
    function flatOffences() { var out = []; for (var i = 0; i < sections.length; i++) for (var j = 0; j < sections[i].offenses.length; j++) out.push(sections[i].offenses[j]); return out }
    function offenceById(id) { var f = flatOffences(); for (var i = 0; i < f.length; i++) if (f[i].id === id) return f[i]; return null }
    // per-offence resolved rung, for the confirm summary
    function selectedRungs() {
        var out = []
        for (var i = 0; i < selected.length; i++) {
            var off = offenceById(selected[i]); if (!off) continue
            var r = rung(off); if (!r) continue
            out.push({ display: off.display, label: r.label })
        }
        return out
    }
    function durText(ms) {
        if (ms <= 0) return "Permanent"
        var rem = ms, parts = []
        var d = Math.floor(rem / 86400000); rem -= d * 86400000
        var h = Math.floor(rem / 3600000); rem -= h * 3600000
        var m = Math.floor(rem / 60000)
        if (d > 0) parts.push(d + "d"); if (h > 0) parts.push(h + "h"); if (m > 0) parts.push(m + "m")
        return parts.length ? parts.join(" ") : "0m"
    }
    function describeStep(type, ms) {
        if (type === "WARN") return "Warn"
        if (type === "KICK") return "Kick"
        var action = type
        if (type === "MUTE" || type === "TEMP_MUTE") action = "Mute"
        else if (type === "BAN" || type === "TEMP_BAN") action = "Ban"
        else if (type === "IP_BAN" || type === "TEMP_IP_BAN") action = "IP Ban"
        return ms <= 0 ? ("Permanent " + action) : (durText(ms) + " " + action)
    }
    // mirror of JartonGuard's PunishmentStacker: durations add within a family, permanent wins,
    // kick/warn pass through. Preview only — the plugin receipt stays authoritative.
    function stackedActions() {
        var ban = { on: false, perm: false, dur: 0 }, ip = { on: false, perm: false, dur: 0 }, mute = { on: false, perm: false, dur: 0 }
        var kick = false, warn = false
        for (var i = 0; i < selected.length; i++) {
            var off = offenceById(selected[i]); if (!off) continue
            var s = rung(off); if (!s) continue
            var ms = s.durationMs || 0, fam = null
            if (s.type === "BAN" || s.type === "TEMP_BAN") fam = ban
            else if (s.type === "IP_BAN" || s.type === "TEMP_IP_BAN") fam = ip
            else if (s.type === "MUTE" || s.type === "TEMP_MUTE") fam = mute
            else if (s.type === "KICK") { kick = true; continue }
            else if (s.type === "WARN") { warn = true; continue }
            else continue
            fam.on = true
            if (ms <= 0) fam.perm = true; else fam.dur += ms
        }
        var out = []
        if (ban.on) out.push(describeStep(ban.perm ? "BAN" : "TEMP_BAN", ban.perm ? 0 : ban.dur))
        if (ip.on) out.push(describeStep(ip.perm ? "IP_BAN" : "TEMP_IP_BAN", ip.perm ? 0 : ip.dur))
        if (mute.on) out.push(describeStep(mute.perm ? "MUTE" : "TEMP_MUTE", mute.perm ? 0 : mute.dur))
        if (kick) out.push("Kick")
        if (warn) out.push("Warn")
        return out
    }
    function allowed() {
        if (ProctorClient.admin) return null
        var helper = ["warn"], jrmod = helper.concat(["kick", "mute", "tempmute"]), mod = jrmod.concat(["tempban"]),
            srmod = mod.concat(["ban"]), jradmin = srmod.concat(["banip", "tempbanip"])
        switch ((ProctorClient.rank || "").toLowerCase()) {
        case "helper": return helper; case "jrmod": return jrmod; case "mod": return mod
        case "srmod": return srmod; case "jradmin": return jradmin; default: return null
        }
    }
    function canDo(node) { if (node.indexOf("un") === 0) return true; var a = allowed(); return a === null || a.indexOf(node) !== -1 }
    function visibleActions() {
        var out = []
        for (var i = 0; i < rawActions.length; i++) {
            var a = rawActions[i]
            if (a.action === "unban" && !PlayerHistoryModel.banned) continue
            if (a.action === "unban-ip" && !PlayerHistoryModel.ipBanned) continue
            if (a.action === "shadowban" && PlayerHistoryModel.shadowBanned) continue
            if (a.action === "unshadowban" && !PlayerHistoryModel.shadowBanned) continue
            if (a.action === "shadowmute" && PlayerHistoryModel.shadowMuted) continue
            if (a.action === "unshadowmute" && !PlayerHistoryModel.shadowMuted) continue
            if (canDo(a.node)) out.push(a)
        }
        return out
    }
    function toggle(id) { var s = selected.slice(); var i = s.indexOf(id); if (i === -1) s.push(id); else s.splice(i, 1); selected = s }
    function trackWrite(id) { var p = pendingWrites; p[id] = true; pendingWrites = p }
    function sendRaw(reason, durationMs) {
        // shadow actions are their own bridge types; the reason rides along for the history
        // trail only — the player never sees it
        var isShadow = pendingAction === "shadowban" || pendingAction === "shadowmute"
        var args = isShadow ? { target: uuid, targetName: name, reason: reason }
                            : { target: uuid, targetName: name, action: pendingAction, reason: reason }
        if (!isShadow && durationMs > 0) args.durationMs = durationMs
        trackWrite(ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: isShadow ? pendingAction : "punish", args: args })))
        banner = pendingAction + " sent for " + name
        pendingAction = ""
    }
    function sendUn(action) {
        trackWrite(ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "unpunish", args: { target: uuid, targetName: name, action: action } })))
        banner = action + " sent"
    }
    function sendSimple(action) {
        trackWrite(ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: action, args: { target: uuid, targetName: name } })))
        banner = action + " sent for " + name
    }
    function sendClearAll() {
        trackWrite(ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "clear-punishments", args: { target: uuid, targetName: name } })))
        banner = "Cleared all punishments for " + name
        clearAllConfirm = false
    }
    function sendClearHistory() {
        trackWrite(ProctorApi.send("POST", "/proctor/players/history/clear", JSON.stringify({ uuid: uuid })))
        banner = "Cleared punishment history for " + name
        clearHistoryConfirm = false
    }
    function deleteHistoryEntry(id) {
        trackWrite(ProctorApi.send("POST", "/proctor/players/history/delete", JSON.stringify({ id: id })))
        banner = "Removed history entry"
    }
    function applyOffenses() {
        if (!selected.length) return
        if (isSelf) { banner = "You can't punish yourself"; return }
        var args = { target: uuid, categories: selected }
        var reason = offReasonIn.text.trim()
        if (reason.length) args.reason = reason
        if (offenceSilent) args.silent = true
        trackWrite(ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "punish-offense", args: args })))
        banner = "Applied " + selected.length + " offence" + (selected.length === 1 ? "" : "s") + " to " + name
        selected = []; offenceConfirm = false; offenceSilent = false; offReasonIn.text = ""
    }
    function pressAction(a) {
        if (a.un) { sendUn(a.action); return }
        if (a.simple) {
            if (a.action.indexOf("un") === 0) { sendSimple(a.action); return }
            if (isSelf) { banner = "You can't punish yourself"; return }
            pendingAction = a.action; pendingNode = a.node; pendingTemp = false
            return
        }
        if (isSelf) { banner = "You can't punish yourself"; return }
        if (a.action === "kick" || a.action === "warn") { pendingAction = a.action; pendingNode = a.node; pendingTemp = false }
        else { pendingAction = a.action; pendingNode = a.node; pendingTemp = a.temp }
    }

    // ---- inventory helpers ----
    function loadSnapshots() {
        if (invLoaded) return
        invLoaded = true; invError = ""
        reqSnaps = StaffApi.send("GET", "/invplus/players/" + uuid + "/snapshots")
    }
    function restore(scope, label) {
        invBusy = true
        var p = pendingInv
        p[StaffApi.send("POST", "/invplus/restore", JSON.stringify({ player: name, target: String(expandedSnap), scope: scope }))] = "Restored " + label.toLowerCase() + " to " + name + "."
        pendingInv = p
        confirmScope = ""; confirmLabel = ""
    }
    function applyAdjust() {
        if (adjPending === 0 || adjBusy) return
        adjBusy = true
        var spec = adjSpecs[adjIndex]
        var p = pendingInv
        p[StaffApi.send("POST", "/invplus/adjust", JSON.stringify({ player: name, resource: spec.key, amount: adjPending }))] =
            "Applied " + adjLabel() + " " + spec.label.toLowerCase() + " to " + name + "."
        pendingInv = p
    }
    function zeroResource() {
        if (adjBusy) return
        adjBusy = true
        var spec = adjSpecs[adjIndex]
        var p = pendingInv
        p[StaffApi.send("POST", "/invplus/zero", JSON.stringify({ player: name, resource: spec.key }))] =
            "Removed all " + spec.label.toLowerCase() + " from " + name + "."
        pendingInv = p
        zeroConfirm = false
    }
    function runInvDanger() {
        if (invBusy) return
        invBusy = true
        var p = pendingInv
        if (invDanger === "clear")
            p[StaffApi.send("POST", "/invplus/clear", JSON.stringify({ player: name }))] = "Cleared " + name + "'s inventory."
        else
            p[StaffApi.send("POST", "/invplus/wipe", JSON.stringify({ player: name }))] = "Wipe queued for " + name + "."
        pendingInv = p
        invDanger = ""
    }
    function adjLabel() {
        var spec = adjSpecs[adjIndex]
        if (spec.key === "playtime") {
            var sign = adjPending < 0 ? "-" : "+"
            return sign + fmtSeconds(Math.abs(adjPending))
        }
        return (adjPending > 0 ? "+" : "") + adjPending
    }
    function stepLabel(delta) {
        var spec = adjSpecs[adjIndex]
        var sign = delta > 0 ? "+" : "-"
        var v = Math.abs(delta)
        if (spec.key === "playtime") {
            if (v >= 86400) return sign + (v / 86400) + "d"
            if (v >= 3600) return sign + (v / 3600) + "h"
            return sign + (v / 60) + "m"
        }
        return sign + v
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqServers) {
                if (ok) { try { var s = JSON.parse(body).servers || []; if (s.length && !root.route.length) { root.route = s[0]; root.loadGuide(); root.loadNotes() } } catch (e) {} }
                return
            }
            if (id === root.reqGuide) {
                if (ok) { try { root.sections = (JSON.parse(body).data || {}).sections || [] } catch (e) { root.sections = [] }
                    root.reqCounts = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: root.route, type: "offense-counts", args: { target: root.uuid, categories: root.allIds() } })) }
                return
            }
            if (id === root.reqCounts) { if (ok) { try { root.counts = (JSON.parse(body).data || {}).counts || {} } catch (e) { root.counts = {} } } return }
            if (id === root.reqNotes) { if (ok) { try { root.notes = (JSON.parse(body).data) || [] } catch (e) { root.notes = [] } } return }
            if (id === root.reqNoteAdd) { if (ok) root.loadNotes(); else root.banner = "Note failed (" + status + ")."; return }
            if (id === root.reqDiscord) {
                if (ok) { try { var d = JSON.parse(body); root.discordHandle = d.linked ? (d.handle || "") : "" } catch (e) {} }
                return
            }
            if (id === root.reqPlaytime) {
                if (ok) { try { root.playtime = JSON.parse(body).playtime || [] } catch (e) { root.playtime = [] } }
                return
            }
            if (id === root.reqInfo) {
                if (ok) { try { root.joinInfo = JSON.parse(body).info || null } catch (e) { root.joinInfo = null } }
                return
            }
            if (id === root.reqReports) {
                if (ok) { try { root.reports = JSON.parse(body).reports || [] } catch (e) { root.reports = [] } }
                return
            }
            if (root.reportPending[id] !== undefined) {
                var rp = root.reportPending; delete rp[id]; root.reportPending = rp
                if (ok) root.reqReports = ProctorApi.send("GET", "/proctor/players/reports?uuid=" + root.uuid)
                else root.banner = "Resolve failed (" + status + ")."
                return
            }
            // only writes THIS screen issued refresh the history — everything else
            // on the shared session (pollers, other tabs) is none of our business
            if (root.pendingWrites[id] !== undefined) {
                var p = root.pendingWrites; delete p[id]; root.pendingWrites = p
                if (!ok) {
                    // the broker's refusals carry the actual reason ("you can't
                    // punish yourself", rank wall) — show it, not just the code
                    var why = ""
                    try { why = JSON.parse(body).error || "" } catch (e) {}
                    root.banner = why.length ? why : "Action failed (" + status + ")."
                } else {
                    PlayerHistoryModel.load(root.uuid, root.name)
                }
            }
        }
    }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqSnaps) {
                if (ok) { try { root.snapshots = JSON.parse(body).snapshots || [] } catch (e) { root.snapshots = [] } }
                else root.invError = status === 403 || status === 409 ? "No inventory access — connect your panel key." : "Couldn't load snapshots (" + status + ")."
                return
            }
            if (root.pendingInv[id] !== undefined) {
                var msg = root.pendingInv[id]
                var p = root.pendingInv; delete p[id]; root.pendingInv = p
                root.invBusy = false; root.adjBusy = false
                if (ok) { root.banner = msg; if (msg.indexOf("Applied") === 0) root.adjPending = 0 }
                else root.banner = "InvPlus action failed (" + status + ") — player offline or no console access."
            }
        }
    }

    component InfoRow: Item {
        property string k: ""
        property string v: ""
        property bool copyable: false
        visible: v.length > 0
        width: parent ? parent.width : 0; height: 20
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: k; color: "#8a7a56"; font.pixelSize: 12 }
        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: v; color: "#F2E8D0"; font.pixelSize: 13
            MouseArea {
                anchors.fill: parent; visible: copyable; cursorShape: Qt.PointingHandCursor
                onClicked: { ProctorClient.copyToClipboard(v); root.banner = "Copied " + v }
            }
        }
    }

    component SectionHeader: Rectangle {
        id: sh
        property string title: ""
        property bool open: false
        property string badge: ""
        signal toggled()
        width: parent.width; height: 42; radius: 11
        color: shHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)
        Behavior on color { ColorAnimation { duration: 100 } }
        Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: sh.title; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            Rectangle {
                visible: sh.badge.length > 0; anchors.verticalCenter: parent.verticalCenter
                width: shBadge.width + 14; height: 18; radius: 9; color: Qt.rgba(1, 0.72, 0.2, 0.16)
                Text { id: shBadge; anchors.centerIn: parent; text: sh.badge; color: "#FFB833"; font.pixelSize: 10; font.bold: true }
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/jarton/staff/icons/ui/chevron-up-cream.svg"
                width: 12; height: 12; sourceSize: Qt.size(24, 24)
                rotation: sh.open ? 180 : 90
                Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea { id: shHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sh.toggled() }
    }

    Flickable {
        id: detailFlick
        anchors.fill: parent
        contentWidth: width; contentHeight: detailCol.height + 16; clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600
        maximumFlickVelocity: 6000
        property real accel: 1
        property real lastWheel: 0
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse
            onWheel: function (e) {
                var now = Date.now()
                detailFlick.accel = (now - detailFlick.lastWheel < 90) ? Math.min(detailFlick.accel + 0.7, 7) : 1.4
                detailFlick.lastWheel = now
                var maxY = Math.max(0, detailFlick.contentHeight - detailFlick.height)
                detailFlick.contentY = Math.max(0, Math.min(maxY, detailFlick.contentY - (e.angleDelta.y / 120) * 64 * detailFlick.accel))
                e.accepted = true
            }
        }

        Column {
            id: detailCol
            width: parent.width; spacing: 14

            // header
            Item {
                width: parent.width; height: 44
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    SButton { anchors.verticalCenter: parent.verticalCenter; text: "Back"; icon: "chevron-left"; variant: "ghost"; onClicked: root.closed() }
                    Avatar { anchors.verticalCenter: parent.verticalCenter; size: 40; uuid: root.uuid }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 3
                        Text { text: root.name; color: "#FFFFFF"; font.pixelSize: 19; font.bold: true }
                        Row {
                            spacing: 6
                            Rectangle {
                                visible: PlayerHistoryModel.banned; width: bb.width + 14; height: 18; radius: 9; color: Qt.rgba(1, 0.42, 0.42, 0.16)
                                Text { id: bb; anchors.centerIn: parent; text: "Banned"; color: "#ff6b6b"; font.pixelSize: 10; font.bold: true }
                            }
                            Rectangle {
                                visible: PlayerHistoryModel.ipBanned; width: ib.width + 14; height: 18; radius: 9; color: Qt.rgba(1, 0.22, 0.22, 0.26)
                                Text { id: ib; anchors.centerIn: parent; text: "IP Banned"; color: "#ff4d4d"; font.pixelSize: 10; font.bold: true }
                            }
                            Rectangle {
                                visible: PlayerHistoryModel.muted; width: mb.width + 14; height: 18; radius: 9; color: Qt.rgba(0.94, 0.66, 0.35, 0.16)
                                Text { id: mb; anchors.centerIn: parent; text: "Muted"; color: "#f0a85a"; font.pixelSize: 10; font.bold: true }
                            }
                            Rectangle {
                                visible: !PlayerHistoryModel.banned && !PlayerHistoryModel.ipBanned && !PlayerHistoryModel.muted; width: cb.width + 14; height: 18; radius: 9; color: Qt.rgba(0.35, 0.82, 0.48, 0.16)
                                Text { id: cb; anchors.centerIn: parent; text: "Clean"; color: "#5ad17a"; font.pixelSize: 10; font.bold: true }
                            }
                            Rectangle {
                                visible: root.discordHandle.length > 0
                                width: dh.width + 16; height: 18; radius: 9; color: Qt.rgba(0.35, 0.4, 0.9, 0.2)
                                Text { id: dh; anchors.centerIn: parent; text: "@" + root.discordHandle; color: "#9aa8ff"; font.pixelSize: 10; font.bold: true }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { ProctorClient.copyToClipboard(root.discordHandle); root.banner = "Copied @" + root.discordHandle }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 30; radius: 9; visible: root.banner.length > 0
                color: Qt.rgba(0.35, 0.82, 0.48, 0.14)
                Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: root.banner; color: "#9fe0ad"; font.pixelSize: 12 }
            }

            // ---- action buttons grid ----
            Grid {
                width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: root.visibleActions()
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool blocked: root.isSelf && !modelData.un
                        width: (detailCol.width - 8) / 2; height: 52; radius: 12
                        opacity: blocked ? 0.35 : 1
                        color: aHover.containsMouse && !blocked ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: modelData.label; color: modelData.color; font.pixelSize: 15; font.bold: true }
                        MouseArea { id: aHover; anchors.fill: parent; hoverEnabled: true; cursorShape: parent.blocked ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: root.pressAction(modelData) }
                    }
                }
            }

            // ---- raw compose form ----
            Rectangle {
                width: parent.width; height: confirmForm.implicitHeight + 24; radius: 12; visible: root.pendingAction.length > 0
                color: Qt.rgba(1, 1, 1, 0.05); border.color: "#FFB833"; border.width: 1
                Column {
                    id: confirmForm
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12; spacing: 8
                    Text { text: "Confirm " + root.pendingAction; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                    Text {
                        visible: root.pendingAction === "shadowban" || root.pendingAction === "shadowmute"
                        text: "The player never sees this — logged to JartonGuard for staff only."
                        color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11
                    }
                    Rectangle {
                        width: parent.width; height: 30; radius: 8; color: Qt.rgba(1, 1, 1, 0.06)
                        TextInput {
                            id: reasonIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 13; clip: true
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Reason…"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13; visible: reasonIn.text.length === 0 }
                        }
                    }
                    Row {
                        spacing: 8
                        Rectangle {
                            visible: root.pendingTemp; width: 96; height: 30; radius: 8; color: Qt.rgba(1, 1, 1, 0.06)
                            TextInput {
                                id: durIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 13; clip: true; validator: IntValidator { bottom: 0 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "minutes"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 12; visible: durIn.text.length === 0 }
                            }
                        }
                        SButton { text: "Apply"; variant: "primary"; onClicked: root.sendRaw(reasonIn.text, root.pendingTemp ? (parseInt(durIn.text || "0") * 60000) : 0) }
                        SButton { text: "Cancel"; variant: "ghost"; onClicked: root.pendingAction = "" }
                    }
                }
            }

            // ---- clear all punishments ----
            Column {
                width: parent.width; spacing: 6
                visible: PlayerHistoryModel.banned || PlayerHistoryModel.ipBanned || PlayerHistoryModel.muted
                         || PlayerHistoryModel.shadowBanned || PlayerHistoryModel.shadowMuted
                SButton { visible: !root.clearAllConfirm; text: "Clear all punishments"; variant: "danger"; compact: true; onClicked: root.clearAllConfirm = true }
                Column {
                    visible: root.clearAllConfirm
                    width: parent.width; spacing: 6
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Clear ALL punishments for " + root.name + "? Lifts bans, IP bans, mutes, freeze, shadow-ban/mute, inventory locks."
                        color: "#FFE082"; font.pixelSize: 12
                    }
                    Row {
                        spacing: 8
                        SButton { text: "Clear all"; variant: "danger"; compact: true; onClicked: root.sendClearAll() }
                        SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: root.clearAllConfirm = false }
                    }
                }
            }

            // ---- offences ----
            Column {
                width: parent.width; spacing: 8
                SectionHeader {
                    title: "Offences"; open: root.offencesOpen
                    badge: root.selected.length > 0 ? root.selected.length + " selected" : ""
                    onToggled: root.offencesOpen = !root.offencesOpen
                }
                Column {
                    width: parent.width; spacing: 6; visible: root.offencesOpen
                    Repeater {
                        model: root.offencesOpen ? root.flatOffences() : []
                        delegate: Rectangle {
                            required property var modelData
                            width: detailCol.width; height: Math.max(48, oCol.height + 18); radius: 10
                            color: root.selected.indexOf(modelData.id) !== -1 ? Qt.rgba(1, 0.72, 0.2, 0.12) : (oa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: root.selected.indexOf(modelData.id) !== -1 ? "#FFB833" : "transparent"; border.width: 1
                            Column {
                                id: oCol
                                anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: chk.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { text: modelData.display; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
                                Text { text: root.rungLabel(modelData); color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11; visible: text.length > 0; width: parent.width; wrapMode: Text.WordWrap }
                            }
                            Text { id: chk; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: root.selected.indexOf(modelData.id) !== -1 ? "✓" : ""; color: "#FFB833"; font.pixelSize: 16; font.bold: true }
                            MouseArea { id: oa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(modelData.id) }
                        }
                    }
                    Text { visible: root.sections.length === 0; text: "Loading offences…"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13 }
                    SButton {
                        visible: root.selected.length > 0 && !root.offenceConfirm
                        text: "Review " + root.selected.length + " offence" + (root.selected.length === 1 ? "" : "s"); variant: "primary"
                        onClicked: root.offenceConfirm = true
                    }

                    // ---- offence confirm summary (what stacks, what the player receives) ----
                    Rectangle {
                        visible: root.offenceConfirm && root.selected.length > 0
                        width: detailCol.width; height: offConfirmCol.implicitHeight + 24; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05); border.color: "#FFB833"; border.width: 1
                        Column {
                            id: offConfirmCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 12; spacing: 8
                            Text { text: "Applying to " + root.name; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                            Column {
                                width: parent.width; spacing: 4
                                Repeater {
                                    model: root.offSummary
                                    delegate: Row {
                                        required property var modelData
                                        width: offConfirmCol.width; spacing: 8
                                        Text { text: modelData.display; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 12; width: parent.width * 0.55; elide: Text.ElideRight }
                                        Text { text: modelData.label; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 12; horizontalAlignment: Text.AlignRight; width: parent.width * 0.45 - 8; elide: Text.ElideRight }
                                    }
                                }
                            }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                            Text { text: "Player receives"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11 }
                            Column {
                                width: parent.width; spacing: 3
                                Repeater {
                                    model: root.offStacked
                                    delegate: Text { required property var modelData; text: modelData; color: "#FFB833"; font.pixelSize: 14; font.bold: true }
                                }
                            }
                            Rectangle {
                                width: parent.width; height: 30; radius: 8; color: Qt.rgba(1, 1, 1, 0.06)
                                TextInput {
                                    id: offReasonIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 13; clip: true
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Reason (optional)…"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13; visible: offReasonIn.text.length === 0 }
                                }
                            }
                            Row {
                                spacing: 8
                                SButton { text: root.offenceSilent ? "Silent: on" : "Silent: off"; variant: root.offenceSilent ? "secondary" : "ghost"; compact: true; onClicked: root.offenceSilent = !root.offenceSilent }
                                SButton { text: "Confirm & apply"; variant: "primary"; compact: true; onClicked: root.applyOffenses() }
                                SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: { root.offenceConfirm = false; root.offenceSilent = false; offReasonIn.text = "" } }
                            }
                        }
                    }
                }
            }

            // ---- inventory (snapshots + restore) ----
            Column {
                width: parent.width; spacing: 8
                SectionHeader {
                    title: "Inventory"; open: root.invOpen
                    badge: root.snapshots.length > 0 ? root.snapshots.length + " snapshots" : ""
                    onToggled: { root.invOpen = !root.invOpen; if (root.invOpen) root.loadSnapshots() }
                }
                Column {
                    width: parent.width; spacing: 6; visible: root.invOpen
                    Text { visible: root.invError.length > 0; text: root.invError; color: "#e06c6c"; font.pixelSize: 13 }
                    Text {
                        visible: root.invError.length === 0 && root.invLoaded && root.snapshots.length === 0
                        text: "No snapshots for this player yet."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13
                    }
                    ListView {
                        width: parent.width
                        visible: root.snapshots.length > 0
                        height: Math.min(contentHeight, 300)
                        clip: true; spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.snapshots
                        delegate: Rectangle {
                            id: snapCard
                            required property var modelData
                            readonly property bool expanded: root.expandedSnap === modelData.id
                            width: detailCol.width
                            height: snapCol.height + 20
                            radius: 11
                            color: expanded ? Qt.rgba(1, 0.72, 0.2, 0.07) : (sHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: expanded ? "#3a2f14" : "transparent"; border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            MouseArea {
                                id: sHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.confirmScope = ""; root.expandedSnap = snapCard.expanded ? -1 : snapCard.modelData.id }
                            }
                            Column {
                                id: snapCol
                                anchors.left: parent.left; anchors.leftMargin: 14
                                anchors.right: parent.right; anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Item {
                                    width: parent.width; height: 30
                                    Column {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                        Text { text: root.fmtReason(snapCard.modelData.reason); color: "#F2E8D0"; font.pixelSize: 13; font.bold: true }
                                        Text {
                                            text: root.fmtWhen(snapCard.modelData.createdAt)
                                                  + "  ·  gold " + root.fmtGold(snapCard.modelData.gold)
                                                  + "  ·  xp " + (snapCard.modelData.expLevel === undefined || snapCard.modelData.expLevel === null ? "—" : Math.floor(snapCard.modelData.expLevel))
                                            color: "#8a7a56"; font.pixelSize: 11
                                        }
                                    }
                                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "#" + snapCard.modelData.id; color: "#6b5d3f"; font.pixelSize: 11; font.family: "Menlo" }
                                }
                                // restore strip (auto pre-restore snapshot server-side, so it's reversible)
                                Row {
                                    visible: snapCard.expanded && root.confirmScope.length === 0
                                    spacing: 7
                                    SButton { text: "Items"; variant: "secondary"; compact: true; enabled: !root.invBusy; onClicked: { root.confirmScope = "items"; root.confirmLabel = "Items" } }
                                    SButton { text: "Ender chest"; variant: "secondary"; compact: true; enabled: !root.invBusy; onClicked: { root.confirmScope = "ender"; root.confirmLabel = "Ender chest" } }
                                    SButton { text: "Vaults"; variant: "secondary"; compact: true; enabled: !root.invBusy; onClicked: { root.confirmScope = "vaults"; root.confirmLabel = "Vaults" } }
                                    SButton { text: "XP"; variant: "secondary"; compact: true; enabled: !root.invBusy; onClicked: { root.confirmScope = "xp"; root.confirmLabel = "XP" } }
                                    SButton { text: "Gold"; variant: "secondary"; compact: true; enabled: !root.invBusy; onClicked: { root.confirmScope = "gold"; root.confirmLabel = "Gold" } }
                                    SButton {
                                        // pre-nectar snapshots carry null — nothing to restore, so no button
                                        visible: snapCard.modelData.nectar !== null && snapCard.modelData.nectar !== undefined
                                        text: "Nectar"; variant: "secondary"; compact: true; enabled: !root.invBusy
                                        onClicked: { root.confirmScope = "nectar"; root.confirmLabel = "Nectar" }
                                    }
                                    SButton { text: "Everything"; variant: "danger"; compact: true; enabled: !root.invBusy; onClicked: { root.confirmScope = "all"; root.confirmLabel = "Everything" } }
                                }
                                Row {
                                    visible: snapCard.expanded && root.confirmScope.length > 0
                                    spacing: 8
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Restore " + root.confirmLabel.toLowerCase() + " to " + root.name + "?"; color: "#FFE082"; font.pixelSize: 12 }
                                    SButton { text: "Restore"; variant: "primary"; compact: true; busy: root.invBusy; onClicked: root.restore(root.confirmScope, root.confirmLabel) }
                                    SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: root.confirmScope = "" }
                                }
                            }
                        }
                    }
                    Row {
                        visible: root.invDanger.length === 0 && StaffAuth.canPanel
                        spacing: 7
                        SButton { text: "Clear inventory"; variant: "danger"; compact: true; enabled: !root.invBusy; onClicked: root.invDanger = "clear" }
                        SButton { text: "Wipe player"; variant: "danger"; compact: true; enabled: !root.invBusy; onClicked: root.invDanger = "wipe" }
                    }
                    Text {
                        visible: !StaffAuth.canPanel
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "You don't have permission to clear or wipe inventories."; color: "#6b5d3f"; font.pixelSize: 12
                    }
                    Column {
                        visible: root.invDanger.length > 0
                        width: parent.width; spacing: 6
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: root.invDanger === "clear"
                                  ? "Empty inventory, armor + ender chest? Snapshot taken first; applies on next join if offline."
                                  : "Full reset — items, vaults, XP, gold, playtime, nectar, advancements, spawn. Snapshot first; applies on next join if offline."
                            color: "#FFE082"; font.pixelSize: 12
                        }
                        Row {
                            spacing: 8
                            SButton { text: root.invDanger === "clear" ? "Clear" : "Wipe"; variant: "danger"; compact: true; busy: root.invBusy; onClicked: root.runInvDanger() }
                            SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: root.invDanger = "" }
                        }
                    }
                }
            }

            // ---- adjust resources ----
            Column {
                width: parent.width; spacing: 8
                SectionHeader {
                    title: "Adjust resources"; open: root.adjOpen
                    onToggled: root.adjOpen = !root.adjOpen
                }
                Text {
                    visible: root.adjOpen && !StaffAuth.canPanel
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "You don't have permission to adjust player resources."; color: "#6b5d3f"; font.pixelSize: 12
                }
                Rectangle {
                    width: parent.width; visible: root.adjOpen && StaffAuth.canPanel
                    height: adjCol.height + 24; radius: 11
                    color: Qt.rgba(1, 1, 1, 0.04)
                    Column {
                        id: adjCol
                        anchors.top: parent.top; anchors.topMargin: 12
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
                        spacing: 10
                        Row {
                            spacing: 6
                            Repeater {
                                model: root.adjSpecs
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: root.adjIndex === index
                                    width: rTxt.width + 22; height: 26; radius: 8
                                    color: active ? "#3a2f14" : "transparent"
                                    border.color: active ? "#FFB81C" : "#2a2114"; border.width: 1
                                    Text { id: rTxt; anchors.centerIn: parent; text: modelData.label; color: active ? "#FFE082" : "#8a7a56"; font.pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.adjIndex = index; root.adjPending = 0; root.zeroConfirm = false } }
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.adjLabel()
                            color: root.adjPending === 0 ? "#6b5d3f" : (root.adjPending > 0 ? "#5ad17a" : "#ff6b6b")
                            font.pixelSize: 26; font.bold: true; font.family: "Menlo"
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            Repeater {
                                model: root.adjSpecs[root.adjIndex].steps
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 74; height: 30; radius: 9; color: Qt.rgba(1, 0.42, 0.42, 0.12)
                                    Text { anchors.centerIn: parent; text: root.stepLabel(-modelData); color: "#ff8f8f"; font.pixelSize: 12; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !root.adjBusy; onClicked: root.adjPending -= modelData }
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            Repeater {
                                model: root.adjSpecs[root.adjIndex].steps
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 74; height: 30; radius: 9; color: Qt.rgba(0.35, 0.82, 0.48, 0.12)
                                    Text { anchors.centerIn: parent; text: root.stepLabel(modelData); color: "#7fdb95"; font.pixelSize: 12; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !root.adjBusy; onClicked: root.adjPending += modelData }
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            visible: !root.zeroConfirm
                            SButton { text: "Reset"; variant: "ghost"; compact: true; enabled: root.adjPending !== 0 && !root.adjBusy; onClicked: root.adjPending = 0 }
                            SButton { text: "Apply"; variant: "primary"; compact: true; busy: root.adjBusy; enabled: root.adjPending !== 0; onClicked: root.applyAdjust() }
                            SButton { text: "Remove all"; variant: "danger"; compact: true; enabled: !root.adjBusy; onClicked: root.zeroConfirm = true }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            visible: root.zeroConfirm
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Remove ALL " + root.adjSpecs[root.adjIndex].label.toLowerCase() + " from " + root.name + "? Applies on next join if offline."; color: "#FFE082"; font.pixelSize: 12 }
                            SButton { text: "Remove"; variant: "danger"; compact: true; busy: root.adjBusy; onClicked: root.zeroResource() }
                            SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: root.zeroConfirm = false }
                        }
                        Item { width: 1; height: 2 }
                    }
                }
            }

            // ---- playtime ----
            Column {
                width: parent.width; spacing: 8; visible: root.playtime.length > 0
                Text { text: "Playtime"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
                Rectangle {
                    width: parent.width; height: ptCol.height + 20; radius: 11; color: Qt.rgba(1, 1, 1, 0.04)
                    Column {
                        id: ptCol
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Repeater {
                            model: root.playtime
                            delegate: Item {
                                required property var modelData
                                width: parent.width; height: 20
                                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: modelData.server; color: "#F2E8D0"; font.pixelSize: 13 }
                                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.fmtSeconds(modelData.seconds); color: "#FFB833"; font.pixelSize: 13; font.bold: true }
                            }
                        }
                        Item {
                            visible: root.playtime.length > 1
                            width: parent.width; height: 20
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Total"; color: "#8a7a56"; font.pixelSize: 12; font.bold: true }
                            Text {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: { var t = 0; for (var i = 0; i < root.playtime.length; i++) t += Number(root.playtime[i].seconds) || 0; return root.fmtSeconds(t) }
                                color: "#F2E8D0"; font.pixelSize: 12; font.bold: true
                            }
                        }
                    }
                }
            }

            // ---- join info (broker decides masked vs full by rank) ----
            Column {
                width: parent.width; spacing: 8; visible: root.joinInfo !== null
                Text { text: "Join info"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
                Text { text: "First seen shown in your local time (" + TimeFmt.zoneLabel + ")"; color: "#6b5d3f"; font.pixelSize: 11 }
                Row {
                    visible: root.joinInfo && root.joinInfo.masked === true
                    spacing: 6
                    Rectangle {
                        width: mtag.width + 12; height: 16; radius: 8; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { id: mtag; anchors.centerIn: parent; text: "MASKED"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 9; font.bold: true }
                    }
                    Text { height: 16; verticalAlignment: Text.AlignVCenter; text: "Full IP and alts are restricted to admins and above."; color: "#6b5d3f"; font.pixelSize: 11 }
                }
                Rectangle {
                    width: parent.width; height: jiCol.height + 20; radius: 11; color: Qt.rgba(1, 1, 1, 0.04)
                    Column {
                        id: jiCol
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        InfoRow { k: "IP"; v: root.joinInfo ? (root.joinInfo.ip || "") : ""; copyable: true }
                        InfoRow {
                            k: "Location"; copyable: true
                            v: {
                                if (!root.joinInfo) return ""
                                var bits = []
                                if (root.joinInfo.city) bits.push(root.joinInfo.city)
                                if (root.joinInfo.region) bits.push(root.joinInfo.region)
                                if (root.joinInfo.country) bits.push(root.joinInfo.country)
                                return bits.join(", ")
                            }
                        }
                        InfoRow { k: "ISP"; v: root.joinInfo ? (root.joinInfo.isp || "") : ""; copyable: true }
                        Row {
                            spacing: 6
                            visible: root.joinInfo !== null && (root.joinInfo.proxy || root.joinInfo.hosting || root.joinInfo.mobile)
                            Repeater {
                                model: {
                                    var out = []
                                    if (root.joinInfo) {
                                        if (root.joinInfo.proxy) out.push("proxy")
                                        if (root.joinInfo.hosting) out.push("hosting")
                                        if (root.joinInfo.mobile) out.push("mobile")
                                    }
                                    return out
                                }
                                delegate: Rectangle {
                                    required property var modelData
                                    width: fTxt.width + 14; height: 18; radius: 9; color: Qt.rgba(1, 0.42, 0.42, 0.16)
                                    Text { id: fTxt; anchors.centerIn: parent; text: modelData; color: "#ff8f8f"; font.pixelSize: 10; font.bold: true }
                                }
                            }
                        }
                        InfoRow { k: "First seen"; v: root.joinInfo && root.joinInfo.firstSeen ? root.fmtWhen(root.joinInfo.firstSeen) : "" }
                        InfoRow { k: "Last seen"; v: root.joinInfo && root.joinInfo.lastSeen ? root.relTime(root.joinInfo.lastSeen) : "" }
                        Item {
                            visible: root.joinInfo !== null && root.joinInfo.alts && root.joinInfo.alts.length > 0
                            width: parent.width; height: 20
                            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Alts"; color: "#8a7a56"; font.pixelSize: 12 }
                            Text {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!root.joinInfo || !root.joinInfo.alts) return ""
                                    var names = []
                                    for (var i = 0; i < root.joinInfo.alts.length; i++) names.push(root.joinInfo.alts[i].name)
                                    return names.join(", ")
                                }
                                color: "#F2E8D0"; font.pixelSize: 13; elide: Text.ElideRight
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { ProctorClient.copyToClipboard(parent.text); root.banner = "Copied alt list" }
                                }
                            }
                        }
                    }
                }
            }

            // ---- history ----
            Text { text: "History"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
            Text { visible: PlayerHistoryModel.count === 0 && !PlayerHistoryModel.loading; text: "No punishments on record."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13 }
            Column {
                width: parent.width; spacing: 6
                Repeater {
                    model: PlayerHistoryModel
                    delegate: Rectangle {
                        width: detailCol.width; height: hc.height + 20; radius: 11
                        color: "#16110a"; border.color: active ? "#4a3018" : "#241c12"; border.width: 1
                        // duration text for temp actions ("30m", "7d"); 0 = permanent
                        function fmtDur(ms) {
                            if (!ms || ms <= 0) return ""
                            var m = Math.round(Number(ms) / 60000)
                            if (m < 60) return m + "m"
                            var h = Math.round(m / 60)
                            if (h < 48) return h + "h"
                            return Math.round(h / 24) + "d"
                        }
                        // per-entry delete (owner/manager tier) — removes just this record via history/delete
                        Image {
                            id: histX
                            visible: root.canManageHistory
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 12
                            source: "qrc:/jarton/staff/icons/ui/x-cream.svg"
                            width: 11; height: 11; sourceSize: Qt.size(22, 22)
                            opacity: histXHover.containsMouse ? 0.9 : 0.35
                            MouseArea { id: histXHover; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.deleteHistoryEntry(model.id) }
                        }
                        Column {
                            id: hc
                            anchors.left: parent.left; anchors.leftMargin: 14
                            anchors.right: root.canManageHistory ? histX.left : parent.right; anchors.rightMargin: root.canManageHistory ? 8 : 14
                            anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Item {
                                width: parent.width; height: 16
                                Row {
                                    anchors.left: parent.left; spacing: 6
                                    Text { text: action.toUpperCase() + (fmtDur(duration).length ? "  ·  " + fmtDur(duration) : ""); color: "#FFB833"; font.pixelSize: 12; font.bold: true }
                                    Rectangle {
                                        visible: { var a = action.toLowerCase().replace(/ /g, "-"); return a === "ban-ip" || a === "temp-ban-ip" }
                                        width: ipv.width + 12; height: 16; radius: 8; color: Qt.rgba(1, 0.28, 0.28, 0.2); anchors.verticalCenter: parent.verticalCenter
                                        Text { id: ipv; anchors.centerIn: parent; text: "IP"; color: "#ff6b6b"; font.pixelSize: 9; font.bold: true } }
                                    Rectangle { visible: active; width: av.width + 12; height: 16; radius: 8; color: Qt.rgba(1, 0.72, 0.2, 0.18); anchors.verticalCenter: parent.verticalCenter
                                        Text { id: av; anchors.centerIn: parent; text: "active"; color: "#FFB81C"; font.pixelSize: 9; font.bold: true } }
                                    Rectangle { visible: typeof server !== "undefined" && server !== null && String(server).length > 0; width: sv.width + 12; height: 16; radius: 8; color: Qt.rgba(1, 1, 1, 0.06); anchors.verticalCenter: parent.verticalCenter
                                        Text { id: sv; anchors.centerIn: parent; text: server || ""; color: "#8a7a56"; font.pixelSize: 9; font.family: "Menlo" } }
                                }
                                Text {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    text: root.relTime(ts) + "  ·  " + root.fmtWhen(ts)
                                    color: "#8a7a56"; font.pixelSize: 11
                                }
                            }
                            Text { width: parent.width; text: reason; color: "#F2E8D0"; font.pixelSize: 12; elide: Text.ElideRight }
                            Text { text: "by " + staffName; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11 }
                        }
                    }
                }
            }

            // ---- clear punishment history (owner/manager only — wipes the record log,
            //      leaves active punishments alone; broker enforces via historyManagerGuard) ----
            Column {
                width: parent.width; spacing: 6
                visible: root.canManageHistory && PlayerHistoryModel.count > 0
                SButton { visible: !root.clearHistoryConfirm; text: "Clear player history"; variant: "danger"; compact: true; onClicked: root.clearHistoryConfirm = true }
                Column {
                    visible: root.clearHistoryConfirm
                    width: parent.width; spacing: 6
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Delete ALL punishment history for " + root.name + "? Removes the record log permanently — this cannot be undone. Active punishments are unaffected."
                        color: "#FFE082"; font.pixelSize: 12
                    }
                    Row {
                        spacing: 8
                        SButton { text: "Delete history"; variant: "danger"; compact: true; onClicked: root.sendClearHistory() }
                        SButton { text: "Cancel"; variant: "ghost"; compact: true; onClicked: root.clearHistoryConfirm = false }
                    }
                }
            }

            // ---- reports filed against this player ----
            Row {
                spacing: 8
                Text { text: "Reports"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    visible: root.reports.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: openTxt.width + 16; height: 18; radius: 9
                    readonly property int openCount: { var c = 0; for (var i = 0; i < root.reports.length; i++) if (!root.reports[i].resolved) c++; return c }
                    color: openCount > 0 ? Qt.rgba(0.94, 0.66, 0.35, 0.16) : Qt.rgba(0.35, 0.82, 0.48, 0.16)
                    Text { id: openTxt; anchors.centerIn: parent; text: parent.openCount > 0 ? parent.openCount + " open" : "resolved"; color: parent.openCount > 0 ? "#f0a85a" : "#5ad17a"; font.pixelSize: 10; font.bold: true }
                }
            }
            Text { visible: root.reports.length === 0; text: "No reports on record."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13 }
            Column {
                width: parent.width; spacing: 6
                Repeater {
                    model: root.reports
                    delegate: Rectangle {
                        id: repCard
                        required property var modelData
                        readonly property bool resolved: modelData.resolved === true
                        width: detailCol.width; height: rc.height + 18; radius: 11
                        color: "#16110a"; border.color: resolved ? "#241c12" : "#3a2f14"; border.width: 1
                        opacity: resolved ? 0.6 : 1.0
                        Column {
                            id: rc
                            anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: rResolve.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Row { spacing: 8
                                Text { text: (modelData.category ? ("" + modelData.category).toUpperCase() : "REPORT"); color: "#FFB81C"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.5; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "by " + (modelData.reporterName ? modelData.reporterName : "unknown"); color: "#FFE082"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: root.relTime(root.reportTs(modelData.timestamp)); color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { visible: repCard.resolved; anchors.verticalCenter: parent.verticalCenter; width: rvTxt.width + 12; height: 15; radius: 7; color: Qt.rgba(0.35, 0.82, 0.48, 0.16)
                                    Text { id: rvTxt; anchors.centerIn: parent; text: "resolved"; color: "#5ad17a"; font.pixelSize: 9; font.bold: true } }
                            }
                            Text { width: parent.width; text: modelData.reason ? modelData.reason : ""; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; wrapMode: Text.WordWrap; visible: text.length > 0 }
                        }
                        SButton {
                            id: rResolve
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            visible: !repCard.resolved
                            text: "Resolve"; variant: "secondary"; compact: true
                            onClicked: root.resolveReport(modelData.id)
                        }
                    }
                }
            }

            // ---- notes ----
            Text { text: "Notes"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
            Rectangle {
                width: parent.width; height: 34; radius: 9; color: Qt.rgba(1, 1, 1, 0.06)
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 6
                    TextInput {
                        id: noteIn; width: parent.width - 64; height: parent.height; verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 12; clip: true
                        onAccepted: { root.addNote(text); text = "" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "add a staff note…"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 12; visible: noteIn.text.length === 0 }
                    }
                    SButton { anchors.verticalCenter: parent.verticalCenter; text: "Add"; variant: "primary"; onClicked: { root.addNote(noteIn.text); noteIn.text = "" } }
                }
            }
            Column {
                width: parent.width; spacing: 6
                Repeater {
                    model: root.notes
                    delegate: Rectangle {
                        required property var modelData
                        width: detailCol.width; height: nc.height + 18; radius: 11; color: Qt.rgba(1, 1, 1, 0.04)
                        Column {
                            id: nc
                            anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: noteX.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Row { spacing: 8
                                Text { text: modelData.staffName ? modelData.staffName : "staff"; color: "#FFE082"; font.pixelSize: 12; font.bold: true }
                                Text { text: root.relTime(modelData.timestamp); color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { width: parent.width; text: modelData.note ? modelData.note : ""; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; wrapMode: Text.WordWrap }
                        }
                        Image {
                            id: noteX
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 12
                            source: "qrc:/jarton/staff/icons/ui/x-cream.svg"
                            width: 11; height: 11; sourceSize: Qt.size(22, 22)
                            opacity: xHover.containsMouse ? 0.9 : 0.35
                            MouseArea { id: xHover; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeNote(modelData.id) }
                        }
                    }
                }
            }
        }
    }
}
