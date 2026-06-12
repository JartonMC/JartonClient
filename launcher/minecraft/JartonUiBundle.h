#pragma once
#include <QString>
#include <QHash>

#include "jarton/services/JartonUiCache.h"

namespace JartonUiBundle {

// Fabric jars are built per Minecraft version; Quilt runs Fabric mods natively and
// shares them. These are the loaders whose jars also ship via the CDN manifest.
inline bool perVersionLoader(const QString& loaderComponent)
{
    return loaderComponent == QStringLiteral("net.fabricmc.fabric-loader")
        || loaderComponent == QStringLiteral("org.quiltmc.quilt-loader");
}

// JartonUI hooks Minecraft's GUI internals, which change between releases, so it's built
// per Minecraft version: the Fabric jar resource is named for the MC version. Quilt runs
// Fabric mods natively, so it shares those jars. Forge/NeoForge aren't multi-versioned
// yet; they keep their single bundled jars. LiteLoader and anything else: no jar.
//
// This is a pure path mapping — it doesn't check whether the resource actually exists.
// If we don't ship a jar for a given version, the returned path simply won't resolve and
// the caller (jartonInjectUiMod) no-ops on the missing file, leaving a plain menu rather
// than injecting a mismatched jar that would fail to load.
inline QString jarFor(const QString& loaderComponent, const QString& mcVersion)
{
    if (perVersionLoader(loaderComponent)) {
        return QStringLiteral(":/jarton/JartonUI-%1.jar").arg(mcVersion);
    }

    static const QHash<QString, QString> map = {
        { QStringLiteral("net.neoforged"), QStringLiteral(":/jarton/JartonUI-neoforge.jar") },
        { QStringLiteral("net.minecraftforge"), QStringLiteral(":/jarton/JartonUI-forge.jar") },
    };
    return map.value(loaderComponent);
}

// A CDN-synced jar wins over the compiled-in bundle when the cache holds one that still
// matches its recorded sha256; anything less falls through to jarFor. Forge/NeoForge
// aren't on the CDN yet, so they always resolve to their bundled jars.
inline QString resolve(const QString& loaderComponent, const QString& mcVersion, const Jarton::JartonUiCache& cache)
{
    if (perVersionLoader(loaderComponent)) {
        const QString cached = cache.verifiedJar(mcVersion);
        if (!cached.isEmpty()) {
            return cached;
        }
    }
    return jarFor(loaderComponent, mcVersion);
}

}  // namespace JartonUiBundle
