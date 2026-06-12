// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QWidget>

class QLabel;

namespace Jarton {

class ServerStatusService;
class DiscordWidgetService;

class StatsTile : public QWidget {
    Q_OBJECT
   public:
    StatsTile(const QString& label, const QString& accent, QWidget* parent = nullptr);
    void setValue(const QString& value);
    void setSubtitle(const QString& subtitle);

   protected:
    void paintEvent(QPaintEvent* event) override;

   private:
    QLabel* m_value = nullptr;
    QLabel* m_subtitle = nullptr;
};

class StatsOverlayWidget : public QWidget {
    Q_OBJECT
   public:
    StatsOverlayWidget(ServerStatusService* status, DiscordWidgetService* discord, QWidget* parent = nullptr);

   private slots:
    void onStatusChanged();
    void onDiscordChanged();

   private:
    ServerStatusService* m_status = nullptr;
    DiscordWidgetService* m_discord = nullptr;
    StatsTile* m_playersTile = nullptr;
    StatsTile* m_discordTile = nullptr;
};

}  // namespace Jarton
