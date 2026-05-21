// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

namespace Jarton {

class DiscordWidgetService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(int presenceCount READ presenceCount NOTIFY changed)
    Q_PROPERTY(QString inviteUrl READ inviteUrl NOTIFY changed)

   public:
    explicit DiscordWidgetService(const QString& guildId, QObject* parent = nullptr);
    ~DiscordWidgetService() override;

    bool available() const { return m_available; }
    int presenceCount() const { return m_presenceCount; }
    QString inviteUrl() const { return m_inviteUrl; }

    Q_INVOKABLE void refreshNow();

   signals:
    void changed();

   private slots:
    void onReplyFinished();

   private:
    QString m_guildId;
    QNetworkAccessManager* m_nam = nullptr;
    QNetworkReply* m_inFlight = nullptr;
    QTimer* m_timer = nullptr;
    bool m_available = false;
    int m_presenceCount = 0;
    QString m_inviteUrl;
    int m_consecutiveFailures = 0;
};

}  // namespace Jarton
