// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QDateTime>
#include <QObject>
#include <QString>

#include "JartonManifest.h"

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

namespace Jarton {

// Fetches /launcher/manifest.json on startup and every 15 minutes.
// Persists the last-good response to disk for offline fallback.
// Other services subscribe via manifestChanged; they never fetch HTTP themselves.
class JartonManifestService : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(bool stale READ stale NOTIFY readyChanged)
    Q_PROPERTY(QDateTime lastUpdated READ lastUpdated NOTIFY readyChanged)
    Q_PROPERTY(int consecutiveFailures READ consecutiveFailures NOTIFY readyChanged)
    Q_PROPERTY(QString featuredTitle READ featuredTitle NOTIFY readyChanged)
    Q_PROPERTY(QString featuredImageUrl READ featuredImageUrl NOTIFY readyChanged)
    Q_PROPERTY(QString featuredCtaUrl READ featuredCtaUrl NOTIFY readyChanged)

   public:
    explicit JartonManifestService(QObject* parent = nullptr);
    ~JartonManifestService() override;

    bool ready() const { return m_ready; }
    bool stale() const { return m_stale; }
    QDateTime lastUpdated() const { return m_lastUpdated; }
    int consecutiveFailures() const { return m_consecutiveFailures; }
    const Manifest& manifest() const { return m_manifest; }

    QString featuredTitle() const { return m_manifest.featured.present ? m_manifest.featured.title : QString{}; }
    QString featuredImageUrl() const { return m_manifest.featured.present ? m_manifest.featured.imageUrl : QString{}; }
    QString featuredCtaUrl() const { return m_manifest.featured.present ? m_manifest.featured.ctaUrl : QString{}; }

    // Override the endpoint for testing / dev builds. Default is the BuildConfig URL.
    void setEndpointUrl(const QString& url);

    Q_INVOKABLE void refreshNow();

   signals:
    void manifestChanged(bool stale);
    void readyChanged();
    void fetchFailed(const QString& reason);
    void firstLaunchOffline();  // first-ever fetch failed AND no on-disk cache exists

   private slots:
    void onReplyFinished();

   private:
    void loadFromDiskCache();
    static void persistToDiskCache(const QByteArray& bytes);
    static QString cachePath();

    QNetworkAccessManager* m_nam = nullptr;
    QNetworkReply* m_inFlight = nullptr;
    QTimer* m_refreshTimer = nullptr;
    QString m_endpoint;
    Manifest m_manifest;
    bool m_ready = false;
    bool m_stale = false;
    QDateTime m_lastUpdated;
    int m_consecutiveFailures = 0;
};

}  // namespace Jarton
