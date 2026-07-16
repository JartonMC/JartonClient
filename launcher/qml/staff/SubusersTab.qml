import QtQuick
import Jarton

// Pterodactyl subusers: list + invite + edit permissions + remove, over StaffApi.
// Permission keys come from /servers/permissions; create/edit post the selected key list.
Item {
    id: root
    property string serverId: ""
    property var users: []
    property var groups: []
    property bool loading: false
    property string error: ""
    property int reqList: -1
    property int reqPerms: -1
    property string loadedServer: ""
    property var pending: ({})   // ids of writes this tab issued; only these trigger a reload

    // editor state: mode "" (closed) | "invite" | "edit"
    property string mode: ""
    property string editUuid: ""
    property var selected: ({})   // key -> true
    property bool submitting: false
    property string editorError: ""

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/users")
        if (groups.length === 0) reqPerms = StaffApi.send("GET", "/servers/permissions")
    }
    function act(method, path, body) { root.pending[StaffApi.send(method, path, body)] = true }
    // "control.console" → "CONSOLE" for the row label; the group header carries the prefix
    function keyLabel(k) { var i = k.indexOf("."); return (i === -1 ? k : k.slice(i + 1)).toUpperCase() }
    function isOn(k) { return selected[k] === true }
    function toggle(k) {
        var s = selected; s[k] = !s[k]; selected = s
    }
    function groupOn(keys) {
        for (var i = 0; i < keys.length; i++) if (selected[keys[i].key] !== true) return false
        return keys.length > 0
    }
    function toggleGroup(keys) {
        var s = selected; var on = groupOn(keys)
        for (var i = 0; i < keys.length; i++) s[keys[i].key] = !on
        selected = s
    }
    readonly property int selCount: { var n = 0; for (var k in selected) if (selected[k] === true) n++; return n }
    function selectedList() {
        var out = []
        for (var k in selected) if (selected[k] === true) out.push(k)
        return out
    }
    function openInvite() {
        mode = "invite"; editUuid = ""; selected = ({}); editorError = ""; emailIn.text = ""; emailIn.forceActiveFocus()
    }
    function openEdit(u) {
        mode = "edit"; editUuid = u.uuid; editorError = ""
        var s = {}; var perms = u.permissions || []
        for (var i = 0; i < perms.length; i++) s[perms[i]] = true
        selected = s
    }
    // The editor stays open until the panel answers — a rejected invite used to
    // vanish silently (the write closed the form and the reload masked the 4xx).
    property int reqSubmit: -1
    function submit() {
        var keys = selectedList()
        if (keys.length === 0) return
        editorError = ""
        if (mode === "invite") {
            if (emailIn.text.length === 0) return
            submitting = true
            reqSubmit = StaffApi.send("POST", "/servers/" + serverId + "/users", JSON.stringify({ email: emailIn.text.trim(), permissions: keys }))
        } else if (mode === "edit") {
            submitting = true
            reqSubmit = StaffApi.send("POST", "/servers/" + serverId + "/users/" + editUuid, JSON.stringify({ permissions: keys }))
        }
    }

    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqPerms) {
                if (ok) { try { root.groups = JSON.parse(body).groups || [] } catch (e) { root.groups = [] } }
                return
            }
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.users = JSON.parse(body).users || [] } catch (e) { root.users = [] } }
                else root.error = "Couldn't load subusers."
                return
            }
            if (id === root.reqSubmit) {
                root.submitting = false; root.reqSubmit = -1
                if (ok) { root.mode = ""; root.load() }
                else {
                    var why = ""
                    try { why = JSON.parse(body).error || "" } catch (e) {}
                    root.editorError = why.length ? why : "The panel refused the request (" + status + ")."
                }
                return
            }
            // a write this tab issued completed — refresh the list (ignore foreign ids)
            if (root.pending[id] !== undefined) { delete root.pending[id]; root.load() }
        }
    }

    Column {
        anchors.fill: parent; spacing: 12
        Item {
            width: parent.width; height: 36
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Subusers"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton { text: "Invite subuser"; icon: "plus"; variant: "primary"; onClicked: root.openInvite() }
                SButton { text: root.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: root.load() }
            }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }

        // editor (invite / edit permissions)
        Rectangle {
            id: editor
            width: parent.width; radius: 11; visible: root.mode.length > 0
            height: visible ? Math.min(560, Math.round(root.height * 0.72)) : 0
            color: "#15100a"; border.color: "#FFB81C"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 14; spacing: 10
                Item {
                    width: parent.width; height: 20
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "invite" ? "Invite a new subuser" : "Edit permissions"
                        color: "#FFE082"; font.pixelSize: 14; font.bold: true
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: root.selCount + " selected"
                        color: root.selCount > 0 ? "#FFB81C" : "#6b5d3f"; font.pixelSize: 11; font.family: "Menlo"
                    }
                }
                Rectangle {
                    width: parent.width; height: 32; radius: 8; visible: root.mode === "invite"
                    color: "#0f0a06"; border.color: emailIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
                    TextInput { id: emailIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 13; clip: true
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "email address"; color: "#6b5d3f"; font.pixelSize: 13; visible: emailIn.text.length === 0 } }
                }
                Item {
                    width: parent.width
                    height: parent.height - 20 - (root.mode === "invite" ? 32 + 10 : 0) - 28 - 20
                    Flickable {
                        id: permFlick
                        anchors.fill: parent; anchors.rightMargin: 10
                        clip: true; contentHeight: permCol.height
                        boundsBehavior: Flickable.StopAtBounds
                        // pressDelay 0 + interactive-only-on-overflow so the Flickable
                        // never swallows a checkbox tap (the reason clicks weren't
                        // registering — a fitting form still armed the flick grab)
                        pressDelay: 0
                        interactive: contentHeight > height
                        flickableDirection: Flickable.VerticalFlick
                        Column {
                            id: permCol; width: parent.width; spacing: 10
                            Repeater {
                                model: root.groups
                                // one card per permission group, panel-style: title +
                                // group description, then a checkbox row per key with
                                // its plain-english description
                                Rectangle {
                                    width: permCol.width; radius: 10
                                    height: gCol.height + 24
                                    color: "#1a140c"; border.color: "#241c12"; border.width: 1
                                    Column {
                                        id: gCol
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                        anchors.margins: 12; spacing: 8
                                        Item {
                                            width: parent.width; height: 20
                                            Text {
                                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                                text: (modelData.group || "").charAt(0).toUpperCase() + (modelData.group || "").slice(1)
                                                color: "#FFB81C"; font.pixelSize: 14; font.bold: true
                                            }
                                            Rectangle {
                                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                                width: 18; height: 18; radius: 5
                                                readonly property bool on: root.groupOn(modelData.keys)
                                                color: on ? "#FFB81C" : "transparent"
                                                border.color: on ? "#FFB81C" : "#4a3c1e"; border.width: 1.5
                                                Text { anchors.centerIn: parent; text: "✓"; visible: parent.on; color: "#1a1a1a"; font.pixelSize: 12; font.bold: true }
                                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleGroup(modelData.keys) }
                                            }
                                        }
                                        Text {
                                            width: parent.width
                                            visible: (modelData.description || "").length > 0
                                            text: modelData.description || ""
                                            color: "#8a7a56"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                        }
                                        Repeater {
                                            model: modelData.keys
                                            Item {
                                                width: gCol.width
                                                height: rowCol.height + 8
                                                Rectangle {
                                                    anchors.fill: parent; radius: 7
                                                    color: rowMa.containsMouse ? "#221a0e" : "transparent"
                                                }
                                                Rectangle {
                                                    id: check
                                                    anchors.left: parent.left; anchors.leftMargin: 6; anchors.top: parent.top; anchors.topMargin: 6
                                                    width: 16; height: 16; radius: 4
                                                    readonly property bool on: root.isOn(modelData.key)
                                                    color: on ? "#FFB81C" : "transparent"
                                                    border.color: on ? "#FFB81C" : "#4a3c1e"; border.width: 1.5
                                                    Text { anchors.centerIn: parent; text: "✓"; visible: parent.on; color: "#1a1a1a"; font.pixelSize: 11; font.bold: true }
                                                }
                                                Column {
                                                    id: rowCol
                                                    anchors.left: check.right; anchors.leftMargin: 10
                                                    anchors.right: parent.right; anchors.rightMargin: 6
                                                    anchors.top: parent.top; anchors.topMargin: 4
                                                    spacing: 2
                                                    Text {
                                                        text: root.keyLabel(modelData.key)
                                                        color: check.on ? "#FFE082" : "#C9C9C9"; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6
                                                    }
                                                    Text {
                                                        width: parent.width
                                                        text: modelData.description || ""
                                                        color: "#8a7a56"; font.pixelSize: 11; wrapMode: Text.WordWrap
                                                    }
                                                }
                                                MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(modelData.key) }
                                            }
                                        }
                                    }
                                }
                            }
                            Item { width: 1; height: 2 }  // keep the last card clear of the fade
                        }
                    }
                    Rectangle {
                        // scroll thumb — Flickable alone gives no position cue in a box this dense
                        anchors.right: parent.right
                        width: 3; radius: 1.5
                        visible: permFlick.contentHeight > permFlick.height
                        height: Math.max(24, permFlick.height * permFlick.visibleArea.heightRatio)
                        y: permFlick.visibleArea.yPosition * permFlick.height
                        color: "#3a2f14"
                    }
                }
                Row {
                    spacing: 8
                    SButton {
                        text: root.submitting ? "Sending…" : (root.mode === "invite" ? "Send invite" : "Save"); variant: "primary"
                        enabled: !root.submitting && root.selCount > 0 && (root.mode !== "invite" || emailIn.text.length > 0)
                        onClicked: root.submit()
                    }
                    SButton { text: "Cancel"; variant: "ghost"; enabled: !root.submitting; onClicked: root.mode = "" }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.editorError.length > 0
                        text: root.editorError
                        color: "#e06c6c"; font.pixelSize: 12
                    }
                }
            }
        }

        ListView {
            width: parent.width; height: parent.height - (root.mode.length > 0 ? editor.height + 62 : 50); clip: true; spacing: 6
            model: root.users
            delegate: Rectangle {
                width: ListView.view.width; height: 56; radius: 11
                color: "#16110a"; border.color: "#241c12"; border.width: 1
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Row {
                        spacing: 8
                        Text { text: modelData.email; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                        Rectangle {
                            visible: modelData.twoFactorEnabled === true
                            width: tf.width + 14; height: 17; radius: 8; color: "#23311f"; anchors.verticalCenter: parent.verticalCenter
                            Text { id: tf; anchors.centerIn: parent; text: "2FA"; color: "#5ad17a"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    Text { text: (modelData.username && modelData.username.length ? modelData.username + "   ·   " : "") + (modelData.permissions ? modelData.permissions.length : 0) + " permissions"; color: "#8a7a56"; font.pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                    SButton { text: "Edit"; variant: "secondary"; compact: true; onClicked: root.openEdit(modelData) }
                    SButton { text: "Remove"; variant: "danger"; compact: true; onClicked: root.act("DELETE", "/servers/" + root.serverId + "/users/" + modelData.uuid) }
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.users.length === 0; text: "No subusers."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }
}
