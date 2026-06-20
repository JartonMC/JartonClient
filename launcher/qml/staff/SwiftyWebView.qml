import QtQuick
import QtWebView
import Jarton

// Swifty, embedded. Rather than reimplement the board UI in QML, this wraps the live
// web app (swifty.jarton.me) in the platform's native webview (WKWebView on macOS,
// WebView2 on Windows) so it's identical to web and stays in sync automatically. We
// load /app directly to skip the marketing landing; Swifty's own login shows in-frame
// the first time, and the native webview persists the session for subsequent launches.
Item {
    id: root
    property url homeUrl: "https://swifty.jarton.me/app"
    property bool failed: false

    Rectangle { anchors.fill: parent; color: "#0f0a06" }  // dark backstop while the page paints

    WebView {
        id: web
        anchors.fill: parent
        url: root.homeUrl
        onLoadingChanged: function (req) {
            if (req.status === WebView.LoadFailedStatus) root.failed = true
            else if (req.status === WebView.LoadSucceededStatus) root.failed = false
        }
    }

    // thin honey load bar across the top
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left
        height: 2
        width: parent.width * Math.max(0, Math.min(1, web.loadProgress / 100))
        color: "#FFB81C"
        visible: web.loading
    }

    // unobtrusive reload, bottom-right (matches the sign-out affordance elsewhere)
    Rectangle {
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 12
        width: 30; height: 30; radius: 15
        color: reloadArea.containsMouse ? "#26200f" : "#1b150e"
        border.color: "#2a2114"; border.width: 1
        opacity: 0.85
        Text { anchors.centerIn: parent; text: "↻"; color: "#9a8a66"; font.pixelSize: 15 }
        MouseArea {
            id: reloadArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.failed = false; web.reload() }
        }
    }

    // load-failure overlay
    Rectangle {
        anchors.fill: parent
        visible: root.failed
        color: "#0f0a06"
        Column {
            anchors.centerIn: parent; spacing: 14; width: 320
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Couldn't reach Swifty"; color: "#FFE082"; font.pixelSize: 18; font.bold: true
            }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: "Check your connection and try again."; color: "#9a8a66"; font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                SButton { text: "Retry"; variant: "primary"; onClicked: { root.failed = false; web.url = root.homeUrl } }
                SButton { text: "Open in browser"; variant: "secondary"; onClicked: Qt.openUrlExternally(root.homeUrl) }
            }
        }
    }
}
