// SPDX-License-Identifier: GPL-3.0-only
#include "ChangelogPanel.h"

#include <QDesktopServices>
#include <QEvent>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPixmap>
#include <QPropertyAnimation>
#include <QRegularExpression>
#include <QScrollBar>
#include <QTextBrowser>
#include <QTextDocument>
#include <QTextOption>
#include <QTimer>
#include <QVBoxLayout>

#include "services/ChangelogService.h"

namespace Jarton {

namespace {
constexpr int g_driftIntervalMs = 60;
constexpr int g_pauseAtBottomMs = 3500;
constexpr int g_returnDurationMs = 1600;
}  // namespace

// QTextBrowser subclass that asks our panel to fetch network image resources.
class NetworkTextBrowser : public QTextBrowser {
   public:
    explicit NetworkTextBrowser(ChangelogPanel* panel, QWidget* parent = nullptr)
        : QTextBrowser(parent), m_panel(panel)
    {}

    QVariant loadResource(int type, const QUrl& name) override
    {
        if (type == QTextDocument::ImageResource && (name.scheme() == "http" || name.scheme() == "https")) {
            // Trigger an async fetch; return whatever's in the document cache
            // for now (empty for the first request — refresh after load).
            QMetaObject::invokeMethod(m_panel, "requestImage", Qt::QueuedConnection, Q_ARG(QUrl, name));
            return {};
        }
        return QTextBrowser::loadResource(type, name);
    }

   private:
    ChangelogPanel* m_panel = nullptr;
};

ChangelogPanel::ChangelogPanel(ChangelogService* service, QWidget* parent)
    : QFrame(parent),
      m_service(service),
      m_drift(new QTimer(this)),
      m_pause(new QTimer(this)),
      m_nam(new QNetworkAccessManager(this))
{
    setAttribute(Qt::WA_StyledBackground, true);
    setObjectName("jartonChangelogPanel");
    setStyleSheet(
        "#jartonChangelogPanel {"
        "  background: rgba(26, 20, 14, 0.40);"
        "  border: 1px solid rgba(255, 184, 28, 0.42);"
        "  border-radius: 22px;"
        "}");

    auto* lay = new QVBoxLayout(this);
    lay->setContentsMargins(20, 18, 28, 18);
    lay->setSpacing(0);

    m_text = new NetworkTextBrowser(this, this);
    m_text->setOpenExternalLinks(true);
    m_text->setReadOnly(true);
    m_text->setFrameShape(QFrame::NoFrame);
    m_text->setAttribute(Qt::WA_TranslucentBackground);
    m_text->viewport()->setAutoFillBackground(false);
    m_text->setStyleSheet(
        "QTextBrowser { background: transparent; color: #D8D8D8; padding-right: 4px; }"
        "QScrollBar:vertical { background: transparent; width: 8px; margin: 4px 0; }"
        "QScrollBar::handle:vertical { background: rgba(255, 184, 28, 0.45); border-radius: 4px; min-height: 30px; }"
        "QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }"
        "QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: transparent; }");
    // Use the system default font. Qt does automatic font substitution for
    // emoji glyphs on macOS, so don't list Apple Color Emoji as a primary
    // family — that forces it to render normal text and produces grotesque
    // per-character spacing.
    QFont font;
    font.setPixelSize(13);
    m_text->setFont(font);
    // Wrap long lines at the panel width so they break onto a new line instead of
    // running under the rounded border; never scroll sideways.
    m_text->setLineWrapMode(QTextEdit::WidgetWidth);
    m_text->setWordWrapMode(QTextOption::WrapAtWordBoundaryOrAnywhere);
    m_text->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    lay->addWidget(m_text);

    m_drift->setInterval(g_driftIntervalMs);
    connect(m_drift, &QTimer::timeout, this, &ChangelogPanel::onDriftTick);
    m_drift->start();

    m_pause->setSingleShot(true);
    m_pause->setInterval(g_pauseAtBottomMs);
    connect(m_pause, &QTimer::timeout, this, &ChangelogPanel::onPauseFinished);

    m_returnAnim = new QPropertyAnimation(m_text->verticalScrollBar(), "value", this);
    m_returnAnim->setDuration(g_returnDurationMs);
    m_returnAnim->setEasingCurve(QEasingCurve::InOutQuad);

    m_text->viewport()->installEventFilter(this);
    m_text->verticalScrollBar()->installEventFilter(this);

    if (m_service != nullptr) {
        connect(m_service, &ChangelogService::changed, this, &ChangelogPanel::onMarkdownChanged);
        applyMarkdown();
    }
}

void ChangelogPanel::requestImage(const QUrl& url)
{
    if (m_pendingImages.contains(url)) {
        return;
    }
    QNetworkRequest req(url);
    // Default follows safe redirects; bump the max so GitHub user-attachment
    // chains complete.
    req.setMaximumRedirectsAllowed(10);
    req.setRawHeader("User-Agent", "JartonClient/1.0");
    QNetworkReply* reply = m_nam->get(req);
    m_pendingImages.insert(url, reply);
    connect(reply, &QNetworkReply::finished, this, &ChangelogPanel::onImageFinished);
}

void ChangelogPanel::onImageFinished()
{
    auto* reply = qobject_cast<QNetworkReply*>(sender());
    if (reply == nullptr) {
        return;
    }
    const QUrl url = reply->request().url();
    m_pendingImages.remove(url);
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
        return;
    }
    QImage img;
    if (!img.loadFromData(reply->readAll())) {
        return;
    }
    m_text->document()->addResource(QTextDocument::ImageResource, url, img);
    // Force a full layout pass — markContentsDirty alone isn't enough for
    // QTextBrowser to reflow around the newly-sized image.
    const int prevScroll = m_text->verticalScrollBar()->value();
    m_text->document()->markContentsDirty(0, m_text->document()->characterCount());
    m_text->setLineWrapColumnOrWidth(m_text->lineWrapColumnOrWidth());  // nudge layout
    m_text->document()->adjustSize();
    m_text->verticalScrollBar()->setValue(prevScroll);
}

