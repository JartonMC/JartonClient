// SPDX-License-Identifier: GPL-3.0-only
#include "StatsOverlayWidget.h"

#include <QDesktopServices>
#include <QHBoxLayout>
#include <QLabel>
#include <QMouseEvent>
#include <QPainter>
#include <QPaintEvent>
#include <QUrl>
#include <QVBoxLayout>

#include "services/DiscordWidgetService.h"
#include "services/ServerStatusService.h"

namespace Jarton {

StatsTile::StatsTile(const QString& label, const QString& accent, QWidget* parent) : QWidget(parent)
{
    setAttribute(Qt::WA_TranslucentBackground, true);

    auto* lay = new QVBoxLayout(this);
    lay->setContentsMargins(16, 10, 16, 10);
    lay->setSpacing(0);

    auto* labelText = new QLabel(label, this);
    QFont labelFont = labelText->font();
    labelFont.setPixelSize(10);
    labelFont.setBold(true);
    labelFont.setLetterSpacing(QFont::AbsoluteSpacing, 1.2);
    labelText->setFont(labelFont);
    labelText->setStyleSheet(QString("color: %1; background: transparent; border: none;").arg(accent));

    m_value = new QLabel("—", this);
    QFont valueFont = m_value->font();
    valueFont.setPixelSize(24);
    valueFont.setWeight(QFont::Black);
    m_value->setFont(valueFont);
    m_value->setStyleSheet("color: #FFE082; background: transparent; border: none;");

    m_subtitle = new QLabel(QString{}, this);
    QFont subFont = m_subtitle->font();
    subFont.setPixelSize(11);
    m_subtitle->setFont(subFont);
    m_subtitle->setStyleSheet("color: #888; background: transparent; border: none;");

    lay->addWidget(labelText);
    lay->addWidget(m_value);
    lay->addWidget(m_subtitle);
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

void StatsTile::paintEvent(QPaintEvent* event)
{
    Q_UNUSED(event);
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setBrush(QColor(26, 20, 14));
    p.setPen(Qt::NoPen);
    p.drawRoundedRect(rect(), 12, 12);
}

StatsOverlayWidget::StatsOverlayWidget(ServerStatusService* status, DiscordWidgetService* discord, QWidget* parent)
    : QWidget(parent), m_status(status), m_discord(discord)
{
    setAttribute(Qt::WA_TranslucentBackground, true);

    auto* row = new QHBoxLayout(this);
    row->setContentsMargins(0, 0, 0, 0);
    row->setSpacing(12);

    m_playersTile = new StatsTile(tr("PLAYERS ONLINE"), "#FFB81C", this);
    m_playersTile->setFixedSize(230, 76);
    m_discordTile = new StatsTile(tr("DISCORD"), "#FFB81C", this);
    m_discordTile->setFixedSize(170, 76);

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
}

}  // namespace Jarton
