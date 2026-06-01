// SPDX-License-Identifier: GPL-3.0-only
#include "ChangelogService.h"

#include <QLoggingCategory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>

Q_LOGGING_CATEGORY(jartonChangelog, "jarton.changelog")

namespace Jarton {

namespace {
constexpr int g_refreshIntervalMs = 15 * 60 * 1000;
constexpr int g_requestTimeoutMs = 10 * 1000;
// Mirrored from JartonMC-Wiki/docs/changelog/index.md on every push via the
// CDN repo's sync workflow. Public raw URL so the launcher can poll without
// auth even though the source wiki is private.
const char* const g_defaultEndpoint =
    "https://raw.githubusercontent.com/JartonMC/jarton-launcher-cdn/main/launcher/changelog.md";
}  // namespace

ChangelogService::ChangelogService(QObject* parent)
    : QObject(parent),
      m_nam(new QNetworkAccessManager(this)),
      m_timer(new QTimer(this)),
      m_endpoint(QString::fromLatin1(g_defaultEndpoint))
{
    m_timer->setInterval(g_refreshIntervalMs);
    connect(m_timer, &QTimer::timeout, this, &ChangelogService::refreshNow);
    QTimer::singleShot(0, this, &ChangelogService::refreshNow);
    m_timer->start();
}

ChangelogService::~ChangelogService() = default;

void ChangelogService::setEndpointUrl(const QString& url)
{
    if (m_endpoint == url) {
        return;
    }
    m_endpoint = url;
    refreshNow();
}

void ChangelogService::refreshNow()
{
    if (m_inFlight != nullptr) {
        return;
    }
    QNetworkRequest req{ QUrl(m_endpoint) };
    req.setRawHeader("User-Agent", "JartonClient/1.0");
    req.setTransferTimeout(g_requestTimeoutMs);
    m_inFlight = m_nam->get(req);
    connect(m_inFlight, &QNetworkReply::finished, this, &ChangelogService::onReplyFinished);
}

void ChangelogService::onReplyFinished()
{
    QNetworkReply* reply = m_inFlight;
    m_inFlight = nullptr;
    if (reply == nullptr) {
        return;
    }
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(jartonChangelog) << "fetch failed:" << reply->errorString()
                                   << "(code" << reply->error() << ") url=" << m_endpoint;
        return;
    }
    const QString fetched = QString::fromUtf8(reply->readAll());
    if (fetched.isEmpty() || fetched == m_markdown) {
        return;
    }
    m_markdown = fetched;
    emit changed();
}

}  // namespace Jarton
