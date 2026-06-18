// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class QNetworkAccessManager;
class QTcpServer;

namespace Jarton {

// Discord-OAuth client for the staff backend's capability system — the desktop
// counterpart to the iOS Companion's sign-in. The broker reads the member's guild
// roles and returns a JWT carrying a capability list; the launcher gates its staff
// sidebar tabs off those capabilities. Distinct from ProctorClient, which owns the
// separate username/password proctor session used inside the Staff section.
//
// Desktop OAuth uses a loopback redirect: the system browser handles consent and
// redirects to http://127.0.0.1:<port>/cb, where a one-shot QTcpServer catches the
// code. The redirect URI must be registered on the Discord OAuth app.
class StaffAuth : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY changed)
    Q_PROPERTY(QString loginError READ loginError NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    // Capability-derived section gates, for the sidebar to bind against.
    Q_PROPERTY(bool canPanel READ canPanel NOTIFY changed)
    Q_PROPERTY(bool canProctor READ canProctor NOTIFY changed)
    Q_PROPERTY(bool canSwifty READ canSwifty NOTIFY changed)

   public:
    // tokenPath: file the refresh token is persisted to so the session survives restarts.
    explicit StaffAuth(QString tokenPath, QObject* parent = nullptr);
    ~StaffAuth() override;

    bool connected() const { return m_connected; }
    bool signingIn() const { return m_signingIn; }
    QString loginError() const { return m_loginError; }
    QString displayName() const { return m_displayName; }
    bool canPanel() const { return hasCap(QStringLiteral("servers.view")); }
    bool canProctor() const { return hasCap(QStringLiteral("proctor.access")); }
    bool canSwifty() const { return hasCap(QStringLiteral("swifty.view")); }

    Q_INVOKABLE void signIn();
    Q_INVOKABLE void signOut();
    // Re-resolve roles/caps from the stored refresh token (called on launch + focus).
    Q_INVOKABLE void refresh();

    // Cap JWT for sibling models (server list, panel key) that hit requireCap routes.
    QNetworkAccessManager* network() const { return m_nam; }
    QString baseUrl() const { return m_baseUrl; }
    QString token() const { return m_token; }

   signals:
    void changed();

   private:
    bool hasCap(const QString& cap) const { return m_caps.contains(QStringLiteral("*")) || m_caps.contains(cap); }
    void exchangeCode(const QString& code, const QString& verifier);
    void applySession(const class QJsonObject& obj);
    void clearSession();
    void loadToken();
    void saveToken() const;

    QNetworkAccessManager* m_nam = nullptr;
    QTcpServer* m_callbackServer = nullptr;
    QString m_baseUrl = QStringLiteral("https://staff.jarton.me");
    QString m_clientId = QStringLiteral("1514454694523568218");
    quint16 m_callbackPort = 53127;
    QString m_tokenPath;

    QString m_token;         // access JWT (in memory)
    QString m_refreshToken;  // persisted
    QStringList m_caps;
    bool m_connected = false;
    bool m_signingIn = false;
    QString m_loginError;
    QString m_displayName;
};

}  // namespace Jarton
