import QtQuick
import Jarton

// Player management landing: a face grid — online players first, then everyone
// by recency (/proctor/players/browse, paged) — with collapsible sections;
// typing searches everyone who has ever joined. Opening a player loads
// PlayerDetailView fresh via the Loader so per-player state never leaks.
Item {
    id: view

    property string selUuid: ""
    property string selName: ""

    // online roster (fallback landing list, old brokers only)
    property var online: []
    property int reqOnline: -1

    // face browse (online grid + everyone-else by recency)
    property var browse: []
    property int browseOffset: 0
    property bool browseLoading: false
    property bool browseEnd: false
    property bool browseSupported: true
    property int reqBrowse: -1
    property bool onlineOpen: true
    property bool offlineOpen: true
    // 120 comfortably fills four+ rows of 92px cells at typical widths
    readonly property int pageSize: 120
    readonly property var onlineBrowse: browse.filter(function (p) { return p.online === true })
    readonly property var offlineBrowse: browse.filter(function (p) { return p.online !== true })

    function relTime(v) { return TimeFmt.rel(v) }
    function lastSeenMs(v) { return v }   // TimeFmt.rel takes the raw value (string or ms) directly

    function openPlayer(uuid, name) { selUuid = uuid; selName = name }

    Component.onCompleted: loadBrowse()
    function loadOnline() { reqOnline = ProctorApi.send("GET", "/proctor/online") }
    function loadBrowse() {
        if (browseLoading || browseEnd || !browseSupported) return
        browseLoading = true
        reqBrowse = ProctorApi.send("GET", "/proctor/players/browse?limit=" + pageSize + "&offset=" + browseOffset)
    }
    function resetBrowse() {
        if (!browseSupported) { loadOnline(); return }
        browse = []; browseOffset = 0; browseEnd = false
        loadBrowse()
    }

    // background presence refresh: re-reads everything loaded so far in one
    // request and swaps it in only when the payload actually changed
    readonly property int autoRefreshMs: 30000
    property int quietReq: -1
    property int quietLimit: 0
    property string lastQuietPayload: ""
    function quietRefresh() {
        if (!browseSupported) { loadOnline(); return }
        if (browseLoading || quietReq !== -1) return
        quietLimit = Math.min(200, Math.max(pageSize, browse.length))
        quietReq = ProctorApi.send("GET", "/proctor/players/browse?limit=" + quietLimit + "&offset=0")
    }
    Timer {
        interval: view.autoRefreshMs; repeat: true
        running: view.visible && view.selUuid === "" && searchInput.text.length === 0
        onTriggered: view.quietRefresh()
    }

    Timer { id: debounce; interval: 280; onTriggered: PlayerSearchModel.search(searchInput.text) }

    component SectionHead: Item {
        id: head
        property string title: ""
        property int count: -1
        property bool open: true
        signal toggled()
        width: parent.width; height: 24
        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: head.title + (head.count >= 0 ? " · " + head.count : "")
                color: "#FFB833"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/jarton/staff/icons/ui/chevron-up-cream.svg"
                width: 11; height: 11; sourceSize: Qt.size(22, 22)
                rotation: head.open ? 180 : 90
                Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: head.toggled() }
    }

    component FaceCell: Rectangle {
        id: cell
        property var p: ({})
        width: 92; height: 106; radius: 12
        color: cellHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
        Behavior on color { ColorAnimation { duration: 100 } }
        Column {
            anchors.top: parent.top; anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Item {
                width: 56; height: 56
                anchors.horizontalCenter: parent.horizontalCenter
                Avatar { anchors.fill: parent; size: 56; uuid: cell.p.uuid || "" }
                Rectangle {
                    visible: cell.p.online === true
                    width: 16; height: 16; radius: 8
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: -3; anchors.bottomMargin: -3
                    color: "#3BA55D"; border.color: "#0f0a06"; border.width: 3
                }
            }
            Text {
                width: 80; horizontalAlignment: Text.AlignHCenter
                text: cell.p.name || ""; color: "#FFFFFF"; font.pixelSize: 12; font.bold: true; elide: Text.ElideMiddle
            }
            Text {
                visible: cell.p.online !== true && text.length > 0
                width: 80; horizontalAlignment: Text.AlignHCenter
                text: view.relTime(view.lastSeenMs(cell.p.lastSeen))
                color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 10
            }
        }
        MouseArea {
            id: cellHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: view.openPlayer(cell.p.uuid, cell.p.name)
        }
    }

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
            if (id === view.quietReq) {
                view.quietReq = -1
                if (!ok || body === view.lastQuietPayload) return
                view.lastQuietPayload = body
                try {
                    var fresh = JSON.parse(body).players || []
                    var y = browseFlick.contentY
                    view.browse = fresh
                    view.browseOffset = fresh.length
                    view.browseEnd = fresh.length < view.quietLimit
                    Qt.callLater(function () {
                        browseFlick.contentY = Math.max(0, Math.min(y, browseFlick.contentHeight - browseFlick.height))
                    })
                } catch (e) {}
                return
            }
            if (id === view.reqBrowse) {
                view.browseLoading = false
                if (ok) {
                    try {
                        var ps = JSON.parse(body).players || []
                        view.browse = view.browse.concat(ps)
                        view.browseOffset += ps.length
                        if (ps.length < view.pageSize) view.browseEnd = true
                    } catch (e) { view.browseEnd = true }
                } else {
                    // old broker without the browse route — fall back to the plain online list
                    view.browseSupported = false
                    view.loadOnline()
                }
            }
        }
    }

    // =========================== LANDING: search + browse ===========================
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

            // section label (search results + the no-browse fallback list)
            Text {
                visible: searchInput.text.length > 0 || !view.browseSupported
                text: searchInput.text.length > 0 ? "RESULTS" : ("ONLINE · " + view.online.length)
                color: "#FFB833"; font.pixelSize: 11; font.bold: true
            }

            // face browse: online grid, then everyone else by recency
            Flickable {
                id: browseFlick
                width: parent.width; height: parent.height - 56
                visible: searchInput.text.length === 0 && view.browseSupported
                contentWidth: width; contentHeight: browseCol.height + 8; clip: true
                boundsBehavior: Flickable.StopAtBounds
                onContentYChanged: if (view.offlineOpen && contentY + height > contentHeight - 400) view.loadBrowse()

                Column {
                    id: browseCol
                    width: parent.width; spacing: 12

                    SectionHead {
                        title: "ONLINE"; count: view.onlineBrowse.length; open: view.onlineOpen
                        onToggled: view.onlineOpen = !view.onlineOpen
                    }
                    Text {
                        visible: view.onlineOpen && view.onlineBrowse.length === 0 && !view.browseLoading
                        text: "Nobody is online right now."
                        color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 14
                    }
                    Flow {
                        width: parent.width; spacing: 10
                        visible: view.onlineOpen
                        Repeater {
                            model: view.onlineOpen ? view.onlineBrowse : []
                            delegate: FaceCell { required property var modelData; p: modelData }
                        }
                    }

                    Item { width: 1; height: 4; visible: view.offlineBrowse.length > 0 }
                    SectionHead {
                        title: "OFFLINE"; count: view.offlineBrowse.length; open: view.offlineOpen
                        visible: view.offlineBrowse.length > 0
                        onToggled: view.offlineOpen = !view.offlineOpen
                    }
                    Flow {
                        width: parent.width; spacing: 10
                        visible: view.offlineOpen
                        Repeater {
                            model: view.offlineOpen ? view.offlineBrowse : []
                            delegate: FaceCell { required property var modelData; p: modelData }
                        }
                    }

                    Text {
                        visible: view.browseLoading
                        text: "Loading…"
                        color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 12
                    }
                }
            }

            // online list (no query — fallback when the browse route is unavailable)
            ListView {
                width: parent.width; height: parent.height - 90; clip: true; spacing: 6
                visible: searchInput.text.length === 0 && !view.browseSupported
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
    Loader {
        anchors.fill: parent; anchors.margins: 4
        active: view.selUuid !== ""
        sourceComponent: PlayerDetailView {
            uuid: view.selUuid
            name: view.selName
            onClosed: { view.selUuid = ""; view.resetBrowse() }
        }
    }
}
