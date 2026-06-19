// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/StaffApi.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

#include "jarton/staff/StaffAuth.h"

namespace Jarton {

StaffApi::StaffApi(StaffAuth* auth, QObject* parent)
    : QObject(parent), m_auth(auth), m_nam(auth ? auth->network() : nullptr)
{
}

int StaffApi::send(const QString& method, const QString& path, const QString& jsonBody)
{
    const int id = m_nextId++;
    if (!m_auth || !m_nam || m_auth->token().isEmpty()) {
        return id;
    }

    QNetworkRequest req{ QUrl(m_auth->baseUrl() + path) };
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    if (!jsonBody.isEmpty()) {
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    }
    req.setTransferTimeout(20000);

    const QByteArray body = jsonBody.toUtf8();
    const QString m = method.toUpper();
    QNetworkReply* reply = nullptr;
    if (m == QStringLiteral("GET")) {
        reply = m_nam->get(req);
    } else if (m == QStringLiteral("DELETE")) {
        reply = m_nam->sendCustomRequest(req, "DELETE", body);
    } else if (m == QStringLiteral("PATCH")) {
        reply = m_nam->sendCustomRequest(req, "PATCH", body);
    } else {
        reply = m_nam->post(req, body);
    }

    connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool ok = reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;
        emit response(id, ok, status, QString::fromUtf8(reply->readAll()));
    });
    return id;
}

}  // namespace Jarton
