// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

namespace Jarton {

class JartonManifestService;
class ConfigService;

class WallpaperService : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString currentUrl READ currentUrl NOTIFY currentChanged)
    Q_PROPERTY(QString nextUrl READ nextUrl NOTIFY currentChanged)

   public:
    explicit WallpaperService(JartonManifestService* manifest, ConfigService* config, QObject* parent = nullptr);
    ~WallpaperService() override;

    QString currentUrl() const;
    QString nextUrl() const;

    Q_INVOKABLE void rotate();

   signals:
    void currentChanged();

   private slots:
    void onManifestChanged(bool stale);
    void onConfigChanged();
    void onDownloadFinished();

   private:
    static QString localPathFor(const QString& url);
    QString resolvedUrl(int index) const;
    void enqueueDownloads();
    void startNextDownload();
    static QString fallbackUrl();

    JartonManifestService* m_manifest = nullptr;
    ConfigService* m_config = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    QTimer* m_rotateTimer = nullptr;
    QStringList m_activeUrls;
    QStringList m_downloadQueue;
    QNetworkReply* m_currentDownload = nullptr;
    int m_currentIndex = 0;
};

}  // namespace Jarton
