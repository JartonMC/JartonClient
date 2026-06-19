import QtQuick
import Jarton

// One server, desktop-laid-out and modernised (honey theme): power + live stats header,
// a pill tab bar, and the active tab — Console (terminal-framed wings console + input)
// or Files (browser + syntax-highlighted editor).
Item {
    id: view
    signal back()

    property string tab: "console"
    property string filesServer: ""
    property string lastServer: ""

    Connections {
        target: PteroServer
        function onChanged() {
            if (PteroServer.serverId !== view.lastServer) {
                view.lastServer = PteroServer.serverId
                view.tab = "console"
                view.filesServer = ""
            }
        }
    }

    function fmtBytes(b) {
        if (b <= 0) return "0 MB"
        var mb = b / 1048576
        return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
    }
    function fmtUptime(ms) {
        if (ms <= 0) return "—"
        var s = Math.floor(ms / 1000)
        var d = Math.floor(s / 86400); s -= d * 86400
        var h = Math.floor(s / 3600); s -= h * 3600
        var m = Math.floor(s / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }
    function stateColor(s) {
        return s === "running" ? "#5ad17a" : (s === "starting" || s === "stopping") ? "#FFB81C" : "#e06c6c"
    }
    function selectTab(t) {
        tab = t
        if (t === "files" && filesServer !== PteroServer.serverId) {
            filesServer = PteroServer.serverId
            PteroFiles.start(PteroServer.serverId)
        }
    }

    Column {
        id: head
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 18
        spacing: 16

        // header row
        Row {
            width: parent.width
            spacing: 12
            SButton { text: "Back"; glyph: "‹"; variant: "ghost"; anchors.verticalCenter: parent.verticalCenter; onClicked: view.back() }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: PteroServer.serverName; color: "#F2E8D0"; font.pixelSize: 20; font.bold: true
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: stRow.width + 22; height: 26; radius: 13
                color: Qt.rgba(view.stateColor(PteroServer.runState).r, view.stateColor(PteroServer.runState).g, view.stateColor(PteroServer.runState).b, 0.13)
                Row {
                    id: stRow
                    anchors.centerIn: parent; spacing: 7
                    Rectangle {
                        width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter
                        color: view.stateColor(PteroServer.runState)
                    }
                    Text { text: PteroServer.runState; color: view.stateColor(PteroServer.runState); font.pixelSize: 12; font.bold: true }
                }
            }
        }

        // power controls
        Row {
            spacing: 9
            SButton { text: "Start"; variant: "primary"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("start") }
            SButton { text: "Restart"; variant: "secondary"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("restart") }
            SButton { text: "Stop"; variant: "secondary"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("stop") }
            SButton { text: "Kill"; variant: "danger"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("kill") }
        }

        // live stats
        Row {
            width: parent.width
            spacing: 12
            Repeater {
                model: [
                    { k: "CPU", v: PteroServer.cpuPercent.toFixed(1) + "%" },
                    { k: "MEMORY", v: view.fmtBytes(PteroServer.memoryBytes) + (PteroServer.memoryLimitBytes > 0 ? " / " + view.fmtBytes(PteroServer.memoryLimitBytes) : "") },
                    { k: "DISK", v: view.fmtBytes(PteroServer.diskBytes) },
                    { k: "UPTIME", v: view.fmtUptime(PteroServer.uptimeMs) }
                ]
                delegate: Rectangle {
                    width: (view.width - 36 - 36) / 4
                    height: 60; radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1c160d" }
                        GradientStop { position: 1.0; color: "#15100a" }
                    }
                    border.color: "#2a2114"; border.width: 1
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { text: modelData.k; color: "#8a7a56"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.5 }
                        Text { text: modelData.v; color: "#F2E8D0"; font.pixelSize: 15; font.bold: true }
                    }
                }
            }
        }

        // pill tab bar
        Row {
            spacing: 8
            Repeater {
                model: [
                    { id: "console", label: "Console" }, { id: "files", label: "Files" },
                    { id: "backups", label: "Backups" }, { id: "schedules", label: "Schedules" },
                    { id: "network", label: "Network" }, { id: "subusers", label: "Subusers" },
                    { id: "databases", label: "Databases" }
                ]
                delegate: Rectangle {
                    width: tabLabel.width + 30; height: 32; radius: 16
                    color: view.tab === modelData.id ? "#FFB81C" : (tabArea.containsMouse ? "#26200f" : "#1b150e")
                    border.color: view.tab === modelData.id ? "transparent" : "#2a2114"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: tabLabel; anchors.centerIn: parent; text: modelData.label
                        color: view.tab === modelData.id ? "#1a140e" : "#9a8a66"
                        font.pixelSize: 13; font.bold: view.tab === modelData.id
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.selectTab(modelData.id)
                    }
                }
            }
        }
    }

    // content
    Item {
        anchors.top: head.bottom; anchors.topMargin: 14
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 18

        // ===== Console =====
        Column {
            anchors.fill: parent
            spacing: 12
            visible: view.tab === "console"

            Rectangle {
                width: parent.width
                height: parent.height - 52
                radius: 13
                color: "#0a0805"; border.color: "#2a2114"; border.width: 1

                // terminal title bar
                Rectangle {
                    id: termBar
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 32; radius: 13
                    color: "#140f09"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 13; color: "#140f09" }  // square off bottom corners
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Rectangle { width: 10; height: 10; radius: 5; color: "#e06c6c" }
                        Rectangle { width: 10; height: 10; radius: 5; color: "#FFB81C" }
                        Rectangle { width: 10; height: 10; radius: 5; color: "#5ad17a" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "console" + (PteroServer.consoleState === "live" ? "" : " · " + PteroServer.consoleState)
                        color: "#6b5d3f"; font.family: "Menlo"; font.pixelSize: 11
                    }
                }

                ListView {
                    id: log
                    anchors.top: termBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 12
                    clip: true
                    model: PteroServer.lines
                    delegate: Text {
                        width: log.width
                        text: modelData; color: "#cfc3a6"
                        font.family: "Menlo"; font.pixelSize: 12; lineHeight: 1.2
                        wrapMode: Text.WrapAnywhere; textFormat: Text.RichText
                    }
                    onCountChanged: positionViewAtEnd()
                    Text {
                        anchors.centerIn: parent
                        visible: log.count === 0
                        text: PteroServer.consoleState === "live" ? "Waiting for output…" : "Connecting to console…"
                        color: "#6b5d3f"; font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 42; radius: 11
                color: "#15100a"
                border.color: cmdInput.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
                opacity: PteroServer.consoleState === "live" ? 1.0 : 0.5
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Row {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                    Text { text: "›"; color: "#FFB81C"; font.pixelSize: 17; anchors.verticalCenter: parent.verticalCenter; rightPadding: 9 }
                    TextInput {
                        id: cmdInput
                        width: parent.width - 26
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#F2E8D0"; font.family: "Menlo"; font.pixelSize: 13; clip: true
                        enabled: PteroServer.consoleState === "live"
                        activeFocusOnPress: true; persistentSelection: true
                        cursorVisible: activeFocus
                        cursorDelegate: Rectangle {
                            width: 2; color: "#FFB81C"; visible: cmdInput.cursorVisible
                            SequentialAnimation on opacity {
                                running: cmdInput.cursorVisible; loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                        onAccepted: { if (text.length > 0) { PteroServer.sendCommand(text); text = "" } }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type a command and press Enter"; color: "#6b5d3f"; font.pixelSize: 13
                            visible: cmdInput.text.length === 0 && !cmdInput.activeFocus
                        }
                    }
                }
            }
        }

        // ===== Files =====
        Item {
            anchors.fill: parent
            visible: view.tab === "files"

            Row {
                id: pathBar
                width: parent.width; height: 34; spacing: 10
                SButton { text: "Up"; glyph: "↑"; variant: "secondary"; onClicked: PteroFiles.up() }
                Rectangle {
                    width: parent.width - 180; height: 34; radius: 9
                    color: "#15100a"; border.color: "#2a2114"; border.width: 1
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: PteroFiles.cwd; color: "#9a8a66"; font.family: "Menlo"; font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }
                }
                SButton { text: PteroFiles.loading ? "…" : "Refresh"; variant: "secondary"; onClicked: PteroFiles.refresh() }
            }

            ListView {
                anchors.top: pathBar.bottom; anchors.topMargin: 10
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                clip: true; spacing: 5
                model: PteroFiles
                delegate: Rectangle {
                    width: ListView.view.width; height: 40; radius: 9
                    color: fileArea.containsMouse ? "#221a0f" : "#16110a"
                    border.color: fileArea.containsMouse ? "#3a2f1c" : "#221a12"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: isFile ? "📄" : "📁"; font.pixelSize: 14
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 42
                        anchors.verticalCenter: parent.verticalCenter
                        text: name; color: "#F2E8D0"; font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: isFile ? view.fmtBytes(size) : ""
                        color: "#6b5d3f"; font.pixelSize: 11
                    }
                    MouseArea {
                        id: fileArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: isFile ? PteroFiles.openFile(name) : PteroFiles.enter(name)
                    }
                }
            }

            // editor overlay
            Rectangle {
                anchors.fill: parent
                visible: PteroFiles.openPath !== ""
                color: "#0f0a06"

                Row {
                    id: edBar
                    width: parent.width; height: 36; spacing: 10
                    SButton { text: "Files"; glyph: "‹"; variant: "ghost"; onClicked: PteroFiles.closeFile() }
                    Rectangle {
                        width: parent.width - 230; height: 34; radius: 9
                        color: "#15100a"; border.color: "#2a2114"; border.width: 1
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: PteroFiles.openPath; color: "#9a8a66"; font.family: "Menlo"; font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }
                    SButton { text: PteroFiles.saving ? "Saving…" : "Save"; variant: "primary"; busy: PteroFiles.saving; onClicked: PteroFiles.save(editor.text) }
                }
                Text {
                    id: edErr
                    anchors.top: edBar.bottom; anchors.topMargin: 6
                    text: PteroFiles.editorError; color: "#e06c6c"; font.pixelSize: 12
                    visible: PteroFiles.editorError.length > 0
                }
                Rectangle {
                    anchors.top: edErr.visible ? edErr.bottom : edBar.bottom; anchors.topMargin: 10
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    radius: 13; color: "#0a0805"; border.color: "#2a2114"; border.width: 1
                    Flickable {
                        id: flick
                        anchors.fill: parent; anchors.margins: 12
                        clip: true
                        contentWidth: editor.width; contentHeight: editor.height
                        function ensureVisible(r) {
                            if (contentY >= r.y) contentY = r.y
                            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
                        }
                        TextEdit {
                            id: editor
                            width: flick.width
                            text: PteroFiles.content
                            color: "#e6dcc4"; font.family: "Menlo"; font.pixelSize: 13
                            selectByMouse: true; persistentSelection: true
                            wrapMode: TextEdit.WrapAnywhere
                            textFormat: TextEdit.PlainText
                            tabStopDistance: 28
                            selectionColor: "#5c4a2a"
                            cursorDelegate: Rectangle {
                                width: 2; color: "#FFB81C"; visible: editor.cursorVisible
                                SequentialAnimation on opacity {
                                    running: editor.cursorVisible; loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 500 }
                                    NumberAnimation { to: 1; duration: 500 }
                                }
                            }
                            Component.onCompleted: SyntaxHelper.attach(editor.textDocument)
                            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: PteroFiles.editorLoading
                        text: "Loading…"; color: "#6b5d3f"; font.pixelSize: 13
                    }
                }
            }
        }

        // ===== Backups / Schedules / Network / Subusers / Databases =====
        BackupsTab   { anchors.fill: parent; visible: view.tab === "backups";   serverId: PteroServer.serverId }
        SchedulesTab { anchors.fill: parent; visible: view.tab === "schedules"; serverId: PteroServer.serverId }
        NetworkTab   { anchors.fill: parent; visible: view.tab === "network";   serverId: PteroServer.serverId }
        SubusersTab  { anchors.fill: parent; visible: view.tab === "subusers";  serverId: PteroServer.serverId }
        DatabasesTab { anchors.fill: parent; visible: view.tab === "databases"; serverId: PteroServer.serverId }
    }
}
