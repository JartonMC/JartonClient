import QtQuick
import Jarton

// Player management — one screen per player, matching the app: status, punish actions,
// offence ladder, history, and notes all together (no separate "punish" button). The
// landing list shows who's online; typing searches everyone who has ever joined.
Item {
    id: view

    property string selUuid: ""
    property string selName: ""

    // online roster (landing list)
    property var online: []
    property int reqOnline: -1

    // punish state (live-bridge routed, mirrors the app)
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

    property int reqServers: -1
    property int reqGuide: -1
    property int reqCounts: -1
    property int reqNotes: -1
    property int reqNoteAdd: -1

    readonly property var rawActions: [
        { label: "Ban",        action: "ban",       node: "ban",      color: "#ff6b6b", temp: false },
        { label: "Temp-ban",   action: "temp-ban",  node: "tempban",  color: "#ff6b6b", temp: true  },
        { label: "Mute",       action: "mute",      node: "mute",     color: "#f0a85a", temp: false },
        { label: "Temp-mute",  action: "temp-mute", node: "tempmute", color: "#f0a85a", temp: true  },
        { label: "Kick",       action: "kick",      node: "kick",     color: "#ffd24a", temp: false },
        { label: "Warn",       action: "warn",      node: "warn",     color: "#ffd24a", temp: false },
        { label: "Unban",      action: "unban",     node: "unban",    color: "#5ad17a", temp: false, un: true },
        { label: "Unmute",     action: "unmute",    node: "unmute",   color: "#5ad17a", temp: false, un: true }
    ]

    function relTime(ms) {
        if (!ms || ms <= 0) return ""
        var diff = Date.now() - Number(ms)
        var d = Math.floor(diff / 86400000); if (d > 0) return d + "d ago"
        var h = Math.floor(diff / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(diff / 60000)) + "m ago"
    }

    // ---- punish helpers (mirror the app's guard-action flow) ----
    function openPlayer(uuid, name) {
        selUuid = uuid; selName = name
        PlayerHistoryModel.load(uuid, name)
        route = ""; sections = []; counts = ({}); selected = []; notes = []; banner = ""; offencesOpen = false
        pendingAction = ""
        reqServers = ProctorApi.send("GET", "/proctor/servers")
        loadGuide(); loadNotes()
    }
    function loadGuide() { reqGuide = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "guide", args: {} })) }
    function loadNotes() { reqNotes = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "notes", args: { target: selUuid } })) }
    function addNote(text) {
        if (!text || !text.length) return
        reqNoteAdd = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "note-add", args: { target: selUuid, text: text } }))
        banner = "Note added"
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
    function visibleActions() { var out = []; for (var i = 0; i < rawActions.length; i++) if (canDo(rawActions[i].node)) out.push(rawActions[i]); return out }
    function toggle(id) { var s = selected.slice(); var i = s.indexOf(id); if (i === -1) s.push(id); else s.splice(i, 1); selected = s }
    function sendRaw(reason, durationMs) {
        var args = { target: selUuid, targetName: selName, action: pendingAction, reason: reason }
        if (durationMs > 0) args.durationMs = durationMs
        ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "punish", args: args }))
        banner = pendingAction + " sent for " + selName
        pendingAction = ""
    }
    function sendUn(action) {
        ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "unpunish", args: { target: selUuid, targetName: selName, action: action } }))
        banner = action + " sent"
    }
    function applyOffenses() {
        if (!selected.length) return
        ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "punish-offense", args: { target: selUuid, categories: selected } }))
        banner = "Applied " + selected.length + " offence" + (selected.length === 1 ? "" : "s") + " to " + selName
        selected = []
    }
    function pressAction(a) {
        if (a.un) { sendUn(a.action); return }
        if (a.action === "kick" || a.action === "warn") { pendingAction = a.action; pendingNode = a.node; pendingTemp = false }
        else { pendingAction = a.action; pendingNode = a.node; pendingTemp = a.temp }
    }

    Component.onCompleted: loadOnline()
    function loadOnline() { reqOnline = ProctorApi.send("GET", "/proctor/online") }

    Timer { id: debounce; interval: 280; onTriggered: PlayerSearchModel.search(searchInput.text) }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === view.reqOnline) {
                if (ok) { try {
                    var arr = (JSON.parse(body).online || [])
                    arr.sort(function (a, b) { return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()) })
                    view.online = arr
                } catch (e) { view.online = [] } }
                return
            }
            if (id === view.reqServers) {
                if (ok) { try { var s = JSON.parse(body).servers || []; if (s.length && !view.route.length) { view.route = s[0]; view.loadGuide(); view.loadNotes() } } catch (e) {} }
                return
            }
            if (id === view.reqGuide) {
                if (ok) { try { view.sections = (JSON.parse(body).data || {}).sections || [] } catch (e) { view.sections = [] }
                    view.reqCounts = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: view.route, type: "offense-counts", args: { target: view.selUuid, categories: view.allIds() } })) }
                return
            }
            if (id === view.reqCounts) { if (ok) { try { view.counts = (JSON.parse(body).data || {}).counts || {} } catch (e) { view.counts = {} } } return }
            if (id === view.reqNotes) { if (ok) { try { view.notes = (JSON.parse(body).data) || [] } catch (e) { view.notes = [] } } return }
            if (id === view.reqNoteAdd) { if (ok) view.loadNotes(); else view.banner = "Note failed (" + status + ")."; return }
            if (!ok && status >= 400) view.banner = "Action failed (" + status + ")."
            else if (ok) PlayerHistoryModel.load(view.selUuid, view.selName)
        }
    }

    // =========================== LANDING: search + online ===========================
    Item {
        anchors.fill: parent; anchors.margins: 4
        visible: view.selUuid === ""

        Column {
            anchors.fill: parent; spacing: 12

            Rectangle {
                width: parent.width; height: 44; radius: 11
                color: Qt.rgba(1, 1, 1, 0.07)
                border.color: searchInput.activeFocus ? "#FFB833" : "transparent"; border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 18 }
                TextInput {
                    id: searchInput
                    anchors.fill: parent; anchors.leftMargin: 40; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 15; clip: true
                    onTextChanged: debounce.restart()
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Search any player who has joined…"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 15; visible: searchInput.text.length === 0 }
                }
            }

            // section label
            Text {
                text: searchInput.text.length > 0 ? "RESULTS" : ("ONLINE · " + view.online.length)
                color: "#FFB833"; font.pixelSize: 11; font.bold: true
            }

            // online list (no query)
            ListView {
                width: parent.width; height: parent.height - 90; clip: true; spacing: 6
                visible: searchInput.text.length === 0
                model: view.online
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width; height: 50; radius: 12
                    color: oHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Avatar { id: oh; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; size: 30; uuid: modelData.uuid }
                    Text { anchors.left: oh.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: "#FFFFFF"; font.pixelSize: 15; font.bold: true }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Rectangle {
                            visible: !!modelData.server; anchors.verticalCenter: parent.verticalCenter
                            width: sv.width + 16; height: 20; radius: 10; color: Qt.rgba(1, 0.72, 0.2, 0.14)
                            Text { id: sv; anchors.centerIn: parent; text: modelData.server ? modelData.server : ""; color: "#FFB833"; font.pixelSize: 11; font.bold: true }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "›"; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 18 }
                    }
                    MouseArea { id: oHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.openPlayer(modelData.uuid, modelData.name) }
                }
                Text { anchors.centerIn: parent; visible: view.online.length === 0; text: "Nobody is online right now."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
            }

            // search results (query)
            ListView {
                width: parent.width; height: parent.height - 90; clip: true; spacing: 6
                visible: searchInput.text.length > 0
                model: PlayerSearchModel
                delegate: Rectangle {
                    width: ListView.view.width; height: 50; radius: 12
                    color: rHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Avatar { id: rh; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; size: 30; uuid: model.uuid }
                    Text { anchors.left: rh.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: model.name; color: "#FFFFFF"; font.pixelSize: 15; font.bold: true }
                    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 18 }
                    MouseArea { id: rHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.openPlayer(model.uuid, model.name) }
                }
                Text { anchors.centerIn: parent; visible: !PlayerSearchModel.loading && PlayerSearchModel.count === 0; text: "No player found."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
            }
        }
    }

    // =========================== PLAYER DETAIL ===========================
    Flickable {
        anchors.fill: parent; anchors.margins: 4
        visible: view.selUuid !== ""
        contentWidth: width; contentHeight: detailCol.height + 16; clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: detailCol
            width: parent.width; spacing: 14

            // header
            Item {
                width: parent.width; height: 44
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    SButton { anchors.verticalCenter: parent.verticalCenter; text: "Back"; glyph: "‹"; variant: "ghost"; onClicked: { view.selUuid = ""; view.loadOnline() } }
                    Avatar { anchors.verticalCenter: parent.verticalCenter; size: 40; uuid: view.selUuid }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 3
                        Text { text: view.selName; color: "#FFFFFF"; font.pixelSize: 19; font.bold: true }
                        Row {
                            spacing: 6
                            Rectangle {
                                visible: PlayerHistoryModel.banned; width: bb.width + 14; height: 18; radius: 9; color: Qt.rgba(1, 0.42, 0.42, 0.16)
                                Text { id: bb; anchors.centerIn: parent; text: "Banned"; color: "#ff6b6b"; font.pixelSize: 10; font.bold: true }
                            }
                            Rectangle {
                                visible: PlayerHistoryModel.muted; width: mb.width + 14; height: 18; radius: 9; color: Qt.rgba(0.94, 0.66, 0.35, 0.16)
                                Text { id: mb; anchors.centerIn: parent; text: "Muted"; color: "#f0a85a"; font.pixelSize: 10; font.bold: true }
                            }
                            Rectangle {
                                visible: !PlayerHistoryModel.banned && !PlayerHistoryModel.muted; width: cb.width + 14; height: 18; radius: 9; color: Qt.rgba(0.35, 0.82, 0.48, 0.16)
                                Text { id: cb; anchors.centerIn: parent; text: "Clean"; color: "#5ad17a"; font.pixelSize: 10; font.bold: true }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 30; radius: 9; visible: view.banner.length > 0
                color: Qt.rgba(0.35, 0.82, 0.48, 0.14)
                Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: view.banner; color: "#9fe0ad"; font.pixelSize: 12 }
            }

            // ---- action buttons grid (2-col, bigger, colour-coded) ----
            Grid {
                width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: view.visibleActions()
                    delegate: Rectangle {
                        required property var modelData
                        width: (detailCol.width - 8) / 2; height: 52; radius: 12
                        color: aHover.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: modelData.label; color: modelData.color; font.pixelSize: 15; font.bold: true }
                        MouseArea { id: aHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.pressAction(modelData) }
                    }
                }
            }

            // ---- raw compose form ----
            Rectangle {
                width: parent.width; height: 96; radius: 12; visible: view.pendingAction.length > 0
                color: Qt.rgba(1, 1, 1, 0.05); border.color: "#FFB833"; border.width: 1
                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "Confirm " + view.pendingAction; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
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
                            visible: view.pendingTemp; width: 96; height: 30; radius: 8; color: Qt.rgba(1, 1, 1, 0.06)
                            TextInput {
                                id: durIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 13; clip: true; validator: IntValidator { bottom: 0 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "minutes"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 12; visible: durIn.text.length === 0 }
                            }
                        }
                        SButton { text: "Apply"; variant: "primary"; onClicked: view.sendRaw(reasonIn.text, view.pendingTemp ? (parseInt(durIn.text || "0") * 60000) : 0) }
                        SButton { text: "Cancel"; variant: "ghost"; onClicked: view.pendingAction = "" }
                    }
                }
            }

            // ---- offences (collapsed by default) ----
            Column {
                width: parent.width; spacing: 8
                Rectangle {
                    width: parent.width; height: 42; radius: 11
                    color: ofHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "Offences"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Rectangle {
                            visible: view.selected.length > 0; anchors.verticalCenter: parent.verticalCenter
                            width: selTxt.width + 14; height: 18; radius: 9; color: Qt.rgba(1, 0.72, 0.2, 0.16)
                            Text { id: selTxt; anchors.centerIn: parent; text: view.selected.length + " selected"; color: "#FFB833"; font.pixelSize: 10; font.bold: true }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: view.offencesOpen ? "▾" : "▸"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 13 }
                    }
                    MouseArea { id: ofHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.offencesOpen = !view.offencesOpen }
                }
                // expanded list
                Column {
                    width: parent.width; spacing: 6; visible: view.offencesOpen
                    Repeater {
                        model: view.offencesOpen ? view.flatOffences() : []
                        delegate: Rectangle {
                            required property var modelData
                            width: detailCol.width; height: 48; radius: 10
                            color: view.selected.indexOf(modelData.id) !== -1 ? Qt.rgba(1, 0.72, 0.2, 0.12) : (oa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: view.selected.indexOf(modelData.id) !== -1 ? "#FFB833" : "transparent"; border.width: 1
                            Column {
                                anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: chk.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { text: modelData.display; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
                                Text { text: view.rungLabel(modelData); color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11; visible: text.length > 0 }
                            }
                            Text { id: chk; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: view.selected.indexOf(modelData.id) !== -1 ? "✓" : ""; color: "#FFB833"; font.pixelSize: 16; font.bold: true }
                            MouseArea { id: oa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.toggle(modelData.id) }
                        }
                    }
                    Text { visible: view.sections.length === 0; text: "Loading offences…"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13 }
                    SButton { visible: view.selected.length > 0; text: "Apply " + view.selected.length + " offence" + (view.selected.length === 1 ? "" : "s"); variant: "primary"; onClicked: view.applyOffenses() }
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
                        width: detailCol.width; height: hc.height + 20; radius: 11; color: Qt.rgba(1, 1, 1, 0.04)
                        Column {
                            id: hc
                            anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Row {
                                spacing: 6
                                Text { text: action.toUpperCase(); color: "#FFB833"; font.pixelSize: 12; font.bold: true }
                                Rectangle { visible: active; width: av.width + 12; height: 16; radius: 8; color: Qt.rgba(1, 0.42, 0.42, 0.16); anchors.verticalCenter: parent.verticalCenter
                                    Text { id: av; anchors.centerIn: parent; text: "active"; color: "#ff6b6b"; font.pixelSize: 9; font.bold: true } }
                                Text { text: view.relTime(timestamp); color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { width: parent.width; text: reason; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; elide: Text.ElideRight }
                            Text { text: "by " + staffName; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11 }
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
                        onAccepted: { view.addNote(text); text = "" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "add a staff note…"; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 12; visible: noteIn.text.length === 0 }
                    }
                    SButton { anchors.verticalCenter: parent.verticalCenter; text: "Add"; variant: "primary"; onClicked: { view.addNote(noteIn.text); noteIn.text = "" } }
                }
            }
            Column {
                width: parent.width; spacing: 6
                Repeater {
                    model: view.notes
                    delegate: Rectangle {
                        required property var modelData
                        width: detailCol.width; height: nc.height + 18; radius: 11; color: Qt.rgba(1, 1, 1, 0.04)
                        Column {
                            id: nc
                            anchors.left: parent.left; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Row { spacing: 8
                                Text { text: modelData.staffName ? modelData.staffName : "staff"; color: "#FFE082"; font.pixelSize: 12; font.bold: true }
                                Text { text: view.relTime(modelData.timestamp); color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { width: parent.width; text: modelData.note ? modelData.note : ""; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
        }
    }
}
