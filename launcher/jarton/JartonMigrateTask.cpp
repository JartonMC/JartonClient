// SPDX-License-Identifier: GPL-3.0-only
#include "JartonMigrateTask.h"

#include "FileSystem.h"
#include "JartonPackApply.h"
#include "MMCZip.h"
#include "net/Download.h"

namespace Jarton {

JartonMigrateTask::JartonMigrateTask(QString instanceRoot,
                                     QString gameRoot,
                                     QString packUrl,
                                     QString mcVersion,
                                     QString packVersion,
                                     QNetworkAccessManager* network)
    : m_instanceRoot(std::move(instanceRoot))
    , m_gameRoot(std::move(gameRoot))
    , m_packUrl(std::move(packUrl))
    , m_mcVersion(std::move(mcVersion))
    , m_packVersion(std::move(packVersion))
    , m_network(network)
{}

void JartonMigrateTask::executeTask()
{
    setStatus(tr("Downloading Jarton pack %1 for %2").arg(m_packVersion, m_mcVersion));
    if (!m_tempDir.isValid()) {
        emitFailed(tr("Couldn't create a temporary folder for the update."));
        return;
    }
    const QString zipPath = FS::PathCombine(m_tempDir.path(), "pack.zip");
    m_dlJob.reset(new NetJob(QStringLiteral("Jarton migrate %1").arg(m_packVersion), m_network));
    m_dlJob->addNetAction(Net::Download::makeFile(QUrl(m_packUrl), zipPath));
    connect(m_dlJob.get(), &NetJob::succeeded, this, &JartonMigrateTask::apply);
    connect(m_dlJob.get(), &NetJob::failed, this, [this](QString reason) { emitFailed(reason); });
    connect(m_dlJob.get(), &NetJob::progress, this, &JartonMigrateTask::setProgress);
    m_dlJob->start();
}

void JartonMigrateTask::apply()
{
    setStatus(tr("Updating to Jarton %1 (%2)").arg(m_packVersion, m_mcVersion));
    const QString zipPath = FS::PathCombine(m_tempDir.path(), "pack.zip");
    const QString unpacked = FS::PathCombine(m_tempDir.path(), "unpacked");
    if (!MMCZip::extractDir(zipPath, unpacked)) {
        emitFailed(tr("Couldn't extract the pack archive."));
        return;
    }
    QString err;
    if (!PackApply::applyMigration(m_instanceRoot, m_gameRoot, unpacked, m_mcVersion, m_packVersion, &err)) {
        emitFailed(err);
        return;
    }
    emitSucceeded();
}

}  // namespace Jarton
