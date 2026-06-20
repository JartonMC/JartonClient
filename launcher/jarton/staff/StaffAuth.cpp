// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/StaffAuth.h"

#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHostAddress>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

namespace Jarton {

namespace {
QByteArray b64url(const QByteArray& in)
{
    return in.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
}

QString makeVerifier()
{
    QByteArray raw(32, Qt::Uninitialized);
    QRandomGenerator::global()->fillRange(reinterpret_cast<quint32*>(raw.data()), raw.size() / sizeof(quint32));
    return QString::fromLatin1(b64url(raw));
}

QString challengeFor(const QString& verifier)
{
    return QString::fromLatin1(b64url(QCryptographicHash::hash(verifier.toLatin1(), QCryptographicHash::Sha256)));
}
}  // namespace

StaffAuth::StaffAuth(QString tokenPath, QObject* parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this)), m_tokenPath(std::move(tokenPath))
{
    m_refreshTimer = new QTimer(this);
    m_refreshTimer->setInterval(10 * 60 * 1000);  // keep the access token alive mid-session
    connect(m_refreshTimer, &QTimer::timeout, this, [this]() { refresh(); });

    loadToken();
    if (!m_refreshToken.isEmpty()) {
        refresh();  // resume the session + pick up any role change since last run
    }
}

StaffAuth::~StaffAuth() = default;

void StaffAuth::signIn()
{
    if (m_signingIn) {
        return;
    }

    // One-shot loopback server to catch Discord's redirect with the auth code.
    if (m_callbackServer) {
        m_callbackServer->deleteLater();
    }
    m_callbackServer = new QTcpServer(this);
    if (!m_callbackServer->listen(QHostAddress::LocalHost, m_callbackPort)) {
        m_loginError = tr("Couldn't open the sign-in listener. Is another login in progress?");
        m_callbackServer->deleteLater();
        m_callbackServer = nullptr;
        emit changed();
        return;
    }

    m_signingIn = true;
    m_loginError.clear();
    emit changed();

    const QString verifier = makeVerifier();
    const QString redirect = QStringLiteral("http://127.0.0.1:%1/cb").arg(m_callbackPort);

    connect(m_callbackServer, &QTcpServer::newConnection, this, [this, verifier, redirect]() {
        QTcpSocket* sock = m_callbackServer->nextPendingConnection();
        if (!sock) {
            return;
        }
        connect(sock, &QTcpSocket::readyRead, this, [this, sock, verifier, redirect]() {
            const QByteArray reqLine = sock->readLine();  // "GET /cb?code=...&state=... HTTP/1.1"
            const QString path = QString::fromLatin1(reqLine).section(' ', 1, 1);
            const QUrlQuery query{ QUrl(QStringLiteral("http://x") + path).query() };
            const QString code = query.queryItemValue("code");

            const QByteArray page =
                "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
                "<!doctype html><meta charset=utf-8><title>Jarton Staff</title>"
                "<body style='background:#0f0a06;color:#FFE082;font-family:system-ui;"
                "display:grid;place-items:center;height:100vh;margin:0'>"
                "<div style='text-align:center'><h2>You're signed in.</h2>"
                "<p style='color:#9a8a66'>You can close this tab and return to Jarton Client.</p></div>";
            sock->write(page);
            sock->flush();
            sock->disconnectFromHost();

            // tear the listener down — it only ever serves this one redirect
            m_callbackServer->close();
            m_callbackServer->deleteLater();
            m_callbackServer = nullptr;

            if (code.isEmpty()) {
                m_signingIn = false;
                m_loginError = tr("Sign-in was cancelled.");
                emit changed();
                return;
            }
            exchangeCode(code, verifier);
        });
    });

    QUrl authUrl(QStringLiteral("https://discord.com/oauth2/authorize"));
    QUrlQuery q;
    q.addQueryItem("client_id", m_clientId);
    q.addQueryItem("response_type", "code");
    q.addQueryItem("redirect_uri", redirect);
    q.addQueryItem("scope", "identify guilds.members.read");
    q.addQueryItem("code_challenge", challengeFor(verifier));
    q.addQueryItem("code_challenge_method", "S256");
    authUrl.setQuery(q);
    QDesktopServices::openUrl(authUrl);
}

