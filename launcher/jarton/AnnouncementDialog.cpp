// SPDX-License-Identifier: GPL-3.0-only
#include "AnnouncementDialog.h"

#include <QMetaObject>
#include <QPainterPath>
#include <QPolygon>
#include <QQuickItem>
#include <QQuickWidget>
#include <QRegion>
#include <QResizeEvent>
#include <QVBoxLayout>
#include <QVariant>

namespace Jarton {

AnnouncementDialog::AnnouncementDialog(QWidget* parent) : QFrame(parent), m_qml(new QQuickWidget(this))
{
    setObjectName("jartonAnnouncementCard");
    // Opaque on purpose: the setMask() in resizeEvent does the corner
    // rounding, and translucent child compositing can't be relied on now
    // that widgets stay non-native (AA_DontCreateNativeWidgetSiblings).
    setAttribute(Qt::WA_StyledBackground, true);
    setStyleSheet(
        "#jartonAnnouncementCard {"
        "  background: #14100a;"
        "  border: 1px solid #FFB81C;"
        "  border-radius: 18px;"
        "}");
    hide();

    // dimmed backdrop behind the card; clicking it closes, like any modal
    if (parent != nullptr) {
        m_scrim = new QWidget(parent);
        m_scrim->setObjectName("jartonAnnouncementScrim");
        m_scrim->setAttribute(Qt::WA_StyledBackground, true);
        m_scrim->setStyleSheet("#jartonAnnouncementScrim { background: rgba(8, 6, 3, 184); }");
        m_scrim->hide();
        m_scrim->installEventFilter(this);
        parent->installEventFilter(this);
    }

    auto* lay = new QVBoxLayout(this);
    lay->setContentsMargins(0, 0, 0, 0);
    lay->setSpacing(0);

    m_qml->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_qml->setClearColor(QColor(0x14, 0x10, 0x0a));
    m_qml->setSource(QUrl(QStringLiteral("qrc:/qt/qml/Jarton/AnnouncementPopup.qml")));
    lay->addWidget(m_qml);

    auto wireClose = [this]() {
        if (auto* root = m_qml->rootObject()) {
            connect(root, SIGNAL(closeRequested()), this, SLOT(onCloseRequested()), Qt::UniqueConnection);
        }
    };
    wireClose();
    connect(m_qml, &QQuickWidget::statusChanged, this, [wireClose](QQuickWidget::Status s) {
        if (s == QQuickWidget::Ready) {
            wireClose();
        }
    });
}

void AnnouncementDialog::showAtIndex(int index)
{
    if (auto* host = parentWidget()) {
        const int w = qMin(host->width() - 80, 1100);
        const int h = qMin(host->height() - 80, 720);
        const int x = (host->width() - w) / 2;
        const int y = (host->height() - h) / 2;
        setGeometry(x, y, w, h);
        if (m_scrim != nullptr) {
            m_scrim->setGeometry(host->rect());
            m_scrim->show();
            m_scrim->raise();
        }
    }
    if (auto* root = m_qml->rootObject()) {
        QMetaObject::invokeMethod(root, "showIndex", Q_ARG(QVariant, index));
    }
    show();
    raise();
    emit opened();
}

void AnnouncementDialog::onCloseRequested()
{
    hide();
    if (m_scrim != nullptr) {
        m_scrim->hide();
    }
    emit closed();
}

bool AnnouncementDialog::eventFilter(QObject* watched, QEvent* event)
{
    if (watched == m_scrim && event->type() == QEvent::MouseButtonPress) {
        onCloseRequested();
        return true;
    }
    if (watched == parentWidget() && event->type() == QEvent::Resize && m_scrim != nullptr && m_scrim->isVisible()) {
        m_scrim->setGeometry(parentWidget()->rect());
    }
    return QFrame::eventFilter(watched, event);
}

void AnnouncementDialog::resizeEvent(QResizeEvent* event)
{
    QFrame::resizeEvent(event);
    // QSS border-radius doesn't actually clip child widgets on macOS, so we
    // mask the frame to a rounded rectangle explicitly.
    QPainterPath path;
    path.addRoundedRect(rect(), 18, 18);
    setMask(QRegion(path.toFillPolygon().toPolygon()));
}

}  // namespace Jarton
