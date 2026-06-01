// SPDX-License-Identifier: GPL-3.0-only
#include "JartonManifestService.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QTimer>

Q_LOGGING_CATEGORY(jartonManifest, "jarton.manifest")

namespace Jarton {

namespace {
constexpr int g_refreshIntervalMs = 15 * 60 * 1000;
constexpr int g_requestTimeoutMs = 10 * 1000;
// Default to raw GitHub until Cloudflare Pages is wired at jarton.me/launcher/*.
const char* const g_defaultEndpoint =
    "https://raw.githubusercontent.com/JartonMC/jarton-launcher-cdn/main/launcher/manifest.json";
}  // namespace

JartonManifestService::JartonManifestService(QObject* parent)
    : QObject(parent),
      m_nam(new QNetworkAccessManager(this)),
      m_refreshTimer(new QTimer(this)),
      m_endpoint(QString::fromLatin1(g_defaultEndpoint))
{
    m_refreshTimer->setInterval(g_refreshIntervalMs);
    connect(m_refreshTimer, &QTimer::timeout, this, &JartonManifestService::refreshNow);

    loadFromDiskCache();
    QTimer::singleShot(0, this, &JartonManifestService::refreshNow);
    m_refreshTimer->start();
}

JartonManifestService::~JartonManifestService() = default;

void JartonManifestService::setEndpointUrl(const QString& url)
{
    m_endpoint = url;
}

QString JartonManifestService::cachePath()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(base);
    return base + QStringLiteral("/manifest.cache.json");
}

void JartonManifestService::loadFromDiskCache()
{
    QFile cache(cachePath());
    if (!cache.exists() || !cache.open(QIODevice::ReadOnly)) {
        return;
    }
    const QByteArray bytes = cache.readAll();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        return;
    }
    const Manifest parsed = Manifest::fromJson(doc.object());
    if (!parsed.valid) {
        return;
    }
    m_manifest = parsed;
    m_lastUpdated = QFileInfo(cache).lastModified();
    m_ready = true;
    m_stale = true;  // disk cache is stale until network confirms otherwise
    emit readyChanged();
    emit manifestChanged(true);
}

void JartonManifestService::persistToDiskCache(const QByteArray& bytes)
{
    QFile cache(cachePath());
    if (cache.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        cache.write(bytes);
    }
}

void JartonManifestService::refreshNow()
{
    if (m_inFlight) {
        return;
    }
    QNetworkRequest req{ QUrl(m_endpoint) };
    req.setRawHeader("User-Agent", "JartonClient/1.0");
    req.setTransferTimeout(g_requestTimeoutMs);
    m_inFlight = m_nam->get(req);
    connect(m_inFlight, &QNetworkReply::finished, this, &JartonManifestService::onReplyFinished);
}

void JartonManifestService::onReplyFinished()
{
    QNetworkReply* reply = m_inFlight;
    m_inFlight = nullptr;
    if (!reply) {
        return;
    }
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(jartonManifest) << "fetch failed:" << reply->errorString()
                                  << "(code" << reply->error() << ") url=" << m_endpoint;
        m_consecutiveFailures++;
        emit fetchFailed(reply->errorString());
        emit readyChanged();
        if (!m_ready && m_consecutiveFailures == 1) {
            // No prior cache, first fetch just failed — UI should surface the offline block.
            emit firstLaunchOffline();
        }
        return;
    }

    const QByteArray bytes = reply->readAll();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        m_consecutiveFailures++;
        emit fetchFailed(QStringLiteral("malformed JSON: ") + err.errorString());
        emit readyChanged();
        return;
    }

    const Manifest parsed = Manifest::fromJson(doc.object());
    if (!parsed.valid) {
        m_consecutiveFailures++;
        emit fetchFailed(QStringLiteral("manifest validation failed: ") + parsed.parseWarnings.join(QStringLiteral("; ")));
        emit readyChanged();
        return;
    }

    persistToDiskCache(bytes);

    m_manifest = parsed;
    m_lastUpdated = QDateTime::currentDateTime();
    m_consecutiveFailures = 0;
    m_stale = false;
    m_ready = true;
    emit readyChanged();
    emit manifestChanged(false);
}

}  // namespace Jarton
