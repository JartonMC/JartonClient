// SPDX-License-Identifier: GPL-3.0-only
#include "PackRecord.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace Jarton {

namespace {

const QString g_recordName = QStringLiteral("jarton-pack.json");

QString hashFile(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    QCryptographicHash h(QCryptographicHash::Sha256);
    if (!h.addData(&f)) {
        return {};
    }
    return QString::fromLatin1(h.result().toHex());
}

QDir modsDir(const QString& gameRoot)
{
    return QDir(gameRoot + QStringLiteral("/mods"));
}

}  // namespace

PackRecord PackRecord::read(const QString& instanceRoot)
{
    PackRecord rec;
    QFile f(instanceRoot + QLatin1Char('/') + g_recordName);
    if (!f.open(QIODevice::ReadOnly)) {
        return rec;
    }
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    rec.mcVersion = root.value(QStringLiteral("mc_version")).toString();
    rec.packVersion = root.value(QStringLiteral("pack_version")).toString();
    const QJsonObject mods = root.value(QStringLiteral("mods")).toObject();
    for (auto it = mods.begin(); it != mods.end(); ++it) {
        rec.modHashes.insert(it.key(), it.value().toString());
    }
    rec.valid = !rec.mcVersion.isEmpty() && !rec.packVersion.isEmpty();
    return rec;
}

bool PackRecord::write(const QString& instanceRoot) const
{
    QJsonObject mods;
    for (auto it = modHashes.begin(); it != modHashes.end(); ++it) {
        mods.insert(it.key(), it.value());
    }
    QJsonObject root;
    root.insert(QStringLiteral("mc_version"), mcVersion);
    root.insert(QStringLiteral("pack_version"), packVersion);
    root.insert(QStringLiteral("mods"), mods);

    QSaveFile f(instanceRoot + QLatin1Char('/') + g_recordName);
    if (!f.open(QIODevice::WriteOnly)) {
        return false;
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return f.commit();
}

PackRecord PackRecord::capture(const QString& gameRoot, const QString& mcVersion, const QString& packVersion)
{
    PackRecord rec;
    rec.mcVersion = mcVersion;
    rec.packVersion = packVersion;
    rec.modHashes = hashMods(gameRoot);
    rec.valid = !mcVersion.isEmpty() && !packVersion.isEmpty();
    return rec;
}

bool PackRecord::modsMatch(const QString& gameRoot) const
{
    return hashMods(gameRoot) == modHashes;
}

QMap<QString, QString> PackRecord::hashMods(const QString& gameRoot)
{
    QMap<QString, QString> out;
    const QDir dir = modsDir(gameRoot);
    const QStringList jars =
        dir.entryList({ QStringLiteral("*.jar"), QStringLiteral("*.jar.disabled") }, QDir::Files, QDir::Name);
    for (const QString& name : jars) {
        out.insert(name, hashFile(dir.absoluteFilePath(name)));
    }
    return out;
}

}  // namespace Jarton
