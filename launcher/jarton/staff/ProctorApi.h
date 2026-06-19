// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;

namespace Jarton {

class ProctorClient;

// Generic authed request helper for the Proctor queues (tickets / applications / reports
// / alerts), using the proctor username/password session. Mirrors StaffApi, but on the
// ProctorClient token rather than the Discord cap token.
class ProctorApi : public QObject {
    Q_OBJECT
   public:
    explicit ProctorApi(ProctorClient* proctor, QObject* parent = nullptr);

    Q_INVOKABLE int send(const QString& method, const QString& path, const QString& jsonBody = QString());

   signals:
    void response(int id, bool ok, int status, const QString& body);

   private:
    ProctorClient* m_proctor = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    int m_nextId = 1;
};

}  // namespace Jarton
