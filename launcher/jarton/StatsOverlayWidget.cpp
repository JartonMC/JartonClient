// SPDX-License-Identifier: GPL-3.0-only
#include "StatsOverlayWidget.h"

#include <QDesktopServices>
#include <QHBoxLayout>
#include <QLabel>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPaintEvent>
#include <QUrl>
#include <QVBoxLayout>

#include "services/DiscordWidgetService.h"
#include "services/ServerStatusService.h"

namespace Jarton {

StatsTile::StatsTile(const QString& label, const QString& accent, QWidget* parent) : QWidget(parent)
{
    setAttribute(Qt::WA_TranslucentBackground, true);
    setAttribute(Qt::WA_NoSystemBackground, true);

    auto* lay = new QVBoxLayout(this);
    lay->setContentsMargins(12, 6, 12, 6);
    lay->setSpacing(0);

    auto* labelText = new QLabel(label, this);
    QFont labelFont = labelText->font();
    labelFont.setPixelSize(9);
    labelFont.setBold(true);
    labelFont.setLetterSpacing(QFont::AbsoluteSpacing, 1.0);
    labelText->setFont(labelFont);
    labelText->setStyleSheet(QString("color: %1; background: transparent; border: none;").arg(accent));

    m_value = new QLabel("—", this);
    QFont valueFont = m_value->font();
    valueFont.setPixelSize(18);
    valueFont.setWeight(QFont::Black);
    m_value->setFont(valueFont);
    m_value->setStyleSheet("color: #FFE082; background: transparent; border: none;");

    m_subtitle = new QLabel(QString{}, this);
    QFont subFont = m_subtitle->font();
    subFont.setPixelSize(9);
    m_subtitle->setFont(subFont);
    m_subtitle->setStyleSheet("color: #888; background: transparent; border: none;");

    lay->addWidget(labelText);
    lay->addWidget(m_value);
    lay->addWidget(m_subtitle);
}

void StatsTile::paintEvent(QPaintEvent* event)
{
    Q_UNUSED(event);
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing, true);

    QPainterPath path;
    path.addRoundedRect(QRectF(rect()).adjusted(0.5, 0.5, -0.5, -0.5), 10, 10);
    p.fillPath(path, QColor(26, 20, 14));
}

void StatsTile::setValue(const QString& value)
{
    if (m_value != nullptr) {
        m_value->setText(value);
    }
}

void StatsTile::setSubtitle(const QString& subtitle)
{
    if (m_subtitle != nullptr) {
        m_subtitle->setText(subtitle);
    }
}

StatsOverlayWidget::StatsOverlayWidget(ServerStatusService* status, DiscordWidgetService* discord, QWidget* parent)
    : QWidget(parent), m_status(status), m_discord(discord)
{
    setAttribute(Qt::WA_TranslucentBackground, true);
    setAttribute(Qt::WA_NoSystemBackground, true);

    auto* row = new QHBoxLayout(this);
    row->setContentsMargins(0, 0, 0, 0);
    row->setSpacing(10);

    m_playersTile = new StatsTile(tr("PLAYERS ONLINE"), "#FFB81C", this);
    m_playersTile->setFixedSize(180, 60);
    m_discordTile = new StatsTile(tr("DISCORD"), "#FFB81C", this);
    m_discordTile->setFixedSize(130, 60);

    m_discordTile->setCursor(Qt::PointingHandCursor);

    row->addWidget(m_playersTile, 0, Qt::AlignLeft);
    row->addWidget(m_discordTile, 0, Qt::AlignLeft);
    row->addStretch(1);

    if (m_status != nullptr) {
        connect(m_status, &ServerStatusService::statusChanged, this, &StatsOverlayWidget::onStatusChanged);
        onStatusChanged();
    }
    if (m_discord != nullptr) {
        connect(m_discord, &DiscordWidgetService::changed, this, &StatsOverlayWidget::onDiscordChanged);
        onDiscordChanged();
    }
}

void StatsOverlayWidget::onStatusChanged()
{
    if (m_status == nullptr || m_playersTile == nullptr) {
        return;
    }
    const auto state = m_status->state();
    if (state == 1) {
        m_playersTile->setValue(QString("%1 / %2").arg(m_status->playersOnline()).arg(m_status->playersMax()));
        m_playersTile->setSubtitle(tr("on mc.jarton.me"));
    } else if (state == 0) {
        m_playersTile->setValue("—");
        m_playersTile->setSubtitle(tr("Status unknown"));
    } else {
        m_playersTile->setValue("—");
        m_playersTile->setSubtitle(tr("Server offline"));
    }
}

void StatsOverlayWidget::onDiscordChanged()
{
    if (m_discord == nullptr || m_discordTile == nullptr) {
        return;
    }
    if (m_discord->available()) {
        m_discordTile->setValue(QString::number(m_discord->presenceCount()));
        m_discordTile->setSubtitle(tr("online now"));
        m_discordTile->setVisible(true);
    } else {
        m_discordTile->setVisible(false);
    }
    adjustSize();
    update();
}

}  // namespace Jarton
