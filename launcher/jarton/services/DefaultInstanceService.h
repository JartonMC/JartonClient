// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

namespace Jarton {

class JartonManifestService;

// Tracks the state of the "JartonMC" instance in Prism's InstanceList and
// exposes a single Play entry point to QML. Auto-provisioning the instance
// from the manifest (Fabric install + mod downloads) is deferred to a follow-up
// phase — in Phase 2 the service reports a Missing state and the UI surfaces
// Prism's existing New Instance flow with the name pre-filled.
class DefaultInstanceService : public QObject {
    Q_OBJECT

    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY stateChanged)

   public:
    enum State : uint8_t { Missing, Ready, Launching };
    Q_ENUM(State)

    explicit DefaultInstanceService(JartonManifestService* manifest, QObject* parent = nullptr);
    ~DefaultInstanceService() override;

    State state() const { return m_state; }
    QString instanceId() const { return m_instanceId; }

    // Re-scan Prism's InstanceList for an instance named "JartonMC".
    Q_INVOKABLE void refresh();

    // Launch the JartonMC instance if Ready. No-op otherwise (UI checks state first).
    Q_INVOKABLE void play();

    // Signal that the UI should surface Prism's New Instance dialog pre-filled.
    Q_INVOKABLE void requestSetup();

   signals:
    void stateChanged();
    void setupRequested(QString name, QString minecraftVersion, QString fabricVersion);
    void launchRequested(QString instanceId);

   private slots:
    void onManifestChanged(bool stale);

   private:
    void setState(State newState, const QString& id = {});

    JartonManifestService* m_manifest = nullptr;
    State m_state = Missing;
    QString m_instanceId;
};

}  // namespace Jarton
