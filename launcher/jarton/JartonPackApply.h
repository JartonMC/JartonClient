// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QString>

namespace Jarton::PackApply {

QString findGameDir(const QString& unpackedRoot);
QString findPackRoot(const QString& unpackedRoot);
bool swapMods(const QString& gameRoot, const QString& packGameDir, QString* error);
void fillConfigs(const QString& gameRoot, const QString& packGameDir);
bool swapVersion(const QString& instanceRoot, const QString& packRoot, QString* error);

// Player-initiated migration: re-target an instance onto an already-unpacked pack,
// swapping the version profile + mods, filling missing configs, and re-baselining
// the pack record. No edit gate — the player asked for it. Validates the pack
// before touching the instance so a bad download leaves it untouched.
bool applyMigration(const QString& instanceRoot,
                    const QString& gameRoot,
                    const QString& unpackedRoot,
                    const QString& mcVersion,
                    const QString& packVersion,
                    QString* error);

}  // namespace Jarton::PackApply
