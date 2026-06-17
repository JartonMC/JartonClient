// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/ProctorClient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace Jarton {

ProctorClient::ProctorClient(QObject* parent) : QObject(parent), m_nam(new QNetworkAccessManager(this)) {}

ProctorClient::~ProctorClient() = default;

void ProctorClient::signIn(const QString& username, const QString& password)
{
    if (m_signingIn) {
        return;
    }
    m_signingIn = true;
    m_loginError.clear();
    emit changed();

    QJsonObject body;
    body.insert("username", username);
    body.insert("password", password);

    QNetworkRequest req{ QUrl(m_baseUrl + "/proctor/auth/login") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(15000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_signingIn = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            switch (status) {
                case 401:
                    m_loginError = tr("Wrong username or password.");
                    break;
                case 403:
                    m_loginError = tr("This account is disabled.");
                    break;
                case 429:
                    m_loginError = tr("Too many attempts. Wait a few minutes.");
                    break;
                default:
                    m_loginError = tr("Couldn't reach the staff service.");
                    break;
            }
            emit changed();
            return;
        }

        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        m_token = obj.value("token").toString();
        m_connected = !m_token.isEmpty();
        m_loginError.clear();
        applyStaff(obj.value("staff").toObject());
        emit changed();
    });
}

void ProctorClient::signOut()
{
    m_token.clear();
    m_connected = false;
    m_displayName.clear();
    m_rank.clear();
    m_admin = false;
    m_loginError.clear();
    emit changed();
}

void ProctorClient::applyStaff(const QJsonObject& staff)
{
    m_displayName = staff.value("displayName").toString();
    m_rank = staff.value("rank").toString();
    m_admin = staff.value("proctorAdmin").toBool();
}

}  // namespace Jarton
