// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>
#include <QVector>

#include "JartonUiCache.h"
#include "net/NetJob.h"

class QNetworkAccessManager;

namespace Jarton {

class JartonManifestService;

// Keeps the local JartonUI jar cache in step with the manifest's "jartonui" section.
// Entirely silent: jars download one at a time, get sha256-verified, and only then swap
// into the cache, so the launch-time injection path never sees a half-written file.
// A stale manifest is ignored — the last good jars keep serving.
class JartonUiSyncService : public QObject {
    Q_OBJECT

   public:
    JartonUiSyncService(JartonManifestService* manifest, QString cacheDir, QObject* parent = nullptr);

   private slots:
    void onManifestChanged(bool stale);

   private:
    struct PendingJar {
        QString mcVersion;
        QString url;
        QString sha256;
    };

    void startNext();
    void advance();

    JartonManifestService* m_manifest = nullptr;
    JartonUiCache m_cache;
    QString m_uiVersion;
    QNetworkAccessManager* m_nam = nullptr;
    QVector<PendingJar> m_queue;
    NetJob::Ptr m_job;
};

}  // namespace Jarton
