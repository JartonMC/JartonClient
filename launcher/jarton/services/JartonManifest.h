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
    // Full-export provisioning: a zip of the canonical instance hosted on the CDN.
    // packVersion gates the update prompt; the mods list above stays for reference/back-compat.
    QString packUrl;
    QString packVersion;
};

// One curated pack per Minecraft version (the "packs" map). Used to provision a fresh
// Jarton instance for a version the user picks. Separate from ManifestInstance, which
// stays the legacy 1.21.4 single-instance path that first-launch + update use.
struct ManifestPack {
    QString minecraftVersion;
    QString fabricVersion;
    QString packVersion;
    QString packUrl;
};

struct ManifestUiJar {
    QString mcVersion;
    QString url;
    QString sha256;
};

// CDN-hosted JartonUI builds keyed by Minecraft version (the "jartonui" section).
// Covers the per-MC-version Fabric/Quilt jars; Forge and NeoForge keep their single
// bundled jars. The section is optional — when absent the launcher runs entirely off
// the jars compiled into the binary.
struct ManifestUi {
    QString version;
    QVector<ManifestUiJar> jars;
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
    QVector<ManifestPack> packs;
    ManifestUi ui;
    QVector<ManifestWallpaper> wallpapers;
    QVector<ManifestNewsItem> news;
    ManifestFeaturedCard featured;

    bool valid = false;
    QStringList parseWarnings;

    static Manifest fromJson(const QJsonObject& root);
    QJsonObject toJson() const;
};

}  // namespace Jarton
