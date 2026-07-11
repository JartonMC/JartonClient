// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/ProctorClient.h"

#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

namespace {
constexpr qint64 kPinIdleMs = 3 * 60 * 60 * 1000;
}

namespace Jarton {

ProctorClient::ProctorClient(const QString& tokenPath, QObject* parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this)), m_tokenPath(tokenPath), m_lockTimer(new QTimer(this))
{
    m_lockTimer->setInterval(60 * 1000);
    connect(m_lockTimer, &QTimer::timeout, this, [this]() {
        if (m_connected && !m_admin && !m_pinLocked && QDateTime::currentMSecsSinceEpoch() - m_lastActivity >= kPinIdleMs) {
            m_pinLocked = true;
            emit changed();
        }
    });
    m_lockTimer->start();

    loadToken();
    if (!m_token.isEmpty()) {
        restoreSession();
    }
}

ProctorClient::~ProctorClient() = default;

void ProctorClient::setCurrentSection(const QString& section)
{
    if (m_currentSection == section) {
        return;
    }
    m_currentSection = section;
    if (section == QLatin1String("staff")) {
        notifyActivity();
    }
    emit sectionChanged();
}

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
        m_loginError.clear();
        applyStaff(obj.value("staff").toObject());
        if (!m_token.isEmpty()) {
            saveToken();
            onSessionEstablished();
        }
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
    m_pinSet = false;
    m_pinLocked = false;
    m_loginError.clear();
    QFile::remove(m_tokenPath);
    emit changed();
}

void ProctorClient::unlock()
{
    m_pinLocked = false;
    m_lastActivity = QDateTime::currentMSecsSinceEpoch();
    emit changed();
}

void ProctorClient::pinCreated()
{
    m_pinSet = true;
    unlock();
}

void ProctorClient::notifyActivity()
{
    if (!m_pinLocked) {
        m_lastActivity = QDateTime::currentMSecsSinceEpoch();
    }
}

void ProctorClient::copyToClipboard(const QString& text)
{
    QGuiApplication::clipboard()->setText(text);
}

void ProctorClient::applyStaff(const QJsonObject& staff)
{
    m_displayName = staff.value("displayName").toString();
    m_rank = staff.value("rank").toString();
    m_admin = staff.value("proctorAdmin").toBool();
    m_pinSet = staff.value("pinSet").toBool();
}

void ProctorClient::onSessionEstablished()
{
    m_connected = true;
    // fresh session = locked until the pin gate clears it; admins skip the gate
    m_pinLocked = !m_admin;
    m_lastActivity = QDateTime::currentMSecsSinceEpoch();
}

void ProctorClient::restoreSession()
{
    m_restoring = true;

    QNetworkRequest req{ QUrl(m_baseUrl + "/proctor/me") };
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(15000);

    QNetworkReply* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_restoring = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 401 || status == 403) {
            // stored jwt is dead (expired or account disabled) — back to the password form
            m_token.clear();
            QFile::remove(m_tokenPath);
            emit changed();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            // network hiccup: keep the token for the next launch, fall back to the form
            emit changed();
            return;
        }

        applyStaff(QJsonDocument::fromJson(reply->readAll()).object().value("staff").toObject());
        onSessionEstablished();
        emit changed();
    });
}

void ProctorClient::loadToken()
{
    QFile f(m_tokenPath);
    if (f.open(QIODevice::ReadOnly)) {
        m_token = QString::fromUtf8(f.readAll()).trimmed();
    }
}

void ProctorClient::saveToken() const
{
    QDir().mkpath(QFileInfo(m_tokenPath).absolutePath());
    QFile f(m_tokenPath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_token.toUtf8());
        f.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
    }
}

}  // namespace Jarton
