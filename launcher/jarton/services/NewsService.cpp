// SPDX-License-Identifier: GPL-3.0-only
#include "NewsService.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>

namespace Jarton {

namespace {
constexpr int g_refreshIntervalMs = 15 * 60 * 1000;
constexpr int g_requestTimeoutMs = 10 * 1000;
const char* const g_defaultEndpoint = "https://jarton.me/launcher/changelog.md";
}  // namespace

NewsService::NewsService(QObject* parent)
    : QObject(parent),
      m_nam(new QNetworkAccessManager(this)),
      m_timer(new QTimer(this)),
      m_endpoint(QString::fromLatin1(g_defaultEndpoint))
{
    m_timer->setInterval(g_refreshIntervalMs);
    connect(m_timer, &QTimer::timeout, this, &NewsService::refreshNow);
    QTimer::singleShot(0, this, &NewsService::refreshNow);
    m_timer->start();
}

NewsService::~NewsService() = default;

void NewsService::setEndpointUrl(const QString& url)
{
    if (m_endpoint == url) {
        return;
    }
    m_endpoint = url;
    refreshNow();
}

void NewsService::refreshNow()
{
    if (m_inFlight != nullptr) {
        return;
    }
    QNetworkRequest req{ QUrl(m_endpoint) };
    req.setRawHeader("User-Agent", "JartonClient/1.0");
    req.setTransferTimeout(g_requestTimeoutMs);
    m_inFlight = m_nam->get(req);
    connect(m_inFlight, &QNetworkReply::finished, this, &NewsService::onReplyFinished);
}

void NewsService::onReplyFinished()
{
    QNetworkReply* reply = m_inFlight;
    m_inFlight = nullptr;
    if (reply == nullptr) {
        return;
    }
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        return;  // keep last-known content
    }

    const QString fetched = QString::fromUtf8(reply->readAll());
    if (fetched.isEmpty() || fetched == m_markdown) {
        return;
    }
    m_markdown = fetched;
    emit changed();
}

}  // namespace Jarton
