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

    onVisibleChanged: if (visible && loadedServer !== serverId && serverId.length) { loadedServer = serverId; load() }

    function load() {
        loading = true; error = ""
        reqList = StaffApi.send("GET", "/servers/" + serverId + "/users")
        if (groups.length === 0) reqPerms = StaffApi.send("GET", "/servers/permissions")
    }
    function act(method, path, body) { root.pending[StaffApi.send(method, path, body)] = true }
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
        mode = "invite"; editUuid = ""; selected = ({}); emailIn.text = ""; emailIn.forceActiveFocus()
    }
    function openEdit(u) {
        mode = "edit"; editUuid = u.uuid
        var s = {}; var perms = u.permissions || []
        for (var i = 0; i < perms.length; i++) s[perms[i]] = true
        selected = s
    }
    function submit() {
        var keys = selectedList()
        if (mode === "invite") {
            if (emailIn.text.length === 0 || keys.length === 0) return
            act("POST", "/servers/" + serverId + "/users", JSON.stringify({ email: emailIn.text, permissions: keys }))
        } else if (mode === "edit") {
            if (keys.length === 0) return
            act("POST", "/servers/" + serverId + "/users/" + editUuid, JSON.stringify({ permissions: keys }))
        }
        mode = ""
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
            height: visible ? Math.min(480, Math.round(root.height * 0.62)) : 0
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
                        Column {
                            id: permCol; width: parent.width; spacing: 12
                            Repeater {
                                model: root.groups
                                Column {
                                    width: permCol.width; spacing: 6
                                    Item {
                                        width: parent.width; height: 18
                                        Text {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            text: (modelData.group || "").toUpperCase()
                                            color: "#FFB81C"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5
                                        }
                                        Rectangle {
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: allTxt.width + 16; height: 17; radius: 8
                                            readonly property bool on: root.groupOn(modelData.keys)
                                            color: on ? "#3a2f14" : "transparent"
                                            border.color: on ? "#FFB81C" : "#2a2114"; border.width: 1
                                            Text { id: allTxt; anchors.centerIn: parent; text: "all"; color: parent.on ? "#FFE082" : "#6b5d3f"; font.pixelSize: 9; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleGroup(modelData.keys) }
                                        }
                                    }
                                    Flow {
                                        width: parent.width; spacing: 6
                                        Repeater {
                                            model: modelData.keys
                                            Rectangle {
                                                height: 26; radius: 8
                                                width: kTxt.width + 24
                                                color: root.isOn(modelData.key) ? "#3a2f14" : (chipHover.containsMouse ? "#1a140c" : "#0f0a06")
                                                border.color: root.isOn(modelData.key) ? "#FFB81C" : (chipHover.containsMouse ? "#4a3c1e" : "#2a2114"); border.width: 1
                                                Text { id: kTxt; anchors.centerIn: parent; text: modelData.key; color: root.isOn(modelData.key) ? "#FFE082" : "#8a7a56"; font.pixelSize: 11 }
                                                MouseArea { id: chipHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(modelData.key) }
                                            }
                                        }
                                    }
                                }
                            }
                            Item { width: 1; height: 2 }  // keep the last chip row clear of the fade
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
                        text: root.mode === "invite" ? "Send invite" : "Save"; variant: "primary"
                        enabled: root.selCount > 0 && (root.mode !== "invite" || emailIn.text.length > 0)
                        onClicked: root.submit()
                    }
                    SButton { text: "Cancel"; variant: "ghost"; onClicked: root.mode = "" }
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
