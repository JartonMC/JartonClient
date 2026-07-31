import QtQuick
import Jarton

// Staff — the ownership home. A scrollable, searchable roster (add / edit / rank / flags /
// reset password / remove) on top, then drill-in buttons into the read-only oversight feeds
// (active staff, sessions, command logs, join/leave, audit, abuse) that used to live under a
// separate Admin tab. All routes are admin-gated. Drilling shows one AdminTab feed with a Back.
Item {
    id: root
    property var staff: []
    property var ranks: []
    property bool loading: false
    property string error: ""
    property string banner: ""
    property bool bannerError: false
    property int reqList: -1
    property int reqRanks: -1
    property var pendingWrites: []
    property bool loadedOnce: false
    property bool adding: false
    property int openId: -1
    property string searchText: ""
    property string drill: ""          // "" = roster home, else a feed id (active/sessions/…)

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load(); reqRanks = ProctorApi.send("GET", "/proctor/ranks") }

    // filtered roster (name / username / mc name), re-evaluates on search or roster change
    readonly property var shownStaff: {
        var q = searchText.toLowerCase()
        if (!q.length) return staff
        return staff.filter(function (s) {
            return (String(s.displayName || "")).toLowerCase().indexOf(q) >= 0
                || (String(s.username || "")).toLowerCase().indexOf(q) >= 0
                || (String(s.mcName || "")).toLowerCase().indexOf(q) >= 0
        })
    }
    // displayName / username / mcName → { name, uuid } so the feeds' faces resolve
    readonly property var staffMap: {
        var m = ({})
        for (var i = 0; i < staff.length; i++) {
            var s = staff[i]
            var e = { name: s.mcName || s.username || "", uuid: s.mcUuid || "" }
            if (s.displayName) m[s.displayName] = e
            if (s.username) m[s.username] = e
            if (s.mcName) m[s.mcName] = e
        }
        return m
    }

    readonly property var navItems: [
        { id: "sessions", label: "Sessions",     icon: "clock",     sub: "Login history" },
        { id: "commands", label: "Command logs", icon: "terminal",  sub: "Staff command trail" },
        { id: "presence", label: "Join / Leave", icon: "network",   sub: "Presence events" },
        { id: "audit",    label: "Audit log",    icon: "file-text", sub: "Everything that changed" },
        { id: "abuse",    label: "Abuse alerts", icon: "flag",      sub: "Flagged staff actions" }
    ]
    function navLabel(id) { for (var i = 0; i < navItems.length; i++) if (navItems[i].id === id) return navItems[i].label; return id }

    // success banners clear themselves; errors stay until the next action
    Timer { id: bannerTimer; interval: 4000; onTriggered: root.banner = "" }

    function say(msg) { bannerError = false; banner = msg; bannerTimer.stop() }
    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/staff") }

    // background roster refresh: silent + change-gated, paused whenever a card is expanded
    // or the add form is open so edits never get clobbered
    readonly property int autoRefreshMs: 30000
    property int quietReq: -1
    property string lastPayload: ""
    function quietLoad() {
        if (loading || quietReq !== -1 || adding || openId !== -1 || pendingWrites.length > 0) return
        quietReq = ProctorApi.send("GET", "/proctor/staff")
    }
    Timer { interval: root.autoRefreshMs; repeat: true; running: root.visible && root.drill.length === 0; onTriggered: root.quietLoad() }

    // clocked-in staff — shown inline under the roster like the Players online grid
    property var activeStaff: []
    property int reqActive: -1
    property string activePayload: ""
    function loadActive() { if (reqActive === -1) reqActive = ProctorApi.send("GET", "/proctor/active") }
    Timer { interval: 25000; repeat: true; running: root.visible && root.drill.length === 0; triggeredOnStart: true; onTriggered: root.loadActive() }
    function track(reqId) { var p = pendingWrites; p.push(reqId); pendingWrites = p }
    function createStaff(body) { track(ProctorApi.send("POST", "/proctor/staff", JSON.stringify(body))); say("Adding " + body.username + "…") }
    function patchStaff(id, body) { track(ProctorApi.send("PATCH", "/proctor/staff/" + id, JSON.stringify(body))); say("Saving…") }
    function removeStaff(id) { track(ProctorApi.send("DELETE", "/proctor/staff/" + id)); say("Removing…") }
    function resetPw(id, pw) { track(ProctorApi.send("POST", "/proctor/staff/" + id + "/password", JSON.stringify({ password: pw }))); say("Resetting password…") }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.quietReq) {
                root.quietReq = -1
                if (!ok || body === root.lastPayload || root.adding || root.openId !== -1) return
                root.lastPayload = body
                try { root.staff = JSON.parse(body).staff || [] } catch (e) {}
                return
            }
            if (id === root.reqList) {
                root.loading = false
                if (ok) {
                    root.lastPayload = body
                    try { root.staff = JSON.parse(body).staff || [] } catch (e) { root.staff = [] }
                } else root.error = "Couldn't load staff (admin only)."
                return
            }
            if (id === root.reqRanks) {
                if (ok) { try { root.ranks = JSON.parse(body).ranks || [] } catch (e) { root.ranks = [] } }
                return
            }
            if (id === root.reqActive) {
                root.reqActive = -1
                if (ok && body !== root.activePayload) {
                    root.activePayload = body
                    try { root.activeStaff = JSON.parse(body).active || [] } catch (e) {}
                }
                return
            }
            var idx = root.pendingWrites.indexOf(id)
            if (idx !== -1) {
                root.pendingWrites.splice(idx, 1)
                if (!ok) {
                    var msg = ""
                    try { msg = JSON.parse(body).error || "" } catch (e) {}
                    root.banner = msg.length ? msg : "Action failed (" + status + ")."
                    root.bannerError = true
                    bannerTimer.stop()
                } else {
                    root.bannerError = false
                    root.banner = "Done."
                    bannerTimer.restart()
                }
                root.load()
            }
        }
    }

    // ================= DRILL-IN FEED =================
    Item {
        anchors.fill: parent; anchors.margins: 4; visible: root.drill.length > 0
        Item {
            id: drillHead
            width: parent.width; height: 34
            SButton { id: backBtn; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: "Back"; icon: "chevron-left"; variant: "ghost"; onClicked: root.drill = "" }
            Text { anchors.left: backBtn.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: root.navLabel(root.drill); color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
        }
        AdminTab {
            anchors.top: drillHead.bottom; anchors.topMargin: 8
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            forceView: root.drill
            staffMap: root.staffMap
        }
    }

    // ================= ROSTER HOME =================
    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12; visible: root.drill.length === 0

        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Staff roster"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton { text: "Add staff"; icon: "plus"; variant: "primary"; onClicked: root.adding = !root.adding }
                SButton { text: root.loading ? "…" : "Refresh"; icon: "refresh"; variant: "secondary"; onClicked: root.load() }
            }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        Rectangle {
            width: parent.width; height: 26; radius: 8; visible: root.banner.length > 0
            color: root.bannerError ? Qt.rgba(0.88, 0.42, 0.42, 0.14) : Qt.rgba(0.35, 0.82, 0.48, 0.14)
            Text {
                anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: root.banner; color: root.bannerError ? "#ff9b9b" : "#9fe0ad"; font.pixelSize: 12
            }
        }

        // search
        Rectangle {
            width: parent.width; height: 32; radius: 8; color: "#0f0a06"
            border.color: searchIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
            Image {
                id: srchIco; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/jarton/staff/icons/ui/users-rest.svg"; width: 13; height: 13; sourceSize: Qt.size(26, 26); opacity: 0.5
            }
            TextInput {
                id: searchIn; anchors.left: srchIco.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: "#F2E8D0"; font.pixelSize: 12; clip: true
                onTextChanged: root.searchText = text
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Search staff…"; color: "#6b5d3f"; font.pixelSize: 12; visible: searchIn.text.length === 0 }
            }
        }

        // ---- add form ----
        Rectangle {
            id: addForm
            width: parent.width; height: addFormCol.height + 24; radius: 12; visible: root.adding; color: "#15100a"; border.color: "#FFB81C"; border.width: 1
            Column {
                id: addFormCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                Text { text: "New staff member"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                Row {
                    width: parent.width; spacing: 8
                    StaffField { id: fUser; ph: "username"; w: (parent.width - 8) / 2 }
                    StaffField { id: fDisplay; ph: "display name (optional)"; w: (parent.width - 8) / 2 }
                }
                Row {
                    width: parent.width; spacing: 8
                    z: fRank.open ? 10 : 0
                    StaffField { id: fMc; ph: "minecraft name"; w: (parent.width - 8) / 2 }
                    RankField { id: fRank; w: (parent.width - 8) / 2 }
                }
                Row {
                    width: parent.width; spacing: 8
                    StaffField { id: fPass; ph: "password (min 8)"; pw: true; w: (parent.width - 8) / 2 }
                    Row {
                        height: 32; spacing: 8
                        AdminToggle { id: tOp; label: "auto-op" }
                        AdminToggle { id: tAdmin; label: "admin" }
                        AdminToggle { id: tApps; label: "applications"; on: true }
                    }
                }
                Row {
                    spacing: 8
                    SButton {
                        text: "Create"; variant: "primary"
                        onClicked: {
                            if (fUser.value.length === 0 || fMc.value.length === 0 || fRank.value.length === 0 || fPass.value.length < 8) { root.banner = "Need username, MC name, rank, 8+ char password."; return }
                            root.createStaff({ username: fUser.value, displayName: fDisplay.value, mcName: fMc.value, rank: fRank.value, password: fPass.value, autoOp: tOp.on, proctorAdmin: tAdmin.on, allowApplications: tApps.on })
                            root.adding = false
                            fUser.clear(); fDisplay.clear(); fMc.clear(); fRank.clear(); fPass.clear()
                        }
                    }
                    SButton { text: "Cancel"; variant: "ghost"; onClicked: root.adding = false }
                }
            }
        }

        // ---- roster: grows to fit every card so the whole list is visible without a
        //      peephole scroll; only caps (and scrolls) if it would crowd out the rest ----
        Rectangle {
            width: parent.width
            height: root.adding ? 120 : Math.min(rosterList.contentHeight, Math.max(160, root.height - 280))
            radius: 12; color: "transparent"
            ListView {
                id: rosterList
                anchors.fill: parent
                clip: true; spacing: 8
                model: root.shownStaff
                delegate: Rectangle {
                    id: sCard
                    required property var modelData
                    readonly property bool open: root.openId === modelData.id
                    width: rosterList.width; height: sCol.height + 22; radius: 12
                    color: "#16110a"; border.color: sCard.open ? "#3a2f14" : "#241c12"; border.width: 1
                    opacity: modelData.enabled === false ? 0.55 : 1.0
                    Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                    Column {
                        id: sCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 11; spacing: 10
                        Item {
                            width: parent.width; height: 32
                            Avatar { id: sh; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; size: 30; uuid: modelData.mcUuid ? modelData.mcUuid : "" }
                            Column {
                                anchors.left: sh.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { text: modelData.displayName ? modelData.displayName : modelData.username; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true }
                                Row {
                                    spacing: 6
                                    Text { text: (modelData.mcName ? modelData.mcName : modelData.username) + "   ·   @" + modelData.username; color: "#9a8a66"; font.pixelSize: 11 }
                                    Rectangle {
                                        visible: !!modelData.discord
                                        width: dcT.width + 12; height: 16; radius: 8; color: Qt.rgba(0.45, 0.5, 0.9, 0.18)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { id: dcT; anchors.centerIn: parent; text: "@" + (modelData.discord || ""); color: "#9aa4ff"; font.pixelSize: 10; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { ProctorClient.copyToClipboard("@" + modelData.discord); root.say("Copied @" + modelData.discord) }
                                        }
                                    }
                                }
                            }
                            Row {
                                anchors.right: chev.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Rectangle { width: rkT.width + 16; height: 20; radius: 10; color: Qt.rgba(1, 0.72, 0.2, 0.16); anchors.verticalCenter: parent.verticalCenter
                                    Text { id: rkT; anchors.centerIn: parent; text: modelData.rank ? modelData.rank : "staff"; color: "#FFB833"; font.pixelSize: 11; font.bold: true } }
                                Rectangle { visible: modelData.proctorAdmin === true; width: adT.width + 14; height: 20; radius: 10; color: Qt.rgba(0.35, 0.82, 0.48, 0.16); anchors.verticalCenter: parent.verticalCenter
                                    Text { id: adT; anchors.centerIn: parent; text: "admin"; color: "#5ad17a"; font.pixelSize: 10; font.bold: true } }
                                Rectangle { visible: modelData.active === true; width: 8; height: 8; radius: 4; color: "#5ad17a"; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Image {
                                id: chev
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                source: "qrc:/jarton/staff/icons/ui/chevron-up-cream.svg"
                                width: 12; height: 12; sourceSize: Qt.size(24, 24)
                                opacity: 0.45
                                rotation: sCard.open ? 180 : 90
                                Behavior on rotation { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            }
                        }

                        // expanded controls
                        Column {
                            width: parent.width; spacing: 8; visible: sCard.open
                            Row {
                                width: parent.width; spacing: 8
                                z: erank.open ? 10 : 0
                                RankField { id: erank; w: (parent.width - 8) / 2; preset: modelData.rank ? modelData.rank : "" }
                                SButton { anchors.top: parent.top; anchors.topMargin: 0; height: 32; text: "Save rank"; variant: "secondary"; onClicked: if (erank.value.length) root.patchStaff(modelData.id, { rank: erank.value }) }
                            }
                            Row {
                                spacing: 7
                                SButton { compact: true; text: modelData.proctorAdmin ? "Revoke admin" : "Make admin"; variant: "secondary"; onClicked: root.patchStaff(modelData.id, { proctorAdmin: !modelData.proctorAdmin }) }
                                SButton { compact: true; text: modelData.autoOp ? "Disable auto-op" : "Enable auto-op"; variant: "secondary"; onClicked: root.patchStaff(modelData.id, { autoOp: !modelData.autoOp }) }
                                SButton { compact: true; text: modelData.allowApplications === false ? "Allow applications" : "Block applications"; variant: "secondary"; onClicked: root.patchStaff(modelData.id, { allowApplications: modelData.allowApplications === false }) }
                                SButton { compact: true; text: modelData.enabled === false ? "Enable" : "Disable"; variant: modelData.enabled === false ? "primary" : "ghost"; onClicked: root.patchStaff(modelData.id, { enabled: modelData.enabled === false }) }
                            }
                            Row {
                                width: parent.width; spacing: 7
                                StaffField { id: epw; ph: "new password (min 8)"; pw: true; w: (parent.width - 8) / 2 }
                                SButton { compact: true; anchors.verticalCenter: parent.verticalCenter; text: "Reset password"; variant: "secondary"; onClicked: if (epw.value.length >= 8) { root.resetPw(modelData.id, epw.value); epw.clear() } }
                                SButton { compact: true; anchors.verticalCenter: parent.verticalCenter; text: "Remove"; variant: "danger"; onClicked: root.removeStaff(modelData.id) }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.bottomMargin: sCard.open ? sCard.height - 44 : 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openId = sCard.open ? -1 : modelData.id
                    }
                }
                Text { anchors.centerIn: parent; visible: !root.loading && root.shownStaff.length === 0 && root.error.length === 0
                    text: root.searchText.length ? "No staff match." : "No staff."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
            }
        }

        // ---- clocked-in staff (inline, Players-online style) ----
        Text { text: "CLOCKED IN · " + root.activeStaff.length; color: "#8a7a56"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5 }
        Text {
            width: parent.width; visible: root.activeStaff.length === 0
            text: "Nobody's clocked in right now."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 13
        }
        Flow {
            width: parent.width; spacing: 8; visible: root.activeStaff.length > 0
            Repeater {
                model: root.activeStaff
                Rectangle {
                    width: 92; height: 106; radius: 12
                    color: acHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Column {
                        anchors.top: parent.top; anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                        Item {
                            width: 56; height: 56; anchors.horizontalCenter: parent.horizontalCenter
                            Avatar { anchors.fill: parent; size: 56; uuid: modelData.mcUuid || modelData.mcName || "" }
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                anchors.rightMargin: -3; anchors.bottomMargin: -3
                                color: "#3BA55D"; border.color: "#0f0a06"; border.width: 3
                            }
                        }
                        Text {
                            width: 80; horizontalAlignment: Text.AlignHCenter
                            text: modelData.displayName || modelData.mcName || ""; color: "#FFFFFF"; font.pixelSize: 12; font.bold: true; elide: Text.ElideMiddle
                        }
                        Text {
                            width: 80; horizontalAlignment: Text.AlignHCenter
                            text: modelData.server || ""; color: "#FFB833"; font.pixelSize: 10
                        }
                    }
                    MouseArea { id: acHover; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }

        // ---- oversight drill-in buttons: 5 feeds, laid out 2 / 2 / 1-centered so the
        //      odd card sits centered instead of leaving a hole ----
        Text { text: "OVERSIGHT"; color: "#8a7a56"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5 }
        component NavCard: Rectangle {
            property var item: ({})
            width: (root.width - 8 - 8) / 2; height: 52; radius: 11
            color: nc.containsMouse ? "#1c160d" : "#16110a"
            border.color: nc.containsMouse ? "#3a2f14" : "#241c12"; border.width: 1
            Behavior on color { ColorAnimation { duration: 110 } }
            Image {
                id: nci; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/jarton/staff/icons/ui/" + item.icon + "-active.svg"
                width: 18; height: 18; sourceSize: Qt.size(36, 36)
            }
            Column {
                anchors.left: nci.right; anchors.leftMargin: 12; anchors.right: ncc.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Text { text: item.label; color: "#F2E8D0"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
                Text { text: item.sub; color: "#6b5d3f"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
            }
            Text { id: ncc; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "›"; color: "#6b5d3f"; font.pixelSize: 16 }
            MouseArea { id: nc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.drill = item.id }
        }
        Column {
            width: parent.width; spacing: 8
            Row { width: parent.width; spacing: 8
                NavCard { item: root.navItems[0] }
                NavCard { item: root.navItems[1] }
            }
            Row { width: parent.width; spacing: 8
                NavCard { item: root.navItems[2] }
                NavCard { item: root.navItems[3] }
            }
            Item {
                width: parent.width; height: 52
                NavCard { anchors.horizontalCenter: parent.horizontalCenter; item: root.navItems[4] }
            }
        }
    }

    // ---- small inline field + toggle components ----
    component StaffField: Rectangle {
        id: fld
        property string ph: ""
        property bool pw: false
        property real w: 160
        property string preset: ""
        property alias value: ti.text
        function clear() { ti.text = "" }
        width: w; height: 32; radius: 8; color: "#0f0a06"
        border.color: ti.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
        Component.onCompleted: if (preset.length) ti.text = preset
        TextInput {
            id: ti; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 12; clip: true
            echoMode: fld.pw ? TextInput.Password : TextInput.Normal
            Text { anchors.verticalCenter: parent.verticalCenter; text: fld.ph; color: "#6b5d3f"; font.pixelSize: 12; visible: ti.text.length === 0 }
        }
    }
    component RankField: Rectangle {
        id: rf
        property real w: 160
        property string preset: ""
        property bool open: false
        readonly property bool dd: root.ranks.length > 0
        property string picked: ""
        readonly property string value: dd ? picked : rti.text
        function clear() { picked = ""; rti.text = ""; open = false }
        width: w; height: 32 + (dd && open ? optFlick.height + 6 : 0)
        radius: 8; color: "#0f0a06"
        border.color: (dd ? open : rti.activeFocus) ? "#FFB81C" : "#2a2114"; border.width: 1
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Component.onCompleted: if (preset.length) { picked = preset; rti.text = preset }

        Item {
            width: parent.width; height: 32; visible: rf.dd
            Text {
                anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: rf.picked.length ? rf.picked : "rank"
                color: rf.picked.length ? "#F2E8D0" : "#6b5d3f"; font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: rf.open ? "▴" : "▾"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rf.open = !rf.open }
        }
        Flickable {
            id: optFlick
            visible: rf.dd && rf.open
            anchors.top: parent.top; anchors.topMargin: 34
            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 4; anchors.rightMargin: 4
            height: Math.min(root.ranks.length, 6) * 28
            contentHeight: optCol.height; clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: optCol; width: parent.width
                Repeater {
                    model: root.ranks
                    Rectangle {
                        width: optCol.width; height: 28; radius: 6
                        color: optHover.containsMouse ? Qt.rgba(1, 0.72, 0.2, 0.14) : "transparent"
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.rank; color: optHover.containsMouse ? "#FFE082" : "#F2E8D0"; font.pixelSize: 12
                        }
                        MouseArea {
                            id: optHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { rf.picked = modelData.rank; rf.open = false }
                        }
                    }
                }
            }
        }
        TextInput {
            id: rti; visible: !rf.dd
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.leftMargin: 10; anchors.rightMargin: 10; height: 32
            verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 12; clip: true
            Text { anchors.verticalCenter: parent.verticalCenter; text: "rank"; color: "#6b5d3f"; font.pixelSize: 12; visible: rti.text.length === 0 }
        }
    }
    component AdminToggle: Rectangle {
        id: tg
        property string label: ""
        property bool on: false
        height: 32; width: tgl.width + 22; radius: 8
        color: on ? "#3a2f14" : "#0f0a06"
        border.color: on ? "#FFB81C" : "#2a2114"; border.width: 1
        Text { id: tgl; anchors.centerIn: parent; text: tg.label; color: tg.on ? "#FFE082" : "#8a7a56"; font.pixelSize: 12; font.bold: tg.on }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.on = !tg.on }
    }
}
