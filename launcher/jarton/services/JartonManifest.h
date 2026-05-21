// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVector>

namespace Jarton {

struct ManifestMod {
    QString slug;
    QString version;
    QString side;
};

struct ManifestInstance {
    QString name;
    QString minecraftVersion;
    QString fabricVersion;
    QString fabricApiVersion;
    QString serverAddress;
    uint16_t serverPort = 25565;
    QVector<ManifestMod> mods;
};

struct ManifestWallpaper {
    QString id;
    QString type;
    QString url;
    bool active = true;
};

struct ManifestNewsItem {
    QString id;
    QString title;
    QString bodyMd;
    QString published;
    QString url;
};

struct ManifestFeaturedCard {
    QString title;
    QString imageUrl;
    QString ctaUrl;
    bool present = false;
};

struct Manifest {
    QString launcherVersion;
    QString minSupportedVersion;
    ManifestInstance instance;
    QVector<ManifestWallpaper> wallpapers;
    QVector<ManifestNewsItem> news;
    ManifestFeaturedCard featured;

    bool valid = false;
    QStringList parseWarnings;

    static Manifest fromJson(const QJsonObject& root);
    QJsonObject toJson() const;
};

}  // namespace Jarton
