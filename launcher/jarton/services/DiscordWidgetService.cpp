// SPDX-License-Identifier: GPL-3.0-only
#include "DiscordWidgetService.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>

Q_LOGGING_CATEGORY(jartonDiscord, "jarton.discord")

namespace Jarton {

namespace {
constexpr int g_pollIntervalMs = 60 * 1000;
constexpr int g_requestTimeoutMs = 8 * 1000;
constexpr int g_failuresUntilHidden = 3;
}  // namespace

DiscordWidgetService::DiscordWidgetService(const QString& guildId, QObject* parent)
    : QObject(parent), m_guildId(guildId), m_nam(new QNetworkAccessManager(this)), m_timer(new QTimer(this))
{
    m_timer->setInterval(g_pollIntervalMs);
    connect(m_timer, &QTimer::timeout, this, &DiscordWidgetService::refreshNow);
    QTimer::singleShot(0, this, &DiscordWidgetService::refreshNow);
    m_timer->start();
}

DiscordWidgetService::~DiscordWidgetService() = default;

void DiscordWidgetService::refreshNow()
{
    if (m_inFlight != nullptr || m_guildId.isEmpty()) {
        return;
    }
    const QString url = QStringLiteral("https://discord.com/api/guilds/%1/widget.json").arg(m_guildId);
    QNetworkRequest req{ QUrl(url) };
    req.setRawHeader("User-Agent", "JartonClient/1.0");
    req.setTransferTimeout(g_requestTimeoutMs);
    m_inFlight = m_nam->get(req);
    connect(m_inFlight, &QNetworkReply::finished, this, &DiscordWidgetService::onReplyFinished);
}

void DiscordWidgetService::onReplyFinished()
{
    QNetworkReply* reply = m_inFlight;
    m_inFlight = nullptr;
    if (reply == nullptr) {
        return;
    }
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(jartonDiscord) << "widget fetch failed:" << reply->errorString()
                                 << "(code" << reply->error() << ") guild=" << m_guildId;
        m_consecutiveFailures++;
        if (m_consecutiveFailures >= g_failuresUntilHidden) {
            m_available = false;
            emit changed();
        }
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        qCWarning(jartonDiscord) << "widget response is not a JSON object; guild=" << m_guildId;
        m_consecutiveFailures++;
        return;
    }
    const QJsonObject root = doc.object();

    m_presenceCount = root.value("presence_count").toInt(0);
    m_inviteUrl = root.value("instant_invite").toString();
    m_available = true;
    m_consecutiveFailures = 0;
    emit changed();
}

}  // namespace Jarton
