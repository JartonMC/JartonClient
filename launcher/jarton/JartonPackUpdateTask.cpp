// SPDX-License-Identifier: GPL-3.0-only
#include "JartonPackUpdateTask.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>

#include "FileSystem.h"
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
    const QString zipPath = FS::PathCombine(m_tempDir.path(), "pack.zip");
    m_dlJob.reset(new NetJob(QStringLiteral("Jarton pack update %1").arg(m_packVersion), m_network));
    m_dlJob->addNetAction(Net::Download::makeFile(QUrl(m_packUrl), zipPath));
    connect(m_dlJob.get(), &NetJob::succeeded, this, &JartonPackUpdateTask::apply);
    connect(m_dlJob.get(), &NetJob::failed, this, [this](QString reason) { emitFailed(reason); });
    connect(m_dlJob.get(), &NetJob::progress, this, &JartonPackUpdateTask::setProgress);
    m_dlJob->start();
}

QString JartonPackUpdateTask::packGameDir(const QString& unpackedRoot) const
{
    // Pack zips are MMC exports: instance.cfg + a minecraft/.minecraft dir,
    // either at the zip root or inside a single top-level folder.
    QStringList candidates{ unpackedRoot };
    const QDir root(unpackedRoot);
    for (const QString& sub : root.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        candidates << root.absoluteFilePath(sub);
    }
    for (const QString& base : candidates) {
        for (const char* game : { "minecraft", ".minecraft" }) {
            const QString dir = FS::PathCombine(base, game);
            if (QFileInfo(FS::PathCombine(dir, "mods")).isDir()) {
                return dir;
            }
        }
    }
    return {};
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

    const QString zipPath = FS::PathCombine(m_tempDir.path(), "pack.zip");
    const QString unpacked = FS::PathCombine(m_tempDir.path(), "unpacked");
    if (!MMCZip::extractDir(zipPath, unpacked)) {
        emitFailed(tr("Couldn't extract the pack archive."));
        return;
    }

    const QString packGame = packGameDir(unpacked);
    if (packGame.isEmpty()) {
        emitFailed(tr("The pack archive has no mods folder."));
        return;
    }

    // Mods: replace the shipped jar set. Only jars are cleared — Prism's
    // mods/.index metadata and anything else in there stays.
    QDir liveMods(FS::PathCombine(m_gameRoot, "mods"));
    if (!liveMods.exists() && !liveMods.mkpath(QStringLiteral("."))) {
        emitFailed(tr("Couldn't open the instance mods folder."));
        return;
    }
    const QStringList oldJars =
        liveMods.entryList({ QStringLiteral("*.jar"), QStringLiteral("*.jar.disabled") }, QDir::Files);
    for (const QString& name : oldJars) {
        // JartonUI is launcher-managed (force-injected per launch); leave it alone.
        if (name.startsWith(QStringLiteral("jartonui"), Qt::CaseInsensitive)) {
            continue;
        }
        if (!liveMods.remove(name)) {
            emitFailed(tr("Couldn't remove %1 from the mods folder.").arg(name));
            return;
        }
    }
    QDir packMods(FS::PathCombine(packGame, "mods"));
    for (const QString& name : packMods.entryList({ QStringLiteral("*.jar") }, QDir::Files)) {
        if (name.startsWith(QStringLiteral("jartonui"), Qt::CaseInsensitive)) {
            continue;
        }
        if (!QFile::copy(packMods.absoluteFilePath(name), liveMods.absoluteFilePath(name))) {
            emitFailed(tr("Couldn't install %1.").arg(name));
            return;
        }
    }

    // Configs: fill gaps only. A config the player (or a mod at runtime) already
    // has on disk is theirs; new mods still get their curated defaults.
    const QString packConfig = FS::PathCombine(packGame, "config");
    if (QFileInfo(packConfig).isDir()) {
        const QString liveConfig = FS::PathCombine(m_gameRoot, "config");
        QDirIterator it(packConfig, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString src = it.next();
            const QString rel = QDir(packConfig).relativeFilePath(src);
            const QString dst = FS::PathCombine(liveConfig, rel);
            if (QFileInfo::exists(dst)) {
                continue;
            }
            FS::ensureFilePathExists(dst);
            QFile::copy(src, dst);
        }
    }

    const PackRecord rec = PackRecord::capture(m_gameRoot, m_mcVersion, m_packVersion);
    if (!rec.write(m_instanceRoot)) {
        emitFailed(tr("Pack applied, but the update record couldn't be written."));
        return;
    }
    emitSucceeded();
}

}  // namespace Jarton
