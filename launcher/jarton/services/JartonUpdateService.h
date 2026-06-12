// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class InstanceList;

namespace Jarton {

class JartonManifestService;

// Update checks against the CDN manifest, run once per launch when a
// network-confirmed manifest is in.
//
// Launcher: compares the running BuildConfig version against
// manifest.launcher_version and emits launcherUpdateAvailable; the host wires
// that into JartonSelfUpdateService, which downloads and applies the update.
//
// Instances: every instance carrying a jarton-pack.json (written at provision)
// is compared against the manifest's pack for its Minecraft version. Stock
// instances — mods folder still exactly what we installed — get one prompt
// listing the available updates; accepting hands each one to the host via
// instanceUpdateRequested. Instances the player has edited are theirs and are
// skipped permanently. Pre-record instances (or anything made elsewhere) have
// no jarton-pack.json and are invisible to this check.
class JartonUpdateService : public QObject {
    Q_OBJECT

   public:
    JartonUpdateService(JartonManifestService* manifest, InstanceList* instances, QObject* parent = nullptr);
    ~JartonUpdateService() override;

    // Run the checks. Safe to call repeatedly; each prompt fires at most once per launch.
    void checkAll();

    // User-triggered check: re-arms the launcher prompt and gives "up to date" feedback.
    void manualCheck();

   signals:
    // Host downloads packUrl and syncs it into the instance (JartonPackUpdateTask).
    void instanceUpdateRequested(QString instanceId, QString packUrl, QString mcVersion, QString packVersion);

    // Host hands this to JartonSelfUpdateService.
    void launcherUpdateAvailable(QString version);

   private slots:
    void onManifestChanged(bool stale);

   private:
    void checkLauncherUpdate();
    void checkInstanceUpdates();

    static QString runningLauncherVersion();

    JartonManifestService* m_manifest = nullptr;
    InstanceList* m_instances = nullptr;

    bool m_launcherPrompted = false;   // launcher-update signal fires once per run
    bool m_instancesPrompted = false;  // instance-update prompt fires once per run
};

}  // namespace Jarton
