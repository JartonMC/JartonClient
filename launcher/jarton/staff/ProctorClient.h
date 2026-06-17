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

   public:
    explicit ProctorClient(QObject* parent = nullptr);
    ~ProctorClient() override;

    bool connected() const { return m_connected; }
    bool signingIn() const { return m_signingIn; }
    QString loginError() const { return m_loginError; }
    QString displayName() const { return m_displayName; }
    QString rank() const { return m_rank; }
    bool admin() const { return m_admin; }

    Q_INVOKABLE void signIn(const QString& username, const QString& password);
    Q_INVOKABLE void signOut();

   signals:
    void changed();

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
};

}  // namespace Jarton
