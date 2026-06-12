// SPDX-License-Identifier: GPL-3.0-only
#include "JartonManifest.h"

#include <QJsonArray>
#include <QJsonObject>

namespace Jarton {

namespace {

QString readString(const QJsonObject& o, const QString& key, QStringList& warnings, const QString& fallback = {})
{
    const QJsonValue v = o.value(key);
    if (v.isString()) {
        return v.toString();
    }
    if (!v.isUndefined() && !v.isNull()) {
        warnings << QStringLiteral("field '%1' expected string").arg(key);
    }
    return fallback;
}

}  // namespace

Manifest Manifest::fromJson(const QJsonObject& root)
{
    Manifest m;
    m.launcherVersion = readString(root, "launcher_version", m.parseWarnings);
    m.minSupportedVersion = readString(root, "min_supported_version", m.parseWarnings);

    if (m.launcherVersion.isEmpty()) {
        m.parseWarnings << QStringLiteral("missing launcher_version");
        return m;  // invalid
    }

    const QJsonObject instObj = root.value("instance").toObject();
    m.instance.name = readString(instObj, "name", m.parseWarnings, QStringLiteral("Jarton"));
    m.instance.minecraftVersion = readString(instObj, "minecraft_version", m.parseWarnings);
    m.instance.fabricVersion = readString(instObj, "fabric_version", m.parseWarnings);
    m.instance.fabricApiVersion = readString(instObj, "fabric_api_version", m.parseWarnings);
    m.instance.packUrl = readString(instObj, "pack_url", m.parseWarnings);
    m.instance.packVersion = readString(instObj, "pack_version", m.parseWarnings);

    const QJsonObject serverObj = instObj.value("server").toObject();
    m.instance.serverAddress = readString(serverObj, "address", m.parseWarnings);
    m.instance.serverPort = static_cast<uint16_t>(serverObj.value("port").toInt(25565));

    const QJsonArray modsArr = instObj.value("mods").toArray();
    m.instance.mods.reserve(modsArr.size());
    for (const auto& v : modsArr) {
        const QJsonObject obj = v.toObject();
        ManifestMod mod;
        mod.slug = readString(obj, "slug", m.parseWarnings);
        mod.version = readString(obj, "version", m.parseWarnings);
        mod.side = readString(obj, "side", m.parseWarnings, QStringLiteral("client"));
        if (!mod.slug.isEmpty()) {
            m.instance.mods.append(mod);
        }
    }

    const QJsonObject packsObj = root.value("packs").toObject();
    m.packs.reserve(packsObj.size());
    for (auto it = packsObj.constBegin(); it != packsObj.constEnd(); ++it) {
        const QJsonObject obj = it.value().toObject();
        ManifestPack pack;
        pack.minecraftVersion = it.key();
        pack.fabricVersion = readString(obj, "fabric_version", m.parseWarnings);
        pack.packVersion = readString(obj, "pack_version", m.parseWarnings);
        pack.packUrl = readString(obj, "pack_url", m.parseWarnings);
        if (!pack.packUrl.isEmpty()) {
            m.packs.append(pack);
        }
    }

    const QJsonArray wpArr = root.value("wallpapers").toArray();
    m.wallpapers.reserve(wpArr.size());
    for (const auto& v : wpArr) {
        const QJsonObject obj = v.toObject();
        ManifestWallpaper wp;
        wp.id = readString(obj, "id", m.parseWarnings);
        wp.type = readString(obj, "type", m.parseWarnings, QStringLiteral("image"));
        wp.url = readString(obj, "url", m.parseWarnings);
        wp.active = obj.value("active").toBool(true);
        if (!wp.url.isEmpty()) {
            m.wallpapers.append(wp);
        }
    }

    const QJsonArray newsArr = root.value("news").toArray();
    m.news.reserve(newsArr.size());
    for (const auto& v : newsArr) {
        const QJsonObject obj = v.toObject();
        ManifestNewsItem item;
        item.id = readString(obj, "id", m.parseWarnings);
        item.title = readString(obj, "title", m.parseWarnings);
        item.bodyMd = readString(obj, "body_md", m.parseWarnings);
        item.published = readString(obj, "published", m.parseWarnings);
        item.url = readString(obj, "url", m.parseWarnings);
        m.news.append(item);
    }

    const QJsonValue featuredVal = root.value("featured_card");
    if (featuredVal.isObject()) {
        const QJsonObject obj = featuredVal.toObject();
        m.featured.title = readString(obj, "title", m.parseWarnings);
        m.featured.imageUrl = readString(obj, "image_url", m.parseWarnings);
        m.featured.ctaUrl = readString(obj, "cta_url", m.parseWarnings);
        m.featured.present = !m.featured.title.isEmpty();
    }

    m.valid = !m.instance.minecraftVersion.isEmpty() && !m.instance.serverAddress.isEmpty();
    return m;
}

QJsonObject Manifest::toJson() const
{
    QJsonObject root;
    root["launcher_version"] = launcherVersion;
    root["min_supported_version"] = minSupportedVersion;

    QJsonObject inst;
    inst["name"] = instance.name;
    inst["minecraft_version"] = instance.minecraftVersion;
    inst["fabric_version"] = instance.fabricVersion;
    inst["fabric_api_version"] = instance.fabricApiVersion;
    inst["pack_url"] = instance.packUrl;
    inst["pack_version"] = instance.packVersion;
    QJsonObject server;
    server["address"] = instance.serverAddress;
    server["port"] = static_cast<int>(instance.serverPort);
    inst["server"] = server;
    QJsonArray modsArr;
    for (const auto& mod : instance.mods) {
        QJsonObject o;
        o["slug"] = mod.slug;
        o["version"] = mod.version;
        o["side"] = mod.side;
        modsArr.append(o);
    }
    inst["mods"] = modsArr;
    root["instance"] = inst;

    QJsonObject packsObj;
    for (const auto& pack : packs) {
        QJsonObject o;
        o["fabric_version"] = pack.fabricVersion;
        o["pack_version"] = pack.packVersion;
        o["pack_url"] = pack.packUrl;
        packsObj[pack.minecraftVersion] = o;
    }
    root["packs"] = packsObj;

    QJsonArray wpArr;
    for (const auto& wp : wallpapers) {
        QJsonObject o;
        o["id"] = wp.id;
        o["type"] = wp.type;
        o["url"] = wp.url;
        o["active"] = wp.active;
        wpArr.append(o);
    }
    root["wallpapers"] = wpArr;

    QJsonArray newsArr;
    for (const auto& n : news) {
        QJsonObject o;
        o["id"] = n.id;
        o["title"] = n.title;
        o["body_md"] = n.bodyMd;
        o["published"] = n.published;
        o["url"] = n.url;
        newsArr.append(o);
    }
    root["news"] = newsArr;

    if (featured.present) {
        QJsonObject f;
        f["title"] = featured.title;
        f["image_url"] = featured.imageUrl;
        f["cta_url"] = featured.ctaUrl;
        root["featured_card"] = f;
    }
    return root;
}

}  // namespace Jarton
