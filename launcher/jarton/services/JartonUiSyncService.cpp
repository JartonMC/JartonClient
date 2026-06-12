// SPDX-License-Identifier: GPL-3.0-only
#include "JartonUiSyncService.h"

#include <QTimer>

#include <QFile>
#include <QLoggingCategory>
#include <QNetworkAccessManager>

#include "FileSystem.h"
#include "JartonManifestService.h"
#include "net/Download.h"

Q_LOGGING_CATEGORY(jartonUiSync, "jarton.uisync")

namespace Jarton {

JartonUiSyncService::JartonUiSyncService(JartonManifestService* manifest, QString cacheDir, QObject* parent)
    : QObject(parent), m_manifest(manifest), m_cache(std::move(cacheDir)), m_nam(new QNetworkAccessManager(this))
{
    if (m_manifest) {
        connect(m_manifest, &JartonManifestService::manifestChanged, this, &JartonUiSyncService::onManifestChanged);
        if (m_manifest->ready()) {
            onManifestChanged(m_manifest->stale());
        }
    }
}

void JartonUiSyncService::onManifestChanged(bool stale)
{
    if (stale || !m_manifest) {
        return;
    }
    if (m_job || !m_queue.isEmpty()) {
        return;  // sync in flight; the 15-minute manifest refresh picks up anything newer
    }

    const ManifestUi& ui = m_manifest->manifest().ui;
    m_uiVersion = ui.version;
    for (const auto& jar : ui.jars) {
        const bool current =
            m_cache.recordedSha256(jar.mcVersion) == jar.sha256 && QFile::exists(m_cache.jarPath(jar.mcVersion));
        if (!current) {
            m_queue.append({ jar.mcVersion, jar.url, jar.sha256 });
        }
    }
    if (!m_queue.isEmpty()) {
        qCInfo(jartonUiSync) << "syncing" << m_queue.size() << "JartonUI jar(s) for version" << m_uiVersion;
        startNext();
    }
}

void JartonUiSyncService::startNext()
{
    if (m_queue.isEmpty()) {
        return;
    }
    const PendingJar next = m_queue.takeFirst();
    const QString part = m_cache.jarPath(next.mcVersion) + QStringLiteral(".part");
    if (!FS::ensureFilePathExists(part)) {
        qCWarning(jartonUiSync) << "cannot create cache directory for" << part;
        m_queue.clear();
        return;
    }
    QFile::remove(part);

    m_job.reset(new NetJob(QStringLiteral("JartonUI %1 (%2)").arg(m_uiVersion, next.mcVersion), m_nam));
    m_job->addNetAction(Net::Download::makeFile(QUrl(next.url), part));
    connect(m_job.get(), &NetJob::succeeded, this, [this, next, part] {
        if (m_cache.commit(part, next.mcVersion, next.sha256, m_uiVersion)) {
            qCInfo(jartonUiSync) << "cached JartonUI" << m_uiVersion << "for" << next.mcVersion;
        } else {
            qCWarning(jartonUiSync) << "sha256 mismatch or cache write failure for" << next.mcVersion
                                    << "- keeping the previous jar";
        }
        advance();
    });
    connect(m_job.get(), &NetJob::failed, this, [this, next](QString reason) {
        qCWarning(jartonUiSync) << "download failed for" << next.mcVersion << ":" << reason;
        advance();
    });
    m_job->start();
}

void JartonUiSyncService::advance()
{
    // The job is mid-emit here; releasing it inline would free the sender.
    QTimer::singleShot(0, this, [this] {
        m_job.reset();
        startNext();
    });
}

}  // namespace Jarton