void ChangelogPanel::onMarkdownChanged()
{
    applyMarkdown();
}

void ChangelogPanel::applyMarkdown()
{
    if (m_service == nullptr) {
        return;
    }
    QString md = m_service->markdown();
    if (md.isEmpty()) {
        m_text->setHtml("<p style='color:#888;font-style:italic;'>Loading the latest changelog…</p>");
        return;
    }
    // Strip every image — HTML <img>, markdown ![alt](url), and raw
    // image links. Half of them are tiny inline icons that look broken
    // when rendered in the panel; if you want a banner, view it in
    // Discord. Emojis are unicode by this point so they survive.
    md.replace(QRegularExpression("<img[^>]*/?>", QRegularExpression::CaseInsensitiveOption), "");
    md.replace(QRegularExpression("!\\[[^\\]]*\\]\\([^\\)]*\\)"), "");

    QTextDocument tmp;
    tmp.setMarkdown(md);
    const QString rawHtml = tmp.toHtml();
    // text-align:left on every block kills Qt's default justify, which was
    // stretching short words across the panel and looking awful.
    const QString css =
        "<style>"
        "  body, p, h1, h2, h3, h4, li, blockquote { text-align: left; }"
        "  body { color: #D8D8D8; }"
        "  h1 { color: #FFE082; font-size: 22px; margin-top: 26px; margin-bottom: 10px; }"
        "  h2 { color: #FFE082; font-size: 18px; margin-top: 22px; margin-bottom: 8px; }"
        "  h3 { color: #FFB81C; font-size: 15px; margin-top: 18px; margin-bottom: 6px; }"
        "  h4 { color: #FFB81C; font-size: 14px; margin-top: 14px; margin-bottom: 4px; }"
        "  p  { margin: 4px 0 6px 0; }"
        "  li { margin-bottom: 2px; }"
        "  strong { color: #FFE082; }"
        "  em { color: #C0B080; }"
        "  code { background: #221911; color: #FFE082; padding: 1px 4px; }"
        "  blockquote { border-left: 3px solid #FFB81C; padding-left: 10px; color: #BCA070; }"
        "  a { color: #FFB81C; }"
        "  hr { margin: 14px 0; }"
        "</style>";
    m_text->setHtml(css + rawHtml);
    m_text->verticalScrollBar()->setValue(0);
}

bool ChangelogPanel::eventFilter(QObject* obj, QEvent* ev)
{
    if (obj == m_text->viewport() || obj == m_text->verticalScrollBar()) {
        if (ev->type() == QEvent::MouseButtonPress) {
            m_userInteracting = true;
            m_pause->stop();
            if (m_returnAnim != nullptr) {
                m_returnAnim->stop();
            }
        } else if (ev->type() == QEvent::MouseButtonRelease) {
            m_userInteracting = false;
        } else if (ev->type() == QEvent::Wheel) {
            m_userInteracting = true;
            QTimer::singleShot(900, this, [this]() { m_userInteracting = false; });
        }
    }
    return QFrame::eventFilter(obj, ev);
}

void ChangelogPanel::onDriftTick()
{
    if (m_userInteracting) {
        return;
    }
    if (m_pause->isActive() || (m_returnAnim != nullptr && m_returnAnim->state() == QAbstractAnimation::Running)) {
        return;
    }
    QScrollBar* bar = m_text->verticalScrollBar();
    const int max = bar->maximum();
    if (max <= 0) {
        return;
    }
    if (bar->value() >= max) {
        m_pause->start();
        return;
    }
    bar->setValue(bar->value() + 1);
}

void ChangelogPanel::onPauseFinished()
{
    QScrollBar* bar = m_text->verticalScrollBar();
    m_returnAnim->stop();
    m_returnAnim->setStartValue(bar->value());
    m_returnAnim->setEndValue(0);
    m_returnAnim->start();
}

}  // namespace Jarton
