// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QString>
#include <QTemporaryDir>

#include "net/NetJob.h"
#include "tasks/Task.h"

class QNetworkAccessManager;

namespace Jarton {

// Player-initiated instance migration: re-targets a Jarton instance to a chosen
// pack version. Unlike JartonPackUpdateTask this has NO edit gate (the player
// explicitly asked for it) and it also swaps the instance's mmc-pack.json, so
// the MC/Fabric version changes too. Worlds, options, keybinds, resource packs,
// shaders and servers are left untouched.
class JartonMigrateTask : public Task {
    Q_OBJECT

   public:
    JartonMigrateTask(QString instanceRoot,
                      QString gameRoot,
                      QString packUrl,
                      QString mcVersion,
                      QString packVersion,
                      QNetworkAccessManager* network);

   protected:
    void executeTask() override;

   private:
    void apply();

    QString m_instanceRoot;
    QString m_gameRoot;
    QString m_packUrl;
    QString m_mcVersion;
    QString m_packVersion;
    QNetworkAccessManager* m_network = nullptr;

    QTemporaryDir m_tempDir;
    NetJob::Ptr m_dlJob;
};

}  // namespace Jarton
