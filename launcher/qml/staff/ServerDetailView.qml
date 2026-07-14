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
            filesTab.backStack = []
            filesTab.fwdStack = []
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
            SButton { text: "Back"; icon: "chevron-left"; variant: "ghost"; anchors.verticalCenter: parent.verticalCenter; onClicked: view.back() }
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
            SButton { text: "Start"; icon: "play"; variant: "primary"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("start") }
            SButton { text: "Restart"; icon: "refresh"; variant: "secondary"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("restart") }
            SButton { text: "Stop"; icon: "square"; variant: "secondary"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("stop") }
            SButton { text: "Kill"; icon: "zap"; variant: "danger"; busy: PteroServer.powerBusy; onClicked: PteroServer.power("kill") }
        }

        // live stats — players data rides the server-list poll, not the wings socket
        Row {
            width: parent.width
            spacing: 10
            readonly property var srvPlayers: {
                var tick = ServerListModel.count + ServerListModel.totalOnline  // rebind when the 10s poll lands
                return ServerListModel.playersFor(PteroServer.serverId)
            }
            Repeater {
                model: [
                    { k: "CPU", v: PteroServer.cpuPercent.toFixed(1) + "%" },
                    { k: "MEMORY", v: view.fmtBytes(PteroServer.memoryBytes) + (PteroServer.memoryLimitBytes > 0 ? " / " + view.fmtBytes(PteroServer.memoryLimitBytes) : "") },
                    { k: "DISK", v: view.fmtBytes(PteroServer.diskBytes) },
                    { k: "UPTIME", v: view.fmtUptime(PteroServer.uptimeMs) },
                    { k: "PLAYERS", v: "", players: true }
                ]
                delegate: Rectangle {
                    id: tile
                    readonly property var pl: modelData.players ? parent.srvPlayers : null
                    readonly property var names: pl ? (pl.names || []) : []
                    width: (view.width - 36 - 40) / 5
                    height: 52; radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1c160d" }
                        GradientStop { position: 1.0; color: "#15100a" }
                    }
                    border.color: tileHover.hovered && tile.names.length > 0 ? "#3a2f14" : "#2a2114"
                    border.width: 1
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text { text: modelData.k; color: "#8a7a56"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.5 }
                        Text {
                            text: modelData.players ? (tile.pl ? tile.pl.online + " / " + tile.pl.max : "—") : modelData.v
                            color: "#F2E8D0"; font.pixelSize: 14; font.bold: true
                        }
                    }
                    HoverHandler { id: tileHover; enabled: modelData.players === true }
                    // hover popover: who's on this server (SLP sample, ~12 names max)
                    Rectangle {
                        visible: tileHover.hovered && tile.names.length > 0
                        z: 50
                        anchors.top: parent.bottom; anchors.topMargin: 6
                        anchors.left: parent.left
                        width: namesCol.width + 28; height: namesCol.height + 20
                        radius: 11; color: "#1a140e"; border.color: "#3a2f14"; border.width: 1
                        Column {
                            id: namesCol
                            anchors.centerIn: parent
                            spacing: 3
                            Repeater {
                                model: tile.names
                                Text { text: modelData; color: "#FFE082"; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }

        // sub-tab bar
        STabBar {
            width: parent.width
            current: view.tab
            onSelected: (id) => view.selectTab(id)
            model: [
                { id: "console", label: "Console", icon: "terminal" },
                { id: "files", label: "Files", icon: "folder" },
                { id: "backups", label: "Backups", icon: "archive" },
                { id: "schedules", label: "Schedules", icon: "clock" },
                { id: "network", label: "Network", icon: "network" },
                { id: "subusers", label: "Subusers", icon: "users" },
                { id: "databases", label: "Databases", icon: "database" }
            ]
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
                    Text {
                        anchors.centerIn: parent
                        text: "console" + (PteroServer.consoleState === "live" ? "" : " · " + PteroServer.consoleState)
                        color: "#6b5d3f"; font.family: "Menlo"; font.pixelSize: 11
                    }
                }

                // a TextEdit mirror of PteroServer.console instead of a delegate-per-line
                // ListView, so output is selectable and Cmd/Ctrl+C copies like a terminal
                Flickable {
                    id: log
                    anchors.top: termBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 12
                    clip: true
                    flickDeceleration: 2600
                    maximumFlickVelocity: 6000
                    contentWidth: width
                    contentHeight: term.height
                    // terminal follow: pinned to the tail until the user scrolls up,
                    // re-pins when they come back to the bottom
                    property bool follow: true
                    property real accel: 1
                    property real lastWheel: 0
                    function pin() { contentY = Math.max(0, contentHeight - height) }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse
                        onWheel: function (e) {
                            var now = Date.now()
                            log.accel = (now - log.lastWheel < 90) ? Math.min(log.accel + 0.7, 7) : 1.4
                            log.lastWheel = now
                            var maxY = Math.max(0, log.contentHeight - log.height)
                            log.contentY = Math.max(0, Math.min(maxY, log.contentY - (e.angleDelta.y / 120) * 64 * log.accel))
                            log.follow = log.contentY >= maxY - 4
                            e.accepted = true
                        }
                    }
                    onMovementEnded: follow = atYEnd
                    // wrapped RichText settles its height after insertion; keep
                    // re-pinning as the content grows so the tail stays in view
                    onContentHeightChanged: if (follow && !moving) pin()
                    onVisibleChanged: if (visible) { follow = true; Qt.callLater(log.pin) }

                    TextEdit {
                        id: term
                        width: log.width
                        height: Math.max(implicitHeight, log.height)  // short logs: click anywhere in the frame to focus
                        readOnly: true
                        selectByMouse: true; selectByKeyboard: true; persistentSelection: true
                        color: "#cfc3a6"; font.family: "Menlo"; font.pixelSize: 12
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.RichText
                        selectionColor: "#5c4a2a"

                        property int bufLines: 0
                        // TextEdit has no lineHeight; carry the old delegate's 1.2 on each block
                        function wrap(html) { return "<div style=\"margin:0;line-height:120%\">" + html + "</div>" }
                        function push(html) {
                            append(wrap(html))
                            bufLines++
                            // mirror ConsoleLogModel's front trim so the document can't outgrow the cap
                            var cap = PteroServer.console.maxLines()
                            while (bufLines > cap) {
                                var nl = getText(0, Math.min(length, 4096)).indexOf("\n")
                                if (nl < 0) break
                                remove(0, nl + 1)
                                bufLines--
                            }
                            if (log.follow) Qt.callLater(log.pin)
                        }
                        function refill() {
                            var ls = PteroServer.console.allLines()
                            text = ls.map(wrap).join("")
                            bufLines = ls.length
                            log.follow = true
                            Qt.callLater(log.pin)
                        }
                        Component.onCompleted: refill()
                        Connections {
                            target: PteroServer.console
                            function onLineAppended(html) { term.push(html) }
                            function onCleared() { term.clear(); term.bufLines = 0; log.follow = true }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: term.bufLines === 0
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
            id: filesTab
            anchors.fill: parent
            visible: view.tab === "files"
            property bool creatingFolder: false
            property string renaming: ""

            // browser-style name filter (Ctrl+F while browsing)
            property bool filtering: false
            property string filterText: ""   // kept lowercased; delegates collapse on mismatch
            onFilterTextChanged: fileList.positionViewAtBeginning()
            // a filter carried into a new dir would silently hide files there
            property string filterCwd: PteroFiles.cwd
            onFilterCwdChanged: closeFilter()

            function openFilter() {
                filtering = true
                filterIn.forceActiveFocus()
                filterIn.selectAll()
            }
            function closeFilter() {
                filtering = false
                filterIn.text = ""
            }

            Shortcut {
                sequences: [StandardKey.Find]
                enabled: filesTab.visible
                onActivated: {
                    if (PteroFiles.openPath !== "") edOverlay.openFind()
                    else filesTab.openFilter()
                }
            }

            // browser-style directory history: every navigation pushes the dir we
            // left, mouse back/forward (and the editor's back) walk the stacks
            property var backStack: []
            property var fwdStack: []

            function navPush() {
                backStack.push(PteroFiles.cwd)
                fwdStack = []
            }
            function goBack() {
                if (PteroFiles.openPath !== "") { PteroFiles.closeFile(); return }
                // list() silently no-ops while a listing is in flight — mutating the
                // stacks then would desync history by one entry
                if (PteroFiles.loading || backStack.length === 0) return
                fwdStack.push(PteroFiles.cwd)
                PteroFiles.list(backStack.pop())
            }
            function goForward() {
                if (PteroFiles.openPath !== "" || PteroFiles.loading || fwdStack.length === 0) return
                backStack.push(PteroFiles.cwd)
                PteroFiles.list(fwdStack.pop())
            }

            // lowest z, only claims the side buttons — left clicks fall through to the
            // rows/editor above, XButton presses nothing else accepts land here
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.BackButton | Qt.ForwardButton
                onClicked: function (e) {
                    if (e.button === Qt.BackButton) filesTab.goBack()
                    else filesTab.goForward()
                }
            }

            Column {
                id: fhead
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                spacing: 8
                Row {
                    width: parent.width; height: 34; spacing: 10
                    SButton { text: "Up"; icon: "chevron-up"; variant: "secondary"; onClicked: { if (PteroFiles.loading) return; if (PteroFiles.cwd !== "/") filesTab.navPush(); PteroFiles.up() } }
                    Rectangle {
                        width: parent.width - 290; height: 34; radius: 9
                        color: "#15100a"; border.color: "#2a2114"; border.width: 1
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: PteroFiles.cwd; color: "#9a8a66"; font.family: "Menlo"; font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }
                    SButton { text: "New folder"; icon: "plus"; variant: "secondary"; onClicked: { filesTab.renaming = ""; filesTab.creatingFolder = !filesTab.creatingFolder } }
                    SButton { text: PteroFiles.loading ? "…" : "Refresh"; variant: "secondary"; onClicked: PteroFiles.refresh() }
                }
                // inline create-folder / rename input
                Rectangle {
                    width: parent.width; height: 38; radius: 9
                    visible: filesTab.creatingFolder || filesTab.renaming.length > 0
                    color: "#15100a"; border.color: "#FFB81C"; border.width: 1
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; text: filesTab.renaming.length > 0 ? "Rename to" : "New folder"; color: "#FFE082"; font.pixelSize: 12 }
                        TextInput {
                            id: nameIn
                            width: parent.width - 200; anchors.verticalCenter: parent.verticalCenter
                            color: "#F2E8D0"; font.pixelSize: 13; clip: true
                            onAccepted: filesTab.commitInline(text)
                        }
                        SButton { anchors.verticalCenter: parent.verticalCenter; text: "OK"; variant: "primary"; onClicked: filesTab.commitInline(nameIn.text) }
                        SButton { anchors.verticalCenter: parent.verticalCenter; text: "Cancel"; variant: "ghost"; onClicked: { filesTab.creatingFolder = false; filesTab.renaming = ""; nameIn.text = "" } }
                    }
                }
                // inline name filter
                Rectangle {
                    width: parent.width; height: 38; radius: 9
                    visible: filesTab.filtering
                    color: "#15100a"; border.color: filterIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Filter"; color: "#FFE082"; font.pixelSize: 12 }
                        TextInput {
                            id: filterIn
                            width: parent.width - 140; anchors.verticalCenter: parent.verticalCenter
                            color: "#F2E8D0"; font.pixelSize: 13; clip: true
                            onTextChanged: filesTab.filterText = text.toLowerCase()
                            Keys.onEscapePressed: filesTab.closeFilter()
                        }
                        SButton { anchors.verticalCenter: parent.verticalCenter; text: "✕"; variant: "ghost"; onClicked: filesTab.closeFilter() }
                    }
                }
            }

            function commitInline(value) {
                if (renaming.length > 0) PteroFiles.renameEntry(renaming, value)
                else PteroFiles.newFolder(value)
                creatingFolder = false; renaming = ""; nameIn.text = ""
            }

            ListView {
                id: fileList
                anchors.top: fhead.bottom; anchors.topMargin: 10
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                clip: true
                flickDeceleration: 2600
                maximumFlickVelocity: 6000
                model: PteroFiles
                property real accel: 1
                property real lastWheel: 0
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: function (e) {
                        var now = Date.now()
                        fileList.accel = (now - fileList.lastWheel < 90) ? Math.min(fileList.accel + 0.7, 7) : 1.4
                        fileList.lastWheel = now
                        var maxY = Math.max(0, fileList.contentHeight - fileList.height)
                        fileList.contentY = Math.max(0, Math.min(maxY, fileList.contentY - (e.angleDelta.y / 120) * 64 * fileList.accel))
                        e.accepted = true
                    }
                }
                // wrapper owns the 5px row gap (not ListView spacing) so filtered-out
                // rows collapse to zero instead of leaving a stack of gaps
                delegate: Item {
                    readonly property bool shown: filesTab.filterText === "" || name.toLowerCase().indexOf(filesTab.filterText) !== -1
                    width: ListView.view.width
                    height: shown ? 45 : 0
                    visible: shown
                    Rectangle {
                        width: parent.width; height: 40; radius: 9
                        color: fileArea.containsMouse ? "#221a0f" : "#16110a"
                        border.color: fileArea.containsMouse ? "#3a2f1c" : "#221a12"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea {
                            id: fileArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isFile) {
                                    PteroFiles.openFile(name)
                                } else if (!PteroFiles.loading) {
                                    filesTab.navPush()
                                    PteroFiles.enter(name)
                                }
                            }
                        }
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
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: isFile ? view.fmtBytes(size) : ""
                                color: "#6b5d3f"; font.pixelSize: 11
                                visible: !fileArea.containsMouse
                            }
                            SButton { anchors.verticalCenter: parent.verticalCenter; visible: fileArea.containsMouse; text: "Rename"; variant: "ghost"; onClicked: { filesTab.creatingFolder = false; filesTab.renaming = name; nameIn.text = name; nameIn.forceActiveFocus() } }
                            SButton { anchors.verticalCenter: parent.verticalCenter; visible: fileArea.containsMouse; text: "Delete"; variant: "danger"; onClicked: PteroFiles.deleteEntry(name) }
                        }
                    }
                }
            }

            // editor overlay
            Rectangle {
                id: edOverlay
                anchors.fill: parent
                visible: PteroFiles.openPath !== ""
                color: "#0f0a06"

                property bool finding: false
                property var matches: []   // match start offsets
                property int matchIndex: -1

                onVisibleChanged: if (!visible) closeFind()

                function openFind() {
                    finding = true
                    findIn.forceActiveFocus()
                    findIn.selectAll()
                    refind(true)
                }
                function closeFind() {
                    finding = false
                    findIn.text = ""
                    if (visible) editor.forceActiveFocus()
                }
                // plain-text scan, capped so a 1-char query on a huge file can't stall the UI.
                // jump=false when the editor text changed under us — reselecting the first
                // match mid-edit would yank the viewport away from the cursor
                function refind(jump) {
                    matchIndex = -1
                    var q = findIn.text.toLowerCase()
                    if (!finding || q.length === 0) { matches = []; return }
                    var hay = editor.text.toLowerCase()
                    var out = []
                    var i = hay.indexOf(q)
                    while (i !== -1 && out.length < 5000) {
                        out.push(i)
                        i = hay.indexOf(q, i + q.length)
                    }
                    matches = out
                    if (jump && out.length > 0) findStep(1)
                }
                function findStep(dir) {
                    if (matches.length === 0) return
                    matchIndex = matchIndex < 0 ? (dir > 0 ? 0 : matches.length - 1)
                                                : (matchIndex + dir + matches.length) % matches.length
                    var start = matches[matchIndex]
                    editor.select(start, start + findIn.text.length)
                    flick.ensureVisible(editor.positionToRectangle(start))
                }

                Shortcut {
                    sequences: [StandardKey.Save]
                    enabled: filesTab.visible && PteroFiles.openPath !== "" && !PteroFiles.saving
                    onActivated: PteroFiles.save(editor.text)
                }

                Row {
                    id: edBar
                    width: parent.width; height: 36; spacing: 10
                    SButton { text: "Files"; icon: "chevron-left"; variant: "ghost"; onClicked: PteroFiles.closeFile() }
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
                // in-editor find bar (Ctrl+F while a file is open)
                Rectangle {
                    id: findBar
                    anchors.top: edBar.bottom; anchors.topMargin: 6
                    width: parent.width; height: 34; radius: 9
                    visible: edOverlay.finding
                    color: "#15100a"; border.color: findIn.activeFocus ? "#FFB81C" : "#2a2114"; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Find"; color: "#FFE082"; font.pixelSize: 12 }
                        TextInput {
                            id: findIn
                            width: parent.width - 320; anchors.verticalCenter: parent.verticalCenter
                            color: "#F2E8D0"; font.family: "Menlo"; font.pixelSize: 13; clip: true
                            onTextChanged: edOverlay.refind(true)
                            Keys.onReturnPressed: function (e) { edOverlay.findStep(e.modifiers & Qt.ShiftModifier ? -1 : 1) }
                            Keys.onEnterPressed: function (e) { edOverlay.findStep(e.modifiers & Qt.ShiftModifier ? -1 : 1) }
                            Keys.onEscapePressed: edOverlay.closeFind()
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: edOverlay.matches.length === 0 ? "0/0"
                                : (edOverlay.matchIndex + 1) + "/" + edOverlay.matches.length + (edOverlay.matches.length >= 5000 ? "+" : "")
                            color: "#6b5d3f"; font.family: "Menlo"; font.pixelSize: 11
                        }
                        SButton { anchors.verticalCenter: parent.verticalCenter; compact: true; text: "Prev"; variant: "ghost"; onClicked: edOverlay.findStep(-1) }
                        SButton { anchors.verticalCenter: parent.verticalCenter; compact: true; text: "Next"; variant: "ghost"; onClicked: edOverlay.findStep(1) }
                        SButton { anchors.verticalCenter: parent.verticalCenter; compact: true; text: "✕"; variant: "ghost"; onClicked: edOverlay.closeFind() }
                    }
                }
                Text {
                    id: edErr
                    anchors.top: findBar.visible ? findBar.bottom : edBar.bottom; anchors.topMargin: 6
                    text: PteroFiles.editorError; color: "#e06c6c"; font.pixelSize: 12
                    visible: PteroFiles.editorError.length > 0
                }
                Rectangle {
                    anchors.top: edErr.visible ? edErr.bottom : (findBar.visible ? findBar.bottom : edBar.bottom); anchors.topMargin: 10
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    radius: 13; color: "#0a0805"; border.color: "#2a2114"; border.width: 1
                    Flickable {
                        id: flick
                        anchors.fill: parent; anchors.margins: 12
                        clip: true
                        flickDeceleration: 2600
                        maximumFlickVelocity: 6000
                        contentWidth: editor.width; contentHeight: editor.height
                        property real accel: 1
                        property real lastWheel: 0
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse
                            onWheel: function (e) {
                                var now = Date.now()
                                flick.accel = (now - flick.lastWheel < 90) ? Math.min(flick.accel + 0.7, 7) : 1.4
                                flick.lastWheel = now
                                var maxY = Math.max(0, flick.contentHeight - flick.height)
                                flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - (e.angleDelta.y / 120) * 64 * flick.accel))
                                e.accepted = true
                            }
                        }
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
                            onTextChanged: if (edOverlay.finding) edOverlay.refind(false)
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
