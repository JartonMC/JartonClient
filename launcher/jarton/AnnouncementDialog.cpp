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
    // Translucent background lets the QSS border-radius paint properly —
    // the area outside the rounded rectangle becomes transparent rather
    // than being clipped to a square.
    setAttribute(Qt::WA_StyledBackground, true);
    setAttribute(Qt::WA_TranslucentBackground, true);
    setStyleSheet(
        "#jartonAnnouncementCard {"
        "  background: #1a140e;"
        "  border: 1px solid #FFB81C;"
        "  border-radius: 18px;"
        "}");
    hide();

    auto* lay = new QVBoxLayout(this);
    lay->setContentsMargins(0, 0, 0, 0);
    lay->setSpacing(0);

    m_qml->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_qml->setAttribute(Qt::WA_TranslucentBackground);
    m_qml->setClearColor(Qt::transparent);
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
    }
    if (auto* root = m_qml->rootObject()) {
        QMetaObject::invokeMethod(root, "showIndex", Q_ARG(QVariant, index));
    }
    show();
    raise();
}

void AnnouncementDialog::onCloseRequested()
{
    hide();
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
