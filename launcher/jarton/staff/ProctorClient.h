// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QJsonObject;
class QTimer;

namespace Jarton {

// Broker client for the staff (Proctor) backend at staff.jarton.me — the same
// API the iOS Companion app talks to. Username/password login -> 30-day JWT,
// persisted to the launcher data dir (like the Discord cap session) so a
// relaunch restores the session via /proctor/me instead of retyping the
// password. Registered as a QML singleton so the docked panel and any
// popped-out windows share one session.
//
// The Staff section is additionally pin-gated for non-admin accounts: locked
// on every launch and after 3h without staff-section activity. The pin itself
// lives on the broker (scrypt hash on proctor_staff); this class only tracks
// the local locked/unlocked state and the idle clock.
class ProctorClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY changed)
    Q_PROPERTY(bool restoring READ restoring NOTIFY changed)
    Q_PROPERTY(QString loginError READ loginError NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QString rank READ rank NOTIFY changed)
    Q_PROPERTY(bool admin READ admin NOTIFY changed)
    Q_PROPERTY(bool pinSet READ pinSet NOTIFY changed)
    Q_PROPERTY(bool pinLocked READ pinLocked NOTIFY changed)
    // Which staff section the sidebar picked ("staff" | "ptero" | "swifty" | "").
    // Driven from C++ (the host window) but exposed here because the sidebar and the
    // docked panel run in separate QML engines — the shared singleton is the only
    // channel both sides see. NOTIFY makes the panel's Loader react, which a plain
    // setProperty on a QML-declared property did not.
    Q_PROPERTY(QString currentSection READ currentSection NOTIFY sectionChanged)

   public:
    explicit ProctorClient(const QString& tokenPath, QObject* parent = nullptr);
    ~ProctorClient() override;

    bool connected() const { return m_connected; }
    bool signingIn() const { return m_signingIn; }
    bool restoring() const { return m_restoring; }
    QString loginError() const { return m_loginError; }
    QString displayName() const { return m_displayName; }
    QString rank() const { return m_rank; }
    bool admin() const { return m_admin; }
    bool pinSet() const { return m_pinSet; }
    bool pinLocked() const { return m_pinLocked; }
    QString currentSection() const { return m_currentSection; }

    Q_INVOKABLE void signIn(const QString& username, const QString& password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void setCurrentSection(const QString& section);
    // Called by the pin gate after the broker accepted the verify / create.
    Q_INVOKABLE void unlock();
    Q_INVOKABLE void pinCreated();
    // Any staff-section interaction feeds the idle clock (ProctorApi requests,
    // sub-tab switches, entering the section).
    Q_INVOKABLE void notifyActivity();
    Q_INVOKABLE void copyToClipboard(const QString& text);

    // C++-side accessors for sibling staff models that reuse this broker session.
    QNetworkAccessManager* network() const { return m_nam; }
    QString baseUrl() const { return m_baseUrl; }
    QString token() const { return m_token; }

   signals:
    void changed();
    void sectionChanged();

   private:
    void applyStaff(const QJsonObject& staff);
    void onSessionEstablished();
    void restoreSession();
    void loadToken();
    void saveToken() const;

    QNetworkAccessManager* m_nam = nullptr;
    QString m_baseUrl = QStringLiteral("https://staff.jarton.me");
    QString m_tokenPath;
    QString m_token;
    QTimer* m_lockTimer = nullptr;
    qint64 m_lastActivity = 0;
    bool m_connected = false;
    bool m_signingIn = false;
    bool m_restoring = false;
    bool m_pinSet = false;
    bool m_pinLocked = false;
    QString m_loginError;
    QString m_displayName;
    QString m_rank;
    bool m_admin = false;
    QString m_currentSection;
};

}  // namespace Jarton
