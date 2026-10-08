// SPDX-License-Identifier: GPL-3.0-only
#include "JartonPackApply.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QObject>
#include <QSaveFile>

#include "FileSystem.h"
#include "services/PackRecord.h"

namespace Jarton::PackApply {

namespace {
bool isLauncherManaged(const QString& name)
{
    return name.startsWith(QStringLiteral("jartonui"), Qt::CaseInsensitive);
}

QStringList candidateRoots(const QString& unpackedRoot)
{
    QStringList roots{ unpackedRoot };
    const QDir root(unpackedRoot);
    for (const QString& sub : root.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        roots << root.absoluteFilePath(sub);
    }
    return roots;
}
}  // namespace

QString resolvedDir(const QString& dir)
{
    const QString resolved = QFileInfo(dir).canonicalFilePath();
    return resolved.isEmpty() ? dir : resolved;
}

QString findGameDir(const QString& unpackedRoot)
{
    for (const QString& base : candidateRoots(unpackedRoot)) {
        for (const char* game : { "minecraft", ".minecraft" }) {
            const QString dir = FS::PathCombine(base, game);
            if (QFileInfo(FS::PathCombine(dir, "mods")).isDir()) {
                return QDir(dir).absolutePath();
            }
        }
    }
    return {};
}

QString findPackRoot(const QString& unpackedRoot)
{
    for (const QString& base : candidateRoots(unpackedRoot)) {
        if (QFileInfo(FS::PathCombine(base, "mmc-pack.json")).isFile()) {
            return QDir(base).absolutePath();
        }
    }
    return {};
}

bool swapMods(const QString& gameRoot, const QString& packGameDir, QString* error)
{
    QDir liveMods(FS::PathCombine(gameRoot, "mods"));
    if (!liveMods.exists() && !liveMods.mkpath(QStringLiteral("."))) {
        if (error)
            *error = QObject::tr("Couldn't open the instance mods folder.");
        return false;
    }

    // Rename the current jars aside instead of deleting them, so a failed copy rolls back
    // cleanly — a half-swapped mods folder leaves the instance unlaunchable. The suffix
    // keeps the backups on the same filesystem as the originals so the rename can't fail
    // the way a cross-device move would.
    const QString bak = QStringLiteral(".jartonbak");
    QStringList stashed;
    QStringList installed;
    const auto rollback = [&] {
        for (const QString& name : installed)
            liveMods.remove(name);
        for (const QString& name : stashed)
            QFile::rename(liveMods.absoluteFilePath(name + bak), liveMods.absoluteFilePath(name));
    };

    for (const QString& name : liveMods.entryList({ QStringLiteral("*.jar"), QStringLiteral("*.jar.disabled") }, QDir::Files)) {
        if (isLauncherManaged(name))
            continue;
        liveMods.remove(name + bak);  // a leftover from an interrupted run would block the rename
        if (!QFile::rename(liveMods.absoluteFilePath(name), liveMods.absoluteFilePath(name + bak))) {
            rollback();
            if (error)
                *error = QObject::tr("Couldn't remove %1 from the mods folder.").arg(name);
            return false;
        }
        stashed << name;
    }

    QDir packMods(FS::PathCombine(packGameDir, "mods"));
    for (const QString& name : packMods.entryList({ QStringLiteral("*.jar") }, QDir::Files)) {
        if (isLauncherManaged(name))
            continue;
        if (!QFile::copy(packMods.absoluteFilePath(name), liveMods.absoluteFilePath(name))) {
            rollback();
            if (error)
                *error = QObject::tr("Couldn't install %1.").arg(name);
            return false;
        }
        installed << name;
    }

    for (const QString& name : stashed)
        liveMods.remove(name + bak);
    return true;
}

void fillConfigs(const QString& gameRoot, const QString& packGameDir)
{
    const QString packConfig = FS::PathCombine(packGameDir, "config");
    if (!QFileInfo(packConfig).isDir())
        return;
    const QString liveConfig = FS::PathCombine(gameRoot, "config");
    QDirIterator it(packConfig, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString src = it.next();
        const QString rel = QDir(packConfig).relativeFilePath(src);
        const QString dst = FS::PathCombine(liveConfig, rel);
        if (QFileInfo::exists(dst))
            continue;
        FS::ensureFilePathExists(dst);
        QFile::copy(src, dst);
    }
}

bool swapVersion(const QString& instanceRoot, const QString& packRoot, QString* error)
{
    QFile src(FS::PathCombine(packRoot, "mmc-pack.json"));
    // QSaveFile: a failed write leaves the old profile in place rather than none at all.
    QSaveFile dst(FS::PathCombine(instanceRoot, "mmc-pack.json"));
    if (!src.open(QIODevice::ReadOnly) || !dst.open(QIODevice::WriteOnly) || dst.write(src.readAll()) < 0 ||
        !dst.commit()) {
        if (error)
            *error = QObject::tr("Couldn't update the instance's version profile.");
        return false;
    }
    return true;
}

bool applyMigration(const QString& instanceRoot,
                    const QString& gameRoot,
                    const QString& unpackedRoot,
                    const QString& mcVersion,
                    const QString& packVersion,
                    QString* error)
{
    // Validate the whole pack before touching the instance, so a structurally bad
    // download leaves it untouched.
    const QString packGame = findGameDir(unpackedRoot);
    const QString packRoot = findPackRoot(unpackedRoot);
    if (packGame.isEmpty() || packRoot.isEmpty()) {
        if (error)
            *error = QObject::tr("The pack archive is missing its mods or version profile.");
        return false;
    }
    // Mods first (the many-file op most likely to fail), then the single-file version
    // profile swap, so a failed mod copy leaves the instance on its current version.
    if (!swapMods(gameRoot, packGame, error))
        return false;
    if (!swapVersion(instanceRoot, packRoot, error))
        return false;
    fillConfigs(gameRoot, packGame);

    const PackRecord rec = PackRecord::capture(gameRoot, mcVersion, packVersion);
    if (!rec.valid || !rec.write(instanceRoot)) {
        if (error)
            *error = QObject::tr("The instance was updated but its pack record couldn't be written.");
        return false;
    }
    return true;
}

}  // namespace Jarton::PackApply
