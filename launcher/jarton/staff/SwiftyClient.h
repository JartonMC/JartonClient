// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;

namespace Jarton {

// Swifty (swifty.jarton.me) has its own email/password account system, separate from
// Discord and the Proctor broker — so the launcher's Swifty section signs in on its own
// (hybrid: the Discord `swifty` role reveals the tab, this logs into the service inside).
// Holds the access JWT in memory; persists the refresh token so the session survives a
// restart. Sibling SwiftyApi rides this token for board/card calls.
class SwiftyClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY changed)
    Q_PROPERTY(QString loginError READ loginError NOTIFY changed)

   public:
    explicit SwiftyClient(QString tokenPath, QObject* parent = nullptr);
    ~SwiftyClient() override;

    bool connected() const { return m_connected; }
    bool signingIn() const { return m_signingIn; }
    QString loginError() const { return m_loginError; }

    Q_INVOKABLE void signIn(const QString& email, const QString& password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void refresh();

    QNetworkAccessManager* network() const { return m_nam; }
    QString baseUrl() const { return m_baseUrl; }
    QString token() const { return m_token; }

   signals:
    void changed();

   private:
    void applyTokens(const class QJsonObject& obj);
    void clearSession();
    void loadToken();
    void saveToken() const;

    QNetworkAccessManager* m_nam = nullptr;
    QString m_baseUrl = QStringLiteral("https://swifty.jarton.me/api");
    QString m_tokenPath;
    QString m_token;
    QString m_refreshToken;
    bool m_connected = false;
    bool m_signingIn = false;
    QString m_loginError;
};

}  // namespace Jarton
