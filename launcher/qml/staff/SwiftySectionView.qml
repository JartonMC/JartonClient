import QtQuick
import Jarton

// Swifty section: hybrid sign-in (the Discord `swifty` role reveals the tab; you log into
// the Swifty service here), then your boards grouped by workspace. Board view (columns +
// cards) + card detail come next.
Item {
    id: section

    property string selBoardId: ""
    property string selBoardName: ""

    // boards load: /orgs/mine -> /workspaces/{org} -> /boards/{workspace}
    property var groups: []          // [{ ws, boards: [] }]
    property bool loading: false
    property string error: ""
    property int reqOrg: -1
    property var wsReqs: ({})         // requestId -> true (a /workspaces call)
    property var boardReqs: ({})      // requestId -> workspace index

    function loadBoards() {
        groups = []; error = ""; loading = true
        wsReqs = ({}); boardReqs = ({})
        reqOrg = SwiftyApi.send("GET", "/orgs/mine")
    }

    Connections {
        target: SwiftyClient
        function onChanged() { if (SwiftyClient.connected && section.groups.length === 0 && !section.loading) section.loadBoards() }
    }

    Connections {
        target: SwiftyApi
        function onResponse(id, ok, status, body) {
            if (id === section.reqOrg) {
                if (!ok) { section.loading = false; section.error = "Couldn't load your orgs."; return }
                var orgs = []; try { orgs = JSON.parse(body) } catch (e) {}
                if (!orgs.length) { section.loading = false; return }
                var w = SwiftyApi.send("GET", "/workspaces/" + orgs[0].id)
                var m = section.wsReqs; m[w] = true; section.wsReqs = m
                return
            }
            if (section.wsReqs[id]) {
                if (!ok) { section.loading = false; return }
                var spaces = []; try { spaces = JSON.parse(body) } catch (e) {}
                var g = []
                for (var i = 0; i < spaces.length; i++) {
                    g.push({ ws: spaces[i].name, boards: [] })
                    var b = SwiftyApi.send("GET", "/boards/" + spaces[i].id)
                    var bm = section.boardReqs; bm[b] = i; section.boardReqs = bm
                }
                section.groups = g
                section.loading = false
                return
            }
            if (section.boardReqs[id] !== undefined) {
                var idx = section.boardReqs[id]
                if (ok) {
                    var boards = []; try { boards = JSON.parse(body) } catch (e) {}
                    var gg = section.groups.slice()
                    if (gg[idx]) { gg[idx] = { ws: gg[idx].ws, boards: boards }; section.groups = gg }
                }
                return
            }
        }
    }

    // ---- logged-out: Swifty sign-in ----
    Column {
        anchors.centerIn: parent
        width: 300; spacing: 14
        visible: !SwiftyClient.connected

        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sign into Swifty"; color: "#FFE082"; font.pixelSize: 22; font.bold: true }
        Rectangle {
            width: parent.width; height: 44; radius: 11; color: "#15100a"
            border.color: emailIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
            TextInput {
                id: emailIn; anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 15; clip: true
                onAccepted: passIn.forceActiveFocus()
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Email"; color: "#6b5d3f"; font.pixelSize: 15; visible: emailIn.text.length === 0 && !emailIn.activeFocus }
            }
        }
        Rectangle {
            width: parent.width; height: 44; radius: 11; color: "#15100a"
            border.color: passIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
            TextInput {
                id: passIn; anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter; color: "#F2E8D0"; font.pixelSize: 15; echoMode: TextInput.Password; clip: true
                onAccepted: section.doSignIn()
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Password"; color: "#6b5d3f"; font.pixelSize: 15; visible: passIn.text.length === 0 && !passIn.activeFocus }
            }
        }
        Text { width: parent.width; text: SwiftyClient.loginError; color: "#e06c6c"; font.pixelSize: 13; wrapMode: Text.WordWrap; visible: SwiftyClient.loginError.length > 0 }
        SButton { width: parent.width; height: 44; text: SwiftyClient.signingIn ? "Signing in…" : "Sign in"; variant: "primary"; busy: SwiftyClient.signingIn; onClicked: section.doSignIn() }
    }
    function doSignIn() { if (emailIn.text.length && passIn.text.length) SwiftyClient.signIn(emailIn.text, passIn.text) }

    // ---- logged-in: boards by workspace ----
    Item {
        anchors.fill: parent; anchors.margins: 16
        visible: SwiftyClient.connected

        Item {
            id: sHeader; width: parent.width; height: 34
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Boards"; color: "#F2E8D0"; font.pixelSize: 20; font.bold: true }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: section.loading ? "…" : "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: section.loadBoards() }
        }
        Text {
            id: sErr; anchors.top: sHeader.bottom; anchors.topMargin: 8
            text: section.error; color: "#e06c6c"; font.pixelSize: 13; visible: section.error.length > 0
        }

        ListView {
            anchors.top: sErr.visible ? sErr.bottom : sHeader.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            clip: true; spacing: 14
            model: section.groups
            delegate: Column {
                width: ListView.view.width; spacing: 6
                Text { text: modelData.ws; color: "#8a7a56"; font.pixelSize: 11; font.bold: true }
                Repeater {
                    model: modelData.boards
                    delegate: Rectangle {
                        width: parent.width; height: 50; radius: 11
                        color: bA.containsMouse ? "#221a0f" : "#16110a"
                        border.color: bA.containsMouse ? "#3a2f1c" : "#241c12"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: "#F2E8D0"; font.pixelSize: 15; font.bold: true }
                        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: "#6b5d3f"; font.pixelSize: 18 }
                        MouseArea {
                            id: bA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { section.selBoardName = modelData.name; section.selBoardId = modelData.id }
                        }
                    }
                }
            }
            Text { anchors.centerIn: parent; visible: !section.loading && section.groups.length === 0; text: "No boards."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }

    SwiftyBoardView {
        anchors.fill: parent
        visible: section.selBoardId !== ""
        boardId: section.selBoardId
        boardName: section.selBoardName
        onBack: section.selBoardId = ""
    }
}
