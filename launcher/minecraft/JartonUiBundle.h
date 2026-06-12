#pragma once
#include <QString>
#include <QHash>

namespace JartonUiBundle {

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
    if (loaderComponent == QStringLiteral("net.fabricmc.fabric-loader")
        || loaderComponent == QStringLiteral("org.quiltmc.quilt-loader")) {
        return QStringLiteral(":/jarton/JartonUI-%1.jar").arg(mcVersion);
    }

    static const QHash<QString, QString> map = {
        { QStringLiteral("net.neoforged"), QStringLiteral(":/jarton/JartonUI-neoforge.jar") },
        { QStringLiteral("net.minecraftforge"), QStringLiteral(":/jarton/JartonUI-forge.jar") },
    };
    return map.value(loaderComponent);
}

}  // namespace JartonUiBundle
