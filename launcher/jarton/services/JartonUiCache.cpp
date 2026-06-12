// SPDX-License-Identifier: GPL-3.0-only
#include "JartonUiCache.h"

#include <QCryptographicHash>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

#include "FileSystem.h"

namespace Jarton {

namespace {

QJsonObject readMeta(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QJsonDocument::fromJson(f.readAll()).object();
}

}  // namespace

JartonUiCache::JartonUiCache(QString rootDir) : m_root(std::move(rootDir)) {}

QString JartonUiCache::jarPath(const QString& mcVersion) const
{
    return FS::PathCombine(m_root, mcVersion + QStringLiteral(".jar"));
}

QString JartonUiCache::metaPath(const QString& mcVersion) const
{
    return FS::PathCombine(m_root, mcVersion + QStringLiteral(".json"));
}

QString JartonUiCache::recordedSha256(const QString& mcVersion) const
{
    return readMeta(metaPath(mcVersion)).value(QStringLiteral("sha256")).toString().toLower();
}

QString JartonUiCache::recordedVersion(const QString& mcVersion) const
{
    return readMeta(metaPath(mcVersion)).value(QStringLiteral("version")).toString();
}

QString JartonUiCache::verifiedJar(const QString& mcVersion) const
{
    const QString jar = jarPath(mcVersion);
    const QString want = recordedSha256(mcVersion);
    if (want.isEmpty() || !QFile::exists(jar)) {
        return {};
    }
    if (sha256Hex(jar) == want) {
        return jar;
    }
    // Bytes no longer match the sidecar: drop both so the next sync re-downloads
    // instead of trusting the stale record forever.
    QFile::remove(jar);
    QFile::remove(metaPath(mcVersion));
    return {};
}

bool JartonUiCache::commit(const QString& downloadedJar, const QString& mcVersion, const QString& sha256, const QString& uiVersion)
{
    const QString want = sha256.toLower();
    if (want.isEmpty() || sha256Hex(downloadedJar) != want) {
        QFile::remove(downloadedJar);
        return false;
    }
    if (!FS::ensureFolderPathExists(m_root)) {
        return false;
    }

    const QString dest = jarPath(mcVersion);
    const QString backup = dest + QStringLiteral(".old");
    QFile::remove(backup);
    const bool hadOld = QFile::exists(dest);
    if (hadOld && !QFile::rename(dest, backup)) {
        return false;
    }
    if (!QFile::rename(downloadedJar, dest)) {
        if (hadOld) {
            QFile::rename(backup, dest);
        }
        return false;
    }
    QFile::remove(backup);

    QJsonObject meta;
    meta[QStringLiteral("version")] = uiVersion;
    meta[QStringLiteral("sha256")] = want;
    // If this write doesn't land, the new jar no longer hashes to the old sidecar value,
    // so verifiedJar rejects it and the bundle covers until the next sync retries.
    QSaveFile out(metaPath(mcVersion));
    if (!out.open(QIODevice::WriteOnly)) {
        return false;
    }
    out.write(QJsonDocument(meta).toJson(QJsonDocument::Compact));
    return out.commit();
}

QString JartonUiCache::sha256Hex(const QString& filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!hash.addData(&f)) {
        return {};
    }
    return QString::fromLatin1(hash.result().toHex());
}

}  // namespace Jarton
