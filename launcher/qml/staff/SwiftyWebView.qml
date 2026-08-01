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

    // driven from the toolbar's Reload action (the webview eats clicks over itself,
    // so there is no in-view reload affordance)
    function reloadPage() {
        root.failed = false
        web.reload()
    }

    Rectangle { anchors.fill: parent; color: "#0f0a06" }  // dark backstop while the page paints

    // the native webview composites above QML, so the timezone note can't overlay it —
    // reserve a thin strip below the page for it instead
    // desktop-density zoom: the page renders noticeably larger in the native webview
    // than in a browser. The toolbar Zoom action drives this via setZoom (persisted
    // C++-side); applied per load, SPA route changes keep the style on the document.
    property real pageZoom: 0.8

    // Zoom via the CSS `zoom` property on BOTH engines — never `transform: scale()`. `zoom`
    // is coordinate-safe: pointer events, hit-testing and getBoundingClientRect all account
    // for it, which the board's drag-and-drop needs. The old Chromium path used a transform,
    // which left the dragged card offset from the cursor, clipped the board when dragging to
    // the edge, and tore the background during drag repaints — all fixed by using `zoom`.
    // WebKit (macOS) reflows to fill on its own. Chromium doesn't, so we widen the root by 1/z
    // and force Swifty's `main` (h-screen) layer to (100/z)vh so the board still covers after
    // zooming. One injected function so SPA route changes reapply it.
    function zoomScript(z) {
        return "(function(z){var d=document.documentElement;"
             + "var wk=/AppleWebKit/.test(navigator.userAgent)&&!/Chrome|Chromium|Edg/.test(navigator.userAgent);"
             + "var sid='swifty-zoom-fill';var s=document.getElementById(sid);"
             + "if(!s){s=document.createElement('style');s.id=sid;document.head.appendChild(s);}"
             + "d.style.transform='';d.style.transformOrigin='';"  // undo the old transform hack
             + "if(z==1){d.style.zoom='';d.style.width='';d.style.height='';s.textContent='';}"
             + "else if(wk){d.style.zoom=z;d.style.width='';d.style.height='';s.textContent='';}"
             + "else{d.style.zoom=z;d.style.width=(100/z)+'vw';d.style.height=(100/z)+'vh';s.textContent='main{height:'+(100/z)+'vh!important}';}"
             + "})(" + z + ");"
    }

    function setZoom(z) {
        pageZoom = z
        web.runJavaScript(zoomScript(z))
    }

    WebView {
        id: web
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: tzBar.top
        url: root.homeUrl
        onLoadingChanged: function (req) {
            if (req.status === WebView.LoadFailedStatus) {
                root.failed = true
            } else if (req.status === WebView.LoadSucceededStatus) {
                root.failed = false
                web.runJavaScript(root.zoomScript(root.pageZoom))
            }
        }
    }

    // timezone disclaimer strip — Swifty renders its own times inside the web app,
    // which the client can't reformat, so this is honest about that. The reload and
    // pop-out controls are toolbar actions (MainWindow) — nothing floated over or
    // beside the webview receives clicks reliably.
    Rectangle {
        id: tzBar
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 22; color: "#120d07"; border.color: "#241c12"; border.width: 1
        Text {
            anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
            text: "Swifty times are shown in the app's own timezone"
            color: "#6b5d3f"; font.pixelSize: 11
        }
        // honey load bar rides the top edge of the strip
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left
            height: 2
            width: parent.width * Math.max(0, Math.min(1, web.loadProgress / 100))
            color: "#FFB81C"
            visible: web.loading
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
