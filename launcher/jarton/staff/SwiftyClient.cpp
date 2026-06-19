// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/SwiftyClient.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace Jarton {

SwiftyClient::SwiftyClient(QString tokenPath, QObject* parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this)), m_tokenPath(std::move(tokenPath))
{
    loadToken();
    if (!m_refreshToken.isEmpty()) {
        refresh();
    }
}

SwiftyClient::~SwiftyClient() = default;

void SwiftyClient::signIn(const QString& email, const QString& password)
{
    if (m_signingIn) {
        return;
    }
    m_signingIn = true;
    m_loginError.clear();
    emit changed();

    QJsonObject body;
    body.insert("email", email);
    body.insert("password", password);
    body.insert("remember", true);

    QNetworkRequest req{ QUrl(m_baseUrl + "/auth/login") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_signingIn = false;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 401) {
            m_loginError = tr("Wrong email or password.");
            emit changed();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            m_loginError = tr("Couldn't reach Swifty. Try again.");
            emit changed();
            return;
        }
        applyTokens(QJsonDocument::fromJson(reply->readAll()).object());
    });
}

void SwiftyClient::refresh()
{
    if (m_refreshToken.isEmpty()) {
        return;
    }
    QJsonObject body;
    body.insert("refreshToken", m_refreshToken);

    QNetworkRequest req{ QUrl(m_baseUrl + "/auth/refresh") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 401 || status == 403) {
            clearSession();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            return;  // transient — keep the stored token, retry next launch/focus
        }
        applyTokens(QJsonDocument::fromJson(reply->readAll()).object());
    });
}

void SwiftyClient::applyTokens(const QJsonObject& obj)
{
    m_token = obj.value("accessToken").toString();
    const QString refresh = obj.value("refreshToken").toString();
    if (!refresh.isEmpty()) {
        m_refreshToken = refresh;
        saveToken();
    }
    m_connected = !m_token.isEmpty();
    m_loginError.clear();
    emit changed();
}

void SwiftyClient::signOut()
{
    clearSession();
}

void SwiftyClient::clearSession()
{
    m_token.clear();
    m_refreshToken.clear();
    m_connected = false;
    QFile::remove(m_tokenPath);
    emit changed();
}

void SwiftyClient::loadToken()
{
    QFile f(m_tokenPath);
    if (f.open(QIODevice::ReadOnly)) {
        m_refreshToken = QString::fromUtf8(f.readAll()).trimmed();
    }
}

void SwiftyClient::saveToken() const
{
    QDir().mkpath(QFileInfo(m_tokenPath).absolutePath());
    QFile f(m_tokenPath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_refreshToken.toUtf8());
        f.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
    }
}

}  // namespace Jarton
