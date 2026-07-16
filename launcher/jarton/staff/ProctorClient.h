// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QHash>
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
class ProctorClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY changed)
    Q_PROPERTY(bool restoring READ restoring NOTIFY changed)
    Q_PROPERTY(QString loginError READ loginError NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QString mcUuid READ mcUuid NOTIFY changed)
    Q_PROPERTY(QString rank READ rank NOTIFY changed)
    Q_PROPERTY(bool admin READ admin NOTIFY changed)
    Q_PROPERTY(bool allowApplications READ allowApplications NOTIFY changed)
    Q_PROPERTY(bool allowJoinInfo READ allowJoinInfo NOTIFY changed)
    // Which staff section the sidebar picked ("staff" | "ptero" | "swifty" | "").
    // Driven from C++ (the host window) but exposed here because the sidebar and the
    // docked panel run in separate QML engines — the shared singleton is the only
    // channel both sides see. NOTIFY makes the panel's Loader react, which a plain
    // setProperty on a QML-declared property did not.
    Q_PROPERTY(QString currentSection READ currentSection NOTIFY sectionChanged)
    // Which sections are popped out into their own windows. Same cross-engine
    // rationale as currentSection: the docked panel's placeholders and each popped
    // window's own chrome bind here; MainWindow owns the actual window juggling.
    Q_PROPERTY(bool pteroPopped READ pteroPopped NOTIFY poppedChanged)
    Q_PROPERTY(bool staffPopped READ staffPopped NOTIFY poppedChanged)
    Q_PROPERTY(bool swiftyPopped READ swiftyPopped NOTIFY poppedChanged)

   public:
    explicit ProctorClient(const QString& tokenPath, QObject* parent = nullptr);
    ~ProctorClient() override;

    bool connected() const { return m_connected; }
    bool signingIn() const { return m_signingIn; }
    bool restoring() const { return m_restoring; }
    QString loginError() const { return m_loginError; }
    QString displayName() const { return m_displayName; }
    QString mcUuid() const { return m_mcUuid; }
    QString rank() const { return m_rank; }
    bool admin() const { return m_admin; }
    bool allowApplications() const { return m_allowApplications; }
    bool allowJoinInfo() const { return m_allowJoinInfo; }
    QString currentSection() const { return m_currentSection; }
    bool pteroPopped() const { return m_popped.value(QStringLiteral("ptero")); }
    bool staffPopped() const { return m_popped.value(QStringLiteral("staff")); }
    bool swiftyPopped() const { return m_popped.value(QStringLiteral("swifty")); }
    // invokable because the host window reaches it through the QObject* accessor
    Q_INVOKABLE void setSectionPopped(const QString& section, bool popped);

    Q_INVOKABLE void signIn(const QString& username, const QString& password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void setCurrentSection(const QString& section);
    Q_INVOKABLE void copyToClipboard(const QString& text);
    // QML asks; the host window answers by actually re-parenting the view and then
    // confirming through setSectionPopped().
    Q_INVOKABLE void requestSectionPop(const QString& section, bool popped) { emit sectionPopRequested(section, popped); }

    // C++-side accessors for sibling staff models that reuse this broker session.
    QNetworkAccessManager* network() const { return m_nam; }
    QString baseUrl() const { return m_baseUrl; }
    QString token() const { return m_token; }

   signals:
    void changed();
    void sectionChanged();
    void poppedChanged();
    void sectionPopRequested(const QString& section, bool popped);

   private:
    void applyStaff(const QJsonObject& staff);
    void onSessionEstablished();
    void restoreSession();
    void refreshMe();
    void loadToken();
    void saveToken() const;

    QNetworkAccessManager* m_nam = nullptr;
    QTimer* m_refresh = nullptr;  // re-reads /proctor/me so flag/rank edits apply without a re-login
    QString m_baseUrl = QStringLiteral("https://staff.jarton.me");
    QString m_tokenPath;
    QString m_token;
    bool m_connected = false;
    bool m_signingIn = false;
    bool m_restoring = false;
    QString m_loginError;
    QString m_displayName;
    QString m_mcUuid;
    QString m_rank;
    bool m_admin = false;
    bool m_allowApplications = true;
    bool m_allowJoinInfo = false;   // locked off by default server-side, granted per account
    QString m_currentSection;
    QHash<QString, bool> m_popped;  // section -> popped-out into its own window
};

}  // namespace Jarton
