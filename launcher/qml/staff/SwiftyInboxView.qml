import QtQuick
import Jarton

// Swifty inbox: the notification feed (/notifications) plus the per-account notification
// settings that live on /users/me's settings JSON. Mirrors the app's Inbox tab — scoped
// to Swifty, so it's only meaningful once the Swifty session is connected.
Item {
    id: inbox

    property var notes: []
    property bool loadedOnce: false
    property bool showSettings: false

    property var settingsObj: ({})
    property bool sLoaded: false
    // mirrored notification toggles
    property bool pushEnabled: true
    property bool pushCreated: true
    property bool pushUpdated: true
    property bool pushMoved: true
    property bool pushCompleted: true
    property bool discordPing: false
    property bool inAppPopups: true

    property int reqNotes: -1
    property int reqMe: -1
    property int reqSave: -1

    Component.onCompleted: load()

    function load() { reqNotes = SwiftyApi.send("GET", "/notifications?limit=50") }
    function loadSettings() { reqMe = SwiftyApi.send("GET", "/users/me") }
    function relTime(iso) {
        if (!iso) return ""
        var t = Date.parse(iso); if (isNaN(t)) return ""
        var d = Date.now() - t
        var days = Math.floor(d / 86400000); if (days > 0) return days + "d ago"
        var h = Math.floor(d / 3600000); if (h > 0) return h + "h ago"
        return Math.max(1, Math.floor(d / 60000)) + "m ago"
    }
    function applySettings(u) {
        try { settingsObj = u.settings ? JSON.parse(u.settings) : {} } catch (e) { settingsObj = {} }
        var n = settingsObj.notifications || {}
        var p = n.push || {}
        pushEnabled = p.enabled !== false
        pushCreated = p.cardCreated !== false
        pushUpdated = p.cardUpdated !== false
        pushMoved = p.cardMoved !== false
        pushCompleted = p.cardCompleted !== false
        discordPing = n.discordAssignedCardChanges === true
        inAppPopups = n.webInAppPopups !== false
        sLoaded = true
    }
    function save() {
        if (!sLoaded) return
        var s = settingsObj || {}
        var n = s.notifications || {}
        n.discordAssignedCardChanges = discordPing
        n.webInAppPopups = inAppPopups
        n.push = { enabled: pushEnabled, cardCreated: pushCreated, cardUpdated: pushUpdated, cardMoved: pushMoved, cardCompleted: pushCompleted }
        s.notifications = n; settingsObj = s
        reqSave = SwiftyApi.send("PATCH", "/users/me", JSON.stringify({ settings: s }))
    }
    function openSettings() { showSettings = true; if (!sLoaded) loadSettings() }

    Connections {
        target: SwiftyApi
        function onResponse(id, ok, status, body) {
            if (id === inbox.reqNotes) {
                inbox.loadedOnce = true
                if (ok) { try { inbox.notes = JSON.parse(body) || [] } catch (e) { inbox.notes = [] } }
                return
            }
            if (id === inbox.reqMe) {
                if (ok) { try { inbox.applySettings(JSON.parse(body)) } catch (e) {} }
                return
            }
        }
    }

    // ---- feed ----
    Item {
        anchors.fill: parent; visible: !inbox.showSettings

        Item {
            id: ihead; width: parent.width; height: 34
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Inbox"; color: "#F2E8D0"; font.pixelSize: 20; font.bold: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                SButton { text: "Settings"; glyph: "⚙"; variant: "secondary"; onClicked: inbox.openSettings() }
                SButton { text: "Refresh"; glyph: "↻"; variant: "secondary"; onClicked: inbox.load() }
            }
        }
        ListView {
            anchors.top: ihead.bottom; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            clip: true; spacing: 8
            model: inbox.notes
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: nCol.height + 22; radius: 12
                color: (modelData.readAt ? "#130e08" : "#1b150d"); border.color: "#241c12"; border.width: 1
                Rectangle {
                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.top: parent.top; anchors.topMargin: 14
                    width: 8; height: 8; radius: 4; color: modelData.readAt ? "transparent" : "#FFB81C"
                }
                Column {
                    id: nCol
                    anchors.left: parent.left; anchors.leftMargin: 30; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { width: parent.width; text: modelData.title ? modelData.title : "Notification"; color: "#F2E8D0"; font.pixelSize: 14; font.bold: true; wrapMode: Text.WordWrap }
                    Text { width: parent.width; visible: !!modelData.body && modelData.body.length > 0; text: modelData.body ? modelData.body : ""; color: "#cfc3a6"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    Text { text: inbox.relTime(modelData.createdAt); color: "#6b5d3f"; font.pixelSize: 11 }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: modelData.deepLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (modelData.deepLink) Qt.openUrlExternally(modelData.deepLink)
                }
            }
            Text { anchors.centerIn: parent; visible: inbox.loadedOnce && inbox.notes.length === 0; text: "You're all caught up."; color: "#6b5d3f"; font.pixelSize: 14 }
        }
    }

    // ---- settings ----
    Item {
        anchors.fill: parent; visible: inbox.showSettings

        Item {
            id: shead; width: parent.width; height: 34
            SButton { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Inbox"; glyph: "‹"; variant: "ghost"; onClicked: inbox.showSettings = false }
            Text { anchors.centerIn: parent; text: "Notifications"; color: "#F2E8D0"; font.pixelSize: 18; font.bold: true }
        }

        Flickable {
            anchors.top: shead.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            contentWidth: width; contentHeight: setCol.height; clip: true

            Column {
                id: setCol
                width: parent.width; spacing: 10

                component Toggle: Rectangle {
                    id: tg
                    property string label: ""
                    property bool on: false
                    signal flipped()
                    width: setCol.width; height: 42; radius: 10; color: "#15100a"; border.color: "#241c12"; border.width: 1
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: tg.label; color: "#F2E8D0"; font.pixelSize: 13 }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 24; radius: 12
                        color: tg.on ? "#FFB81C" : "#2a2114"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "#0f0a06"; anchors.verticalCenter: parent.verticalCenter
                            x: tg.on ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.flipped() }
                    }
                }

                Text { text: "SWIFTY · PUSH TO THIS DEVICE"; color: "#FFB81C"; font.pixelSize: 11; font.bold: true }
                Toggle { label: "Push notifications"; on: inbox.pushEnabled; onFlipped: { inbox.pushEnabled = !inbox.pushEnabled; inbox.save() } }
                Toggle { visible: inbox.pushEnabled; label: "Cards assigned to me"; on: inbox.pushCreated; onFlipped: { inbox.pushCreated = !inbox.pushCreated; inbox.save() } }
                Toggle { visible: inbox.pushEnabled; label: "Card updates"; on: inbox.pushUpdated; onFlipped: { inbox.pushUpdated = !inbox.pushUpdated; inbox.save() } }
                Toggle { visible: inbox.pushEnabled; label: "Card moved"; on: inbox.pushMoved; onFlipped: { inbox.pushMoved = !inbox.pushMoved; inbox.save() } }
                Toggle { visible: inbox.pushEnabled; label: "Card completed"; on: inbox.pushCompleted; onFlipped: { inbox.pushCompleted = !inbox.pushCompleted; inbox.save() } }

                Item { width: 1; height: 6 }
                Text { text: "SWIFTY · OTHER CHANNELS"; color: "#FFB81C"; font.pixelSize: 11; font.bold: true }
                Toggle { label: "Discord ping on assigned card changes"; on: inbox.discordPing; onFlipped: { inbox.discordPing = !inbox.discordPing; inbox.save() } }
                Toggle { label: "In-app popups"; on: inbox.inAppPopups; onFlipped: { inbox.inAppPopups = !inbox.inAppPopups; inbox.save() } }

                Text {
                    width: parent.width; topPadding: 6
                    text: "These control Swifty board and card notifications. You'll still see everything in the Inbox."
                    color: "#6b5d3f"; font.pixelSize: 11; wrapMode: Text.WordWrap
                }
            }
        }
    }
}
