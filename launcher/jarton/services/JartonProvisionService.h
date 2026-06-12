// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>
#include <QVector>

#include "JartonManifest.h"

namespace Jarton {

class JartonManifestService;

// Creation-time provisioning for per-version Jarton instances.
//
// When the user picks a Minecraft version, this finds that version's curated pack in
// manifest.packs and asks the host to import it as a new instance named "Jarton <ver>".
// It runs exactly once, at creation: there is no re-sync, no version compare, and no
// "revert to pack contents" path. Once the instance exists the user owns its mods,
// shaders, and configs outright — nothing here ever touches an existing instance.
//
// The canonical 1.21.4 "Jarton" instance (first-launch) stays with DefaultInstanceService,
// which keys on the exact name "Jarton", so the "Jarton <ver>" instances this creates are
// invisible to it. By policy nothing ever updates an instance in place; new content reaches
// players only through this creation-time path.
class JartonProvisionService : public QObject {
    Q_OBJECT

   public:
    explicit JartonProvisionService(JartonManifestService* manifest, QObject* parent = nullptr);
    ~JartonProvisionService() override;

    // Minecraft versions that have a curated pack right now, newest-MC first. Empty until
    // the manifest is ready.
    QVector<ManifestPack> availablePacks() const;

    // Kick off creation for the given Minecraft version. No-op if that version has no pack.
    // The instance is named "Jarton <mcVersion>"; provisionRequested carries the resolved
    // pack URL + that name to the host, which owns the InstanceImportTask plumbing.
    void provision(const QString& mcVersion);

   signals:
    // Host downloads packUrl and imports it as a new instance called instanceName.
    // mcVersion + packVersion ride along so the host can write the instance's
    // jarton-pack.json baseline once the import lands.
    void provisionRequested(QString packUrl, QString instanceName, QString mcVersion, QString packVersion);

   private:
    JartonManifestService* m_manifest = nullptr;
};

}  // namespace Jarton
