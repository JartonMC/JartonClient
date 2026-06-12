// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QMap>
#include <QString>

namespace Jarton {

// What the Jarton pack installed into an instance, written at provision time and
// refreshed whenever an update is applied (<instance root>/jarton-pack.json).
//
// The mod hashes are the edit gate for pushed updates: while the live mods folder
// still matches, the instance is stock and safe to update in place. Any drift —
// a jar added, removed, swapped or disabled — means the player owns the instance
// now, and updates skip it for good. Configs are deliberately not part of the
// gate: mods rewrite their own config files at runtime, so hashing them would
// mark every instance edited after the first play session.
struct PackRecord {
    QString mcVersion;
    QString packVersion;
    QMap<QString, QString> modHashes;  // filename under mods/ -> sha256

    bool valid = false;

    static PackRecord read(const QString& instanceRoot);
    bool write(const QString& instanceRoot) const;

    // Build a record from the live mods folder.
    static PackRecord capture(const QString& gameRoot, const QString& mcVersion, const QString& packVersion);

    bool modsMatch(const QString& gameRoot) const;

    // Top-level jars only (.jar / .jar.disabled). Prism metadata like mods/.index
    // churns on its own and must not trip the gate.
    static QMap<QString, QString> hashMods(const QString& gameRoot);
};

}  // namespace Jarton
