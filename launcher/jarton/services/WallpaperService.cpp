// SPDX-License-Identifier: GPL-3.0-only
#include "WallpaperService.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QLoggingCategory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

Q_LOGGING_CATEGORY(jartonWallpaper, "jarton.wallpaper")

#include "ConfigService.h"
#include "JartonManifestService.h"

namespace Jarton {

namespace {
constexpr int g_rotationIntervalMs = 60 * 1000;
constexpr int g_downloadTimeoutMs = 30 * 1000;
const char* const g_fallbackResource = "qrc:/jarton/wallpapers/fallback.jpg";
}  // namespace

WallpaperService::WallpaperService(JartonManifestService* manifest, ConfigService* config, QObject* parent)
    : QObject(parent),
      m_manifest(manifest),
      m_config(config),
      m_nam(new QNetworkAccessManager(this)),
      m_rotateTimer(new QTimer(this))
{
    m_rotateTimer->setInterval(g_rotationIntervalMs);
    connect(m_rotateTimer, &QTimer::timeout, this, &WallpaperService::rotate);

    if (m_manifest) {
        connect(m_manifest, &JartonManifestService::manifestChanged, this, &WallpaperService::onManifestChanged);
        if (m_manifest->ready()) {
            onManifestChanged(m_manifest->stale());
        }
    }
    if (m_config) {
        connect(m_config, &ConfigService::changed, this, &WallpaperService::onConfigChanged);
        onConfigChanged();
    }

    emit currentChanged();  // initial state, even if just the fallback
}

WallpaperService::~WallpaperService() = default;

QString WallpaperService::fallbackUrl()
{
    return QString::fromLatin1(g_fallbackResource);
}

QString WallpaperService::currentUrl() const
{
    return resolvedUrl(m_currentIndex);
}

QString WallpaperService::nextUrl() const
{
    if (m_activeUrls.isEmpty()) {
        return fallbackUrl();
    }
    const int n = (m_currentIndex + 1) % static_cast<int>(m_activeUrls.size());
    return resolvedUrl(n);
}

QString WallpaperService::resolvedUrl(int index) const
{
    if (m_activeUrls.isEmpty() || index < 0 || index >= m_activeUrls.size()) {
        return fallbackUrl();
    }
    QString remote = m_activeUrls.at(index);
    const QString local = localPathFor(remote);
    if (QFileInfo::exists(local)) {
        return QUrl::fromLocalFile(local).toString();
    }
    // Not yet cached. Show the bundled fallback rather than handing the native
    // WallpaperBackground a URL it can't render — onDownloadFinished re-emits
    // currentChanged once the file lands.
    return fallbackUrl();
}

QString WallpaperService::localPathFor(const QString& url)
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const QString dir = base + QStringLiteral("/wallpapers");
    QDir().mkpath(dir);
    const QString hash = QString::fromLatin1(QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex());
    const QFileInfo remote(QUrl(url).path());
    const QString suffix = remote.suffix().isEmpty() ? QStringLiteral("bin") : remote.suffix();
    return dir + QStringLiteral("/") + hash + QStringLiteral(".") + suffix;
}

void WallpaperService::onManifestChanged(bool /*stale*/)
{
    if (!m_manifest) {
        return;
    }
    QStringList active;
    for (const auto& wp : m_manifest->manifest().wallpapers) {
        if (wp.active && !wp.url.isEmpty()) {
            active.append(wp.url);
        }
    }
    const bool changed = (active != m_activeUrls);
    m_activeUrls = active;
    if (changed) {
        m_currentIndex = 0;
        enqueueDownloads();
        emit currentChanged();
    }
}

void WallpaperService::onConfigChanged()
{
    if (m_config && m_config->wallpaperRotation()) {
        if (!m_rotateTimer->isActive()) {
            m_rotateTimer->start();
        }
    } else {
        m_rotateTimer->stop();
    }
}

void WallpaperService::rotate()
{
    if (m_activeUrls.size() < 2) {
        return;
    }
    m_currentIndex = (m_currentIndex + 1) % static_cast<int>(m_activeUrls.size());
    emit currentChanged();
}

void WallpaperService::enqueueDownloads()
{
    m_downloadQueue.clear();
    for (const QString& url : m_activeUrls) {
        if (!QFileInfo::exists(localPathFor(url))) {
            m_downloadQueue.append(url);
        }
    }
    if (!m_currentDownload) {
        startNextDownload();
    }
}

void WallpaperService::startNextDownload()
{
    if (m_downloadQueue.isEmpty() || m_currentDownload) {
        return;
    }
    const QString url = m_downloadQueue.takeFirst();
    QNetworkRequest req{ QUrl(url) };
    req.setTransferTimeout(g_downloadTimeoutMs);
    m_currentDownload = m_nam->get(req);
    connect(m_currentDownload, &QNetworkReply::finished, this, &WallpaperService::onDownloadFinished);
}

void WallpaperService::onDownloadFinished()
{
    QNetworkReply* reply = m_currentDownload;
    m_currentDownload = nullptr;
    if (!reply) {
        startNextDownload();
        return;
    }
    reply->deleteLater();

    const QString url = reply->request().url().toString();
    if (reply->error() == QNetworkReply::NoError) {
        const QByteArray bytes = reply->readAll();
        // QSaveFile writes to a temp sibling and atomically renames on commit, so a
        // crash mid-write can't leave a truncated image that exists() then trusts forever.
        QSaveFile out(localPathFor(url));
        if (out.open(QIODevice::WriteOnly) && (out.write(bytes) == bytes.size()) && out.commit()) {
            // If this URL is what we're currently showing, refresh QML binding so it
            // switches from the remote fetch URL to the now-cached local file.
            if (m_activeUrls.value(m_currentIndex) == url) {
                emit currentChanged();
            }
        } else {
            qCWarning(jartonWallpaper) << "could not write cache file for" << url
                                       << "path=" << localPathFor(url);
        }
    } else {
        qCWarning(jartonWallpaper) << "download failed:" << reply->errorString()
                                   << "(code" << reply->error() << ") url=" << url;
    }
    startNextDownload();
}

}  // namespace Jarton
