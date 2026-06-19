// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;

namespace Jarton {

class SwiftyClient;

// Generic authed request helper for the Swifty boards/cards UI, on the SwiftyClient token.
// Mirrors StaffApi/ProctorApi: send() -> response(id, …) with the raw JSON body.
class SwiftyApi : public QObject {
    Q_OBJECT
   public:
    explicit SwiftyApi(SwiftyClient* client, QObject* parent = nullptr);

    Q_INVOKABLE int send(const QString& method, const QString& path, const QString& jsonBody = QString());

   signals:
    void response(int id, bool ok, int status, const QString& body);

   private:
    SwiftyClient* m_client = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    int m_nextId = 1;
};

}  // namespace Jarton
