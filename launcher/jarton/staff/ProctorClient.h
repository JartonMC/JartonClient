// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QJsonObject;

namespace Jarton {

// Broker client for the staff (Proctor) backend at staff.jarton.me — the same
// API the iOS Companion app talks to. Phase 0 covers auth only: username/password
// login -> 30-day JWT held in memory, /me identity, sign-out. Registered as a QML
// singleton so the docked panel and any popped-out windows share one session.
//
// NOTE (phase 0): the JWT lives in memory only; persistent secure storage
// (QtKeychain) lands when the sections that need a durable session do.
class ProctorClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY changed)
    Q_PROPERTY(QString loginError READ loginError NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QString rank READ rank NOTIFY changed)
    Q_PROPERTY(bool admin READ admin NOTIFY changed)
    // Per-staff Pterodactyl panel key (ptlc_…): the server sections 409 until it's connected.
    Q_PROPERTY(bool panelKeyConnected READ panelKeyConnected NOTIFY changed)
    Q_PROPERTY(bool panelKeyBusy READ panelKeyBusy NOTIFY changed)
    Q_PROPERTY(QString panelKeyError READ panelKeyError NOTIFY changed)
    // Which staff section the sidebar picked ("staff" | "ptero" | "swifty" | "").
    // Driven from C++ (the host window) but exposed here because the sidebar and the
    // docked panel run in separate QML engines — the shared singleton is the only
    // channel both sides see. NOTIFY makes the panel's Loader react, which a plain
    // setProperty on a QML-declared property did not.
    Q_PROPERTY(QString currentSection READ currentSection NOTIFY sectionChanged)

   public:
    explicit ProctorClient(QObject* parent = nullptr);
    ~ProctorClient() override;

    bool connected() const { return m_connected; }
    bool signingIn() const { return m_signingIn; }
    QString loginError() const { return m_loginError; }
    QString displayName() const { return m_displayName; }
    QString rank() const { return m_rank; }
    bool admin() const { return m_admin; }
    bool panelKeyConnected() const { return m_panelKeyConnected; }
    bool panelKeyBusy() const { return m_panelKeyBusy; }
    QString panelKeyError() const { return m_panelKeyError; }
    QString currentSection() const { return m_currentSection; }

    Q_INVOKABLE void signIn(const QString& username, const QString& password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void checkPanelKey();
    Q_INVOKABLE void connectPanelKey(const QString& key);
    Q_INVOKABLE void setCurrentSection(const QString& section);

    // C++-side accessors for sibling staff models that reuse this broker session.
    QNetworkAccessManager* network() const { return m_nam; }
    QString baseUrl() const { return m_baseUrl; }
    QString token() const { return m_token; }

   signals:
    void changed();
    void sectionChanged();

   private:
    void applyStaff(const QJsonObject& staff);

    QNetworkAccessManager* m_nam = nullptr;
    QString m_baseUrl = QStringLiteral("https://staff.jarton.me");
    QString m_token;
    bool m_connected = false;
    bool m_signingIn = false;
    QString m_loginError;
    QString m_displayName;
    QString m_rank;
    bool m_admin = false;
    bool m_panelKeyConnected = false;
    bool m_panelKeyBusy = false;
    QString m_panelKeyError;
    QString m_currentSection;
};

}  // namespace Jarton