void StaffAuth::exchangeCode(const QString& code, const QString& verifier)
{
    QJsonObject body;
    body.insert("code", code);
    body.insert("codeVerifier", verifier);
    body.insert("redirectUri", QStringLiteral("http://127.0.0.1:%1/cb").arg(m_callbackPort));

    QNetworkRequest req{ QUrl(m_baseUrl + "/auth/discord") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_signingIn = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 403) {
            m_loginError = tr("That Discord account doesn't have a staff role.");
            emit changed();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            m_loginError = tr("Sign-in didn't complete. Try again.");
            emit changed();
            return;
        }
        applySession(QJsonDocument::fromJson(reply->readAll()).object());
    });
}

void StaffAuth::refresh()
{
    if (m_refreshToken.isEmpty() || m_refreshing) {
        return;  // coalesce: one in-flight refresh at a time (broker rotates refresh tokens)
    }
    m_refreshing = true;
    QJsonObject body;
    body.insert("refreshToken", m_refreshToken);

    QNetworkRequest req{ QUrl(m_baseUrl + "/auth/refresh") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_refreshing = false;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        // 401 = token rotated/expired; 403 = every staff role removed since last login
        if (status == 401 || status == 403) {
            clearSession();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            return;  // transient — keep the session, next focus retries
        }
        applySession(QJsonDocument::fromJson(reply->readAll()).object());
        emit tokenRefreshed();
    });
}

void StaffAuth::applySession(const QJsonObject& obj)
{
    m_token = obj.value("accessToken").toString();
    const QString refresh = obj.value("refreshToken").toString();
    if (!refresh.isEmpty()) {
        m_refreshToken = refresh;
        saveToken();
    }
    const QJsonObject user = obj.value("user").toObject();
    m_displayName = user.value("username").toString();
    m_caps.clear();
    for (const QJsonValue& c : user.value("capabilities").toArray()) {
        m_caps << c.toString();
    }
    m_connected = !m_token.isEmpty();
    m_loginError.clear();
    emit changed();
    if (m_connected) {
        if (m_refreshTimer && !m_refreshTimer->isActive()) {
            m_refreshTimer->start();
        }
        if (canPanel()) {
            checkPanelKey();
        }
    }
}

void StaffAuth::checkPanelKey()
{
    if (!m_connected) {
        return;
    }
    QNetworkRequest req{ QUrl(m_baseUrl + "/account/panel-key") };
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(15000);

    QNetworkReply* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            m_panelKeyConnected = QJsonDocument::fromJson(reply->readAll()).object().value("connected").toBool();
            emit changed();
        }
    });
}

void StaffAuth::connectPanelKey(const QString& key)
{
    if (!m_connected || m_panelKeyBusy) {
        return;
    }
    m_panelKeyBusy = true;
    m_panelKeyError.clear();
    emit changed();

    QJsonObject body;
    body.insert("key", key);

    QNetworkRequest req{ QUrl(m_baseUrl + "/account/panel-key") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_panelKeyBusy = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            m_panelKeyError = (status == 422) ? tr("The panel rejected that key.") : tr("Couldn't connect the key.");
            emit changed();
            return;
        }
        m_panelKeyConnected = QJsonDocument::fromJson(reply->readAll()).object().value("connected").toBool();
        m_panelKeyError.clear();
        emit changed();
    });
}

void StaffAuth::signOut()
{
    if (!m_refreshToken.isEmpty()) {
        QJsonObject body;
        body.insert("refreshToken", m_refreshToken);
        QNetworkRequest req{ QUrl(m_baseUrl + "/auth/logout") };
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    }
    clearSession();
}

void StaffAuth::clearSession()
{
    if (m_refreshTimer) {
        m_refreshTimer->stop();
    }
    m_token.clear();
    m_refreshToken.clear();
    m_caps.clear();
    m_displayName.clear();
    m_connected = false;
    QFile::remove(m_tokenPath);
    emit changed();
}

void StaffAuth::loadToken()
{
    QFile f(m_tokenPath);
    if (f.open(QIODevice::ReadOnly)) {
        m_refreshToken = QString::fromUtf8(f.readAll()).trimmed();
    }
}

void StaffAuth::saveToken() const
{
    QDir().mkpath(QFileInfo(m_tokenPath).absolutePath());
    QFile f(m_tokenPath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_refreshToken.toUtf8());
        f.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
    }
}

}  // namespace Jarton
