// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;

namespace Jarton {

class StaffAuth;

// Generic authed request helper for the lighter Pterodactyl tabs (backups, schedules,
// network, subusers, databases) — each is a list + a couple of actions, so QML drives
// them off this instead of a bespoke C++ model per tab. send() returns a request id;
// the response(id, …) signal carries the raw JSON body for QML to JSON.parse.
class StaffApi : public QObject {
    Q_OBJECT
   public:
    explicit StaffApi(StaffAuth* auth, QObject* parent = nullptr);

    // method: GET|POST|DELETE|PATCH. jsonBody is sent as-is for non-GET (empty = none).
    Q_INVOKABLE int send(const QString& method, const QString& path, const QString& jsonBody = QString());

   signals:
    void response(int id, bool ok, int status, const QString& body);

   private:
    StaffAuth* m_auth = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    int m_nextId = 1;
};

}  // namespace Jarton
