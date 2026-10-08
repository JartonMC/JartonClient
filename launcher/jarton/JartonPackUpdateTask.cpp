// SPDX-License-Identifier: GPL-3.0-only
#include "JartonPackUpdateTask.h"

#include <QDir>
#include <QFileInfo>

#include "FileSystem.h"
#include "JartonPackApply.h"
#include "MMCZip.h"
#include "net/Download.h"
#include "services/PackRecord.h"

namespace Jarton {

JartonPackUpdateTask::JartonPackUpdateTask(QString instanceRoot,
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

void JartonPackUpdateTask::executeTask()
{
    setStatus(tr("Downloading Jarton pack %1 for %2").arg(m_packVersion, m_mcVersion));
    if (!m_tempDir.isValid()) {
        emitFailed(tr("Couldn't create a temporary folder for the update."));
        return;
    }
    const QString zipPath = FS::PathCombine(PackApply::resolvedDir(m_tempDir.path()), "pack.zip");
    m_dlJob.reset(new NetJob(QStringLiteral("Jarton pack update %1").arg(m_packVersion), m_network));
    m_dlJob->addNetAction(Net::Download::makeFile(QUrl(m_packUrl), zipPath));
    connect(m_dlJob.get(), &NetJob::succeeded, this, &JartonPackUpdateTask::apply);
    connect(m_dlJob.get(), &NetJob::failed, this, [this](QString reason) { emitFailed(reason); });
    connect(m_dlJob.get(), &NetJob::progress, this, &JartonPackUpdateTask::setProgress);
    m_dlJob->start();
}

void JartonPackUpdateTask::apply()
{
    // The edit gate ran before the prompt; re-check now in case the player
    // touched the mods folder while the pack was downloading.
    const PackRecord prior = PackRecord::read(m_instanceRoot);
    if (!prior.valid || !prior.modsMatch(m_gameRoot)) {
        emitFailed(tr("The instance changed while the update was downloading, so it was left alone."));
        return;
    }

    setStatus(tr("Applying Jarton pack %1").arg(m_packVersion));

    const QString tempRoot = PackApply::resolvedDir(m_tempDir.path());
    const QString zipPath = FS::PathCombine(tempRoot, "pack.zip");
    const QString unpacked = FS::PathCombine(tempRoot, "unpacked");
    if (!MMCZip::extractDir(zipPath, unpacked)) {
        emitFailed(tr("Couldn't extract the pack archive."));
        return;
    }

    const QString packGame = PackApply::findGameDir(unpacked);
    if (packGame.isEmpty()) {
        emitFailed(tr("The pack archive has no mods folder."));
        return;
    }

    QString err;
    if (!PackApply::swapMods(m_gameRoot, packGame, &err)) {
        emitFailed(err);
        return;
    }
    PackApply::fillConfigs(m_gameRoot, packGame);

    const PackRecord rec = PackRecord::capture(m_gameRoot, m_mcVersion, m_packVersion);
    if (!rec.write(m_instanceRoot)) {
        emitFailed(tr("Pack applied, but the update record couldn't be written."));
        return;
    }
    emitSucceeded();
}

}  // namespace Jarton
