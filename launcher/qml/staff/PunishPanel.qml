import QtQuick
import Jarton

// Punish a player: rank-gated raw actions (ban/mute/kick/warn + un-) and the offence
// ladder (pick offences -> server computes + applies the stacked punishment). Offline
// lookups route the command through a live bridge server (/proctor/servers).
Item {
    id: panel
    property string uuid: ""
    property string name: ""
    signal close()

    property string route: ""
    property var sections: []
    property var counts: ({})
    property var selected: []
    property string banner: ""
    property bool banding: false

    // pending raw action awaiting reason/duration
    property string pendingAction: ""
    property string pendingNode: ""
    property bool pendingTemp: false

    property int reqServers: -1
    property int reqGuide: -1
    property int reqCounts: -1
    property int reqNotes: -1
    property int reqNoteAdd: -1
    property var notes: []
    property bool showNotes: false

    Component.onCompleted: { reqServers = ProctorApi.send("GET", "/proctor/servers"); loadGuide(); loadNotes() }

    function loadGuide() {
        reqGuide = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "guide", args: {} }))
    }
    function loadNotes() {
        reqNotes = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "notes", args: { target: uuid } }))
    }
    function addNote(text) {
        if (!text || !text.length) return
        reqNoteAdd = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "note-add", args: { target: uuid, text: text } }))
        banner = "Note added"
    }
    function relNote(ms) {
        if (!ms || ms <= 0) return ""
        var d = Date.now() - Number(ms)
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
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
    function allowed() {
        if (ProctorClient.admin) return null
        var helper = ["warn"], jrmod = helper.concat(["kick", "mute", "tempmute"]), mod = jrmod.concat(["tempban"]),
            srmod = mod.concat(["ban"]), jradmin = srmod.concat(["banip", "tempbanip"])
        switch ((ProctorClient.rank || "").toLowerCase()) {
        case "helper": return helper; case "jrmod": return jrmod; case "mod": return mod
        case "srmod": return srmod; case "jradmin": return jradmin; default: return null
        }
    }
    function canDo(node) { var a = allowed(); return a === null || a.indexOf(node) !== -1 }
    function toggle(id) {
        var s = selected.slice(); var i = s.indexOf(id)
        if (i === -1) s.push(id); else s.splice(i, 1)
        selected = s
    }

    function sendRaw(reason, durationMs) {
        var args = { target: uuid, targetName: name, action: pendingAction, reason: reason }
        if (durationMs > 0) args.durationMs = durationMs
        ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "punish", args: args }))
        banner = pendingAction + " sent for " + name
        pendingAction = ""
    }
    function sendUn(action) {
        ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "unpunish", args: { target: uuid, targetName: name, action: action } }))
        banner = action + " sent"
    }
    function applyOffenses() {
        if (!selected.length) return
        ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: route, type: "punish-offense", args: { target: uuid, categories: selected } }))
        banner = "Applied " + selected.length + " offence" + (selected.length === 1 ? "" : "s") + " to " + name
        selected = []
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === panel.reqServers) {
                if (ok) { try { var s = JSON.parse(body).servers || []; if (s.length && !panel.route.length) { panel.route = s[0]; panel.loadGuide(); panel.loadNotes() } } catch (e) {} }
                return
            }
            if (id === panel.reqGuide) {
                if (ok) { try { panel.sections = (JSON.parse(body).data || {}).sections || [] } catch (e) { panel.sections = [] }
                    panel.reqCounts = ProctorApi.send("POST", "/proctor/guard/actions", JSON.stringify({ server: panel.route, type: "offense-counts", args: { target: panel.uuid, categories: panel.allIds() } })) }
                return
            }
            if (id === panel.reqCounts) {
                if (ok) { try { panel.counts = (JSON.parse(body).data || {}).counts || {} } catch (e) { panel.counts = {} } }
                return
            }
            if (id === panel.reqNotes) {
                if (ok) { try { panel.notes = (JSON.parse(body).data) || [] } catch (e) { panel.notes = [] } }
                return
            }
            if (id === panel.reqNoteAdd) {
                if (ok) panel.loadNotes(); else panel.banner = "Note failed (" + status + ")."
                return
            }
            // a punish/un/offense action came back
            if (!ok) panel.banner = "Action failed (" + status + ")."
        }
    }

    Rectangle { anchors.fill: parent; color: "#0f0a06" }  // opaque cover over the detail

    Column {
        anchors.fill: parent; spacing: 12

        Row {
            width: parent.width; spacing: 10
            SButton { text: "Back"; glyph: "‹"; variant: "ghost"; onClicked: panel.close() }
            Image {
                anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; smooth: false; fillMode: Image.PreserveAspectFit
                source: "https://crafatar.com/avatars/" + panel.uuid + "?size=64&overlay"
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Punish " + panel.name; color: "#F2E8D0"; font.pixelSize: 17; font.bold: true }
        }

        Rectangle {
            width: parent.width; height: 30; radius: 8; visible: panel.banner.length > 0
            color: "#23311f"
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: panel.banner; color: "#9fe0ad"; font.pixelSize: 12 }
        }

        // ---- raw quick actions (rank-gated) ----
        Flow {
            width: parent.width; spacing: 8
            SButton { visible: panel.canDo("ban"); text: "Ban"; variant: "danger"; onClicked: { panel.pendingAction = "ban"; panel.pendingNode = "ban"; panel.pendingTemp = false } }
            SButton { visible: panel.canDo("tempban"); text: "Temp-ban"; variant: "danger"; onClicked: { panel.pendingAction = "temp-ban"; panel.pendingNode = "tempban"; panel.pendingTemp = true } }
            SButton { visible: panel.canDo("mute"); text: "Mute"; variant: "secondary"; onClicked: { panel.pendingAction = "mute"; panel.pendingNode = "mute"; panel.pendingTemp = false } }
            SButton { visible: panel.canDo("tempmute"); text: "Temp-mute"; variant: "secondary"; onClicked: { panel.pendingAction = "temp-mute"; panel.pendingNode = "tempmute"; panel.pendingTemp = true } }
            SButton { visible: panel.canDo("kick"); text: "Kick"; variant: "secondary"; onClicked: { panel.pendingAction = "kick"; panel.pendingNode = "kick"; panel.pendingTemp = false } }
            SButton { visible: panel.canDo("warn"); text: "Warn"; variant: "secondary"; onClicked: { panel.pendingAction = "warn"; panel.pendingNode = "warn"; panel.pendingTemp = false } }
            SButton { text: "Unban"; variant: "ghost"; onClicked: panel.sendUn("unban") }
            SButton { text: "Unmute"; variant: "ghost"; onClicked: panel.sendUn("unmute") }
        }

        // ---- raw compose form (shown when a raw action is pending) ----
        Rectangle {
            width: parent.width; height: 92; radius: 11; visible: panel.pendingAction.length > 0
            color: "#15100a"; border.color: "#2a2114"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Text { text: "Confirm " + panel.pendingAction; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                Rectangle {
                    width: parent.width; height: 30; radius: 8; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                    TextInput {
                        id: reasonIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 13; clip: true
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Reason…"; color: "#6b5d3f"; font.pixelSize: 13; visible: reasonIn.text.length === 0 }
                    }
                }
                Row {
                    spacing: 8
                    Rectangle {
                        visible: panel.pendingTemp; width: 90; height: 30; radius: 8; color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
                        TextInput {
                            id: durIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 13; clip: true
                            validator: IntValidator { bottom: 0 }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "minutes"; color: "#6b5d3f"; font.pixelSize: 12; visible: durIn.text.length === 0 }
                        }
                    }
                    SButton {
                        text: "Apply"; variant: "primary"
                        onClicked: panel.sendRaw(reasonIn.text, panel.pendingTemp ? (parseInt(durIn.text || "0") * 60000) : 0)
                    }
                    SButton { text: "Cancel"; variant: "ghost"; onClicked: panel.pendingAction = "" }
                }
            }
        }

        // ---- offence ladder / notes ----
        Item {
            width: parent.width; height: 30
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: panel.showNotes ? "Notes" : "Offences"; color: "#F2E8D0"; font.pixelSize: 15; font.bold: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton {
                    visible: !panel.showNotes && panel.selected.length > 0; text: "Apply " + panel.selected.length; variant: "primary"; onClicked: panel.applyOffenses()
                }
                SButton { text: panel.showNotes ? "Offences" : "Notes (" + panel.notes.length + ")"; variant: "secondary"; onClicked: panel.showNotes = !panel.showNotes }
            }
        }

        // notes composer (shown in notes mode)
        Rectangle {
            width: parent.width; height: 34; radius: 9; visible: panel.showNotes
            color: "#0f0a06"; border.color: "#2a2114"; border.width: 1
            Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 6
                TextInput {
                    id: noteIn; width: parent.width - 70; height: parent.height
                    verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 12; clip: true
                    onAccepted: { panel.addNote(text); text = "" }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "add a staff note…"; color: "#6b5d3f"; font.pixelSize: 12; visible: noteIn.text.length === 0 }
                }
                SButton { anchors.verticalCenter: parent.verticalCenter; text: "Add"; variant: "primary"; onClicked: { panel.addNote(noteIn.text); noteIn.text = "" } }
            }
        }

        ListView {
            width: parent.width; visible: panel.showNotes
            height: parent.height - (panel.pendingAction.length > 0 ? 296 : 204)
            clip: true; spacing: 5
            model: panel.notes
            delegate: Rectangle {
                width: ListView.view.width; height: nCol.height + 16; radius: 9; color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    id: nCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.staffName ? modelData.staffName : "staff"; color: "#FFE082"; font.pixelSize: 12; font.bold: true }
                        Text { text: panel.relNote(modelData.timestamp); color: "#6b5d3f"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { width: parent.width; text: modelData.note ? modelData.note : ""; color: "#cfc3a6"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                }
            }
            Text { anchors.centerIn: parent; visible: panel.notes.length === 0; text: "No notes on record."; color: "#6b5d3f"; font.pixelSize: 13 }
        }

        ListView {
            width: parent.width; visible: !panel.showNotes
            height: parent.height - (panel.pendingAction.length > 0 ? 250 : 158)
            clip: true; spacing: 5
            model: {
                var out = []
                for (var i = 0; i < panel.sections.length; i++) for (var j = 0; j < panel.sections[i].offenses.length; j++) out.push(panel.sections[i].offenses[j])
                return out
            }
            delegate: Rectangle {
                width: ListView.view.width; height: 46; radius: 9
                color: panel.selected.indexOf(modelData.id) !== -1 ? "#2a2114" : (oa.containsMouse ? "#221a0f" : "#16110a")
                border.color: panel.selected.indexOf(modelData.id) !== -1 ? "#8B6F2A" : "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: modelData.display; color: "#F2E8D0"; font.pixelSize: 13; font.bold: true }
                    Text {
                        text: { var r = panel.rung(modelData); return r ? ("next: " + r.label) : "" }
                        color: "#8a7a56"; font.pixelSize: 11; visible: text.length > 0
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: panel.selected.indexOf(modelData.id) !== -1 ? "✓" : ""; color: "#FFB81C"; font.pixelSize: 16; font.bold: true
                }
                MouseArea { id: oa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.toggle(modelData.id) }
            }
            Text { anchors.centerIn: parent; visible: panel.sections.length === 0; text: "Loading offences…"; color: "#6b5d3f"; font.pixelSize: 13 }
        }
    }
}
