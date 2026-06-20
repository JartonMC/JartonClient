import QtQuick
import Jarton

// Staff roster (admin): list, add, expand-to-edit (rank, flags, enable/disable, reset
// password) and remove. Mirrors the app's staff admin. All routes are admin-gated.
Item {
    id: root
    property var staff: []
    property bool loading: false
    property string error: ""
    property string banner: ""
    property int reqList: -1
    property var pendingWrites: []
    property bool loadedOnce: false
    property bool adding: false
    property int openId: -1

    onVisibleChanged: if (visible && !loadedOnce) { loadedOnce = true; load() }

    function load() { loading = true; error = ""; reqList = ProctorApi.send("GET", "/proctor/staff") }
    function track(reqId) { var p = pendingWrites; p.push(reqId); pendingWrites = p }
    function createStaff(body) { track(ProctorApi.send("POST", "/proctor/staff", JSON.stringify(body))); banner = "Adding " + body.username + "…" }
    function patchStaff(id, body) { track(ProctorApi.send("PATCH", "/proctor/staff/" + id, JSON.stringify(body))) }
    function removeStaff(id) { track(ProctorApi.send("DELETE", "/proctor/staff/" + id)); banner = "Removed staff." }
    function resetPw(id, pw) { track(ProctorApi.send("POST", "/proctor/staff/" + id + "/password", JSON.stringify({ password: pw }))); banner = "Password reset." }

    Connections {
        target: ProctorApi
        function onResponse(id, ok, status, body) {
            if (id === root.reqList) {
                root.loading = false
                if (ok) { try { root.staff = JSON.parse(body).staff || [] } catch (e) { root.staff = [] } }
                else root.error = "Couldn't load staff (admin only)."
                return
            }
            var idx = root.pendingWrites.indexOf(id)
            if (idx !== -1) {
                root.pendingWrites.splice(idx, 1)
                if (!ok) root.banner = "Action failed (" + status + ")."
                root.load()
            }
        }
    }

    Column {
        anchors.fill: parent; anchors.margins: 4; spacing: 12
        Item {
            width: parent.width; height: 32
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Staff roster"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton { text: "Add staff"; glyph: "＋"; variant: "primary"; onClicked: root.adding = !root.adding }
                SButton { text: root.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: root.load() }
            }
        }
        Text { width: parent.width; visible: root.error.length > 0; text: root.error; color: "#e06c6c"; font.pixelSize: 13 }
        Rectangle {
            width: parent.width; height: 26; radius: 8; visible: root.banner.length > 0; color: Qt.rgba(0.35, 0.82, 0.48, 0.14)
            Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: root.banner; color: "#9fe0ad"; font.pixelSize: 12 }
        }

        // ---- add form ----
        Rectangle {
            width: parent.width; height: 156; radius: 12; visible: root.adding; color: Qt.rgba(1, 1, 1, 0.05); border.color: "#FFB833"; border.width: 1
            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Text { text: "New staff member"; color: "#FFE082"; font.pixelSize: 13; font.bold: true }
                Row {
                    width: parent.width; spacing: 8
                    StaffField { id: fUser; ph: "username"; w: (parent.width - 8) / 2 }
                    StaffField { id: fDisplay; ph: "display name (optional)"; w: (parent.width - 8) / 2 }
                }
                Row {
                    width: parent.width; spacing: 8
                    StaffField { id: fMc; ph: "minecraft name"; w: (parent.width - 8) / 2 }
                    StaffField { id: fRank; ph: "rank (e.g. Moderator)"; w: (parent.width - 8) / 2 }
                }
                Row {
                    width: parent.width; spacing: 8
                    StaffField { id: fPass; ph: "password (min 8)"; pw: true; w: (parent.width - 8) / 2 }
                    Row {
                        height: 32; spacing: 8
                        AdminToggle { id: tOp; label: "auto-op" }
                        AdminToggle { id: tAdmin; label: "admin" }
                    }
                }
                Row {
                    spacing: 8
                    SButton {
                        text: "Create"; variant: "primary"
                        onClicked: {
                            if (fUser.value.length === 0 || fMc.value.length === 0 || fRank.value.length === 0 || fPass.value.length < 8) { root.banner = "Need username, MC name, rank, 8+ char password."; return }
                            root.createStaff({ username: fUser.value, displayName: fDisplay.value, mcName: fMc.value, rank: fRank.value, password: fPass.value, autoOp: tOp.on, proctorAdmin: tAdmin.on })
                            root.adding = false
                            fUser.clear(); fDisplay.clear(); fMc.clear(); fRank.clear(); fPass.clear()
                        }
                    }
                    SButton { text: "Cancel"; variant: "ghost"; onClicked: root.adding = false }
                }
            }
        }

        ListView {
            width: parent.width; height: parent.height - (root.adding ? 220 : 56) - (root.banner.length > 0 ? 38 : 0); clip: true; spacing: 8
            model: root.staff
            delegate: Rectangle {
                id: sCard
                required property var modelData
                readonly property bool open: root.openId === modelData.id
                width: ListView.view.width; height: sCol.height + 22; radius: 12
                color: Qt.rgba(1, 1, 1, 0.04); opacity: modelData.enabled === false ? 0.55 : 1.0
                Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                Column {
                    id: sCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 11; spacing: 10
                    Item {
                        width: parent.width; height: 32
                        Avatar { id: sh; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; size: 30; uuid: modelData.mcUuid ? modelData.mcUuid : "" }
                        Column {
                            anchors.left: sh.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: modelData.displayName ? modelData.displayName : modelData.username; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
                            Text { text: (modelData.mcName ? modelData.mcName : modelData.username) + "   ·   @" + modelData.username; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11 }
                        }
                        Row {
                            anchors.right: chev.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: rkT.width + 16; height: 20; radius: 10; color: Qt.rgba(1, 0.72, 0.2, 0.16); anchors.verticalCenter: parent.verticalCenter
                                Text { id: rkT; anchors.centerIn: parent; text: modelData.rank ? modelData.rank : "staff"; color: "#FFB833"; font.pixelSize: 11; font.bold: true } }
                            Rectangle { visible: modelData.proctorAdmin === true; width: adT.width + 14; height: 20; radius: 10; color: Qt.rgba(0.35, 0.82, 0.48, 0.16); anchors.verticalCenter: parent.verticalCenter
                                Text { id: adT; anchors.centerIn: parent; text: "admin"; color: "#5ad17a"; font.pixelSize: 10; font.bold: true } }
                            Rectangle { visible: modelData.active === true; width: 8; height: 8; radius: 4; color: "#5ad17a"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { id: chev; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: sCard.open ? "▾" : "▸"; color: Qt.rgba(1, 1, 1, 0.3); font.pixelSize: 13 }
                    }

                    // expanded controls
                    Column {
                        width: parent.width; spacing: 8; visible: sCard.open
                        Row {
                            width: parent.width; spacing: 8
                            StaffField { id: erank; ph: "rank"; w: (parent.width - 8) / 2; preset: modelData.rank ? modelData.rank : "" }
                            SButton { anchors.verticalCenter: parent.verticalCenter; text: "Save rank"; variant: "secondary"; onClicked: if (erank.value.length) root.patchStaff(modelData.id, { rank: erank.value }) }
                        }
                        Row {
                            spacing: 8
                            SButton { text: modelData.proctorAdmin ? "Revoke admin" : "Make admin"; variant: "secondary"; onClicked: root.patchStaff(modelData.id, { proctorAdmin: !modelData.proctorAdmin }) }
                            SButton { text: modelData.autoOp ? "Disable auto-op" : "Enable auto-op"; variant: "secondary"; onClicked: root.patchStaff(modelData.id, { autoOp: !modelData.autoOp }) }
                            SButton { text: modelData.enabled === false ? "Enable" : "Disable"; variant: modelData.enabled === false ? "primary" : "ghost"; onClicked: root.patchStaff(modelData.id, { enabled: modelData.enabled === false }) }
                        }
                        Row {
                            width: parent.width; spacing: 8
                            StaffField { id: epw; ph: "new password (min 8)"; pw: true; w: (parent.width - 8) / 2 }
                            SButton { anchors.verticalCenter: parent.verticalCenter; text: "Reset password"; variant: "secondary"; onClicked: if (epw.value.length >= 8) { root.resetPw(modelData.id, epw.value); epw.clear() } }
                            SButton { anchors.verticalCenter: parent.verticalCenter; text: "Remove"; variant: "danger"; onClicked: root.removeStaff(modelData.id) }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; anchors.bottomMargin: sCard.open ? sCard.height - 44 : 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openId = sCard.open ? -1 : modelData.id
                }
            }
            Text { anchors.centerIn: parent; visible: !root.loading && root.staff.length === 0 && root.error.length === 0; text: "No staff."; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14 }
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
        width: w; height: 32; radius: 8; color: Qt.rgba(1, 1, 1, 0.06)
        border.color: ti.activeFocus ? "#FFB833" : "transparent"; border.width: 1
        Component.onCompleted: if (preset.length) ti.text = preset
        TextInput {
            id: ti; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.pixelSize: 12; clip: true
            echoMode: fld.pw ? TextInput.Password : TextInput.Normal
            Text { anchors.verticalCenter: parent.verticalCenter; text: fld.ph; color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 12; visible: ti.text.length === 0 }
        }
    }
    component AdminToggle: Rectangle {
        id: tg
        property string label: ""
        property bool on: false
        height: 32; width: tgl.width + 22; radius: 8
        color: on ? Qt.rgba(1, 0.72, 0.2, 0.18) : Qt.rgba(1, 1, 1, 0.06)
        border.color: on ? "#FFB833" : "transparent"; border.width: 1
        Text { id: tgl; anchors.centerIn: parent; text: tg.label; color: tg.on ? "#FFB833" : Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 12; font.bold: tg.on }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.on = !tg.on }
    }
}
