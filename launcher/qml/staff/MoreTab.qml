import QtQuick
import Jarton

// Staff "More": profile, per-staff notification toggles (the same set the Companion edits,
// PATCH /proctor/me/notifications), a test push, and sign-out. Read state from /proctor/me;
// each toggle PATCHes one field and the response echoes the full staff row back into `staff`.
Item {
    id: root
    property var staff: ({})
    property bool loaded: false
    property int reqMe: -1
    property var pending: ({})       // proctor write ids
    property var pendingPush: ({})   // cap-API test-push ids
    property string banner: ""

    onVisibleChanged: if (visible && !loaded) { loaded = true; load() }

    function load() { reqMe = ProctorApi.send("GET", "/proctor/me") }
    function on(snake, camel) { var v = root.staff[snake]; if (v === undefined) v = root.staff[camel]; return v === 1 || v === true }
    function setNotif(key, value) {
        var body = {}; body[key] = value
        root.pending[ProctorApi.send("PATCH", "/proctor/me/notifications", JSON.stringify(body))] = true
    }
    function testPush() {
        root.banner = "Sending test push…"
        root.pendingPush[StaffApi.send("POST", "/notify/test", "{}")] = true
    }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqMe) {
                if (ok) { try { root.staff = JSON.parse(body).staff || {} } catch (e) { root.staff = {} } }
                return
            }
            if (root.pending[id] !== undefined) {
                delete root.pending[id]
                if (ok) { try { root.staff = JSON.parse(body).staff || root.staff } catch (e) {} root.banner = "Saved." }
                else root.banner = "Couldn't save (" + status + ")."
            }
        }
    }
    Connections {
        target: StaffApi
        function onResponse(id, ok, status, body) {
            if (root.pendingPush[id] === undefined) return
            delete root.pendingPush[id]
            if (ok) { try { root.banner = "Test push sent to " + (JSON.parse(body).devices || 0) + " device(s)." } catch (e) { root.banner = "Test push sent." } }
            else root.banner = "Test push failed (" + status + ")."
        }
    }

    component NotifToggle: Item {
        id: t
        property string label: ""
        property bool value: false
        signal toggled(bool v)
        height: 42
        Text { anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter; text: t.label; color: "#F2E8D0"; font.pixelSize: 14 }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 24; radius: 12
            color: t.value ? "#FFB81C" : "#2a2114"
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                width: 18; height: 18; radius: 9; color: "#0f0a06"
                anchors.verticalCenter: parent.verticalCenter
                x: t.value ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.value) }
        }
    }

    Flickable {
        anchors.fill: parent; anchors.margins: 4
        contentHeight: col.height; clip: true
        Column {
            id: col
            width: parent.width; spacing: 16

            // profile
            Row {
                spacing: 12
                Rectangle {
                    width: 44; height: 44; radius: 22; color: "#1c1610"; border.color: "#332a14"; border.width: 1
                    Text { anchors.centerIn: parent; text: (ProctorClient.displayName.length ? ProctorClient.displayName.charAt(0) : "?").toUpperCase(); color: "#FFB81C"; font.pixelSize: 18; font.bold: true }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: ProctorClient.displayName.length ? ProctorClient.displayName : "Staff"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
                    Text { text: (ProctorClient.rank.length ? ProctorClient.rank : "JartonMC staff") + (ProctorClient.admin ? "  ·  admin" : ""); color: "#9a8a66"; font.pixelSize: 12 }
                }
            }

            Text { width: parent.width; visible: root.banner.length > 0; text: root.banner; color: "#FFE082"; font.pixelSize: 13 }

            // notifications
            Text { text: "NOTIFICATIONS"; color: "#8a7a56"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5 }
            Rectangle {
                width: parent.width; radius: 14; color: "#15100a"; border.color: "#241c12"; border.width: 1
                height: notifs.height + 20
                Column {
                    id: notifs
                    anchors.top: parent.top; anchors.topMargin: 10
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    NotifToggle { width: parent.width; label: "Tickets"; value: root.on("notify_tickets", "tickets"); onToggled: root.setNotif("tickets", v) }
                    NotifToggle { width: parent.width; label: "Applications"; value: root.on("notify_applications", "applications"); onToggled: root.setNotif("applications", v) }
                    NotifToggle { width: parent.width; label: "Reports"; value: root.on("notify_reports", "reports"); onToggled: root.setNotif("reports", v) }
                    NotifToggle { width: parent.width; label: "Punishments"; value: root.on("notify_punish", "punish"); onToggled: root.setNotif("punish", v) }
                    NotifToggle { width: parent.width; label: "Ban evaders"; value: root.on("notify_evader", "evader"); onToggled: root.setNotif("evader", v) }
                    NotifToggle { width: parent.width; label: "Mass disconnects"; value: root.on("notify_massdisc", "massDisc"); onToggled: root.setNotif("massDisc", v) }
                    NotifToggle { width: parent.width; label: "Server crashes"; value: root.on("notify_crash", "crash"); onToggled: root.setNotif("crash", v) }
                    NotifToggle { width: parent.width; label: "Server recovered"; value: root.on("notify_recovered", "recovered"); onToggled: root.setNotif("recovered", v) }
                    NotifToggle { width: parent.width; label: "Bridge offline"; value: root.on("notify_bridge", "bridge"); onToggled: root.setNotif("bridge", v) }
                    NotifToggle { width: parent.width; label: "Command abuse"; value: root.on("notify_abuse", "abuse"); onToggled: root.setNotif("abuse", v) }
                }
            }
            Text {
                width: parent.width
                text: "Swifty board notifications are managed inside the Swifty tab."
                color: "#6b5d3f"; font.pixelSize: 12; wrapMode: Text.WordWrap
            }

            // account
            Text { text: "ACCOUNT"; color: "#8a7a56"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5 }
            Row {
                spacing: 10
                SButton { visible: ProctorClient.admin; text: "Send test push"; glyph: "🔔"; variant: "secondary"; onClicked: root.testPush() }
                SButton { text: "Sign out"; variant: "danger"; onClicked: ProctorClient.signOut() }
            }
            Item { width: 1; height: 8 }  // bottom breathing room for the flick
        }
    }
}
