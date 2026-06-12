// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

namespace Jarton {

class JartonManifestService;

// Tracks the state of the canonical "Jarton" instance in Prism's InstanceList,
// exposes a single Play entry point to QML, and auto-provisions the instance on
// first launch from the manifest's pack_url (a full-instance zip on the CDN).
// Provisioning only fires when the instance is Missing, so a user's existing or
// hand-edited Jarton instance is never touched — the no-overwrite rule holds by
// construction.
class DefaultInstanceService : public QObject {
    Q_OBJECT

    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY stateChanged)

   public:
    enum State : uint8_t { Missing, Provisioning, Ready, Launching };
    Q_ENUM(State)

    explicit DefaultInstanceService(JartonManifestService* manifest, QObject* parent = nullptr);
    ~DefaultInstanceService() override;

    State state() const { return m_state; }
    QString instanceId() const { return m_instanceId; }

    // Re-scan Prism's InstanceList for an instance named "Jarton".
    Q_INVOKABLE void refresh();

    // Launch the Jarton instance if Ready. No-op otherwise (UI checks state first).
    Q_INVOKABLE void play();

    // Signal that the UI should surface Prism's New Instance dialog pre-filled.
    Q_INVOKABLE void requestSetup();

    // Application calls this when an import it kicked off finishes, so the
    // service can re-scan and flip out of Provisioning.
    void onProvisionFinished();

   signals:
    void stateChanged();
    void setupRequested(QString name, QString minecraftVersion, QString fabricVersion);
    // Application listens: download the pack zip at packUrl and import it as "Jarton".
    void provisionRequested(QString packUrl);
    void launchRequested(QString instanceId);

   private slots:
    void onManifestChanged(bool stale);

   private:
    void setState(State newState, const QString& id = {});
    void maybeProvision();

    JartonManifestService* m_manifest = nullptr;
    State m_state = Missing;
    QString m_instanceId;
    bool m_provisionAttempted = false;  // fire the first-launch download at most once per run
};

}  // namespace Jarton
