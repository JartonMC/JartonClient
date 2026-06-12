// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QString>
#include <QTemporaryDir>

#include "net/NetJob.h"
#include "tasks/Task.h"

class QNetworkAccessManager;

namespace Jarton {

// In-place pack update for a stock Jarton instance. Downloads the version's pack
// zip and syncs it into the live instance:
//   - mods: the shipped jar set is replaced wholesale (the edit gate upstream
//     guarantees the live set is still exactly what we installed)
//   - config: files are added when missing, never overwritten
//   - everything else (saves, options, servers, screenshots, shaders) untouched
// On success the instance's jarton-pack.json baseline is rewritten so the next
// check compares against the new pack.
class JartonPackUpdateTask : public Task {
    Q_OBJECT

   public:
    JartonPackUpdateTask(QString instanceRoot,
                         QString gameRoot,
                         QString packUrl,
                         QString mcVersion,
                         QString packVersion,
                         QNetworkAccessManager* network);

   protected:
    void executeTask() override;

   private:
    void apply();
    QString packGameDir(const QString& unpackedRoot) const;

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
