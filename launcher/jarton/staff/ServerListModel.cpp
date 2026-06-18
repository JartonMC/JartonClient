// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/ServerListModel.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

#include "jarton/staff/StaffAuth.h"

namespace Jarton {

ServerListModel::ServerListModel(StaffAuth* auth, QObject* parent) : QAbstractListModel(parent), m_auth(auth) {}

int ServerListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_servers.size();
}

QVariant ServerListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_servers.size()) {
        return {};
    }
    const GameServer& s = m_servers.at(index.row());
    switch (role) {
        case IdRole:
            return s.id;
        case NameRole:
            return s.name;
        case NodeRole:
            return s.node;
        case AddressRole:
            return s.address;
        case StateRole:
            return s.state;
        case CpuRole:
            return s.cpuPercent;
        case MemBytesRole:
            return QVariant::fromValue(s.memoryBytes);
        case MemLimitMbRole:
            return QVariant::fromValue(s.memoryLimitMb);
        case PlayersOnlineRole:
            return s.playersOnline;
        case PlayersMaxRole:
            return s.playersMax;
        default:
            return {};
    }
}

QHash<int, QByteArray> ServerListModel::roleNames() const
{
    return {
        { IdRole, "serverId" },     { NameRole, "name" },         { NodeRole, "node" },
        { AddressRole, "address" }, { StateRole, "state" },       { CpuRole, "cpu" },
        { MemBytesRole, "memBytes" }, { MemLimitMbRole, "memLimitMb" },
        { PlayersOnlineRole, "playersOnline" }, { PlayersMaxRole, "playersMax" },
    };
}

void ServerListModel::refresh()
{
    if (m_auth == nullptr || m_auth->token().isEmpty() || m_loading) {
        return;
    }
    m_loading = true;
    m_error.clear();
    emit changed();

    QNetworkRequest req{ QUrl(m_auth->baseUrl() + "/servers") };
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_auth->network()->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_loading = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 409) {
            m_panelKeyMissing = true;
            emit changed();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            m_error = tr("Couldn't load servers.");
            emit changed();
            return;
        }

        m_panelKeyMissing = false;
        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).object().value("servers").toArray();
        QVector<GameServer> next;
        next.reserve(arr.size());
        for (const auto& v : arr) {
            const QJsonObject o = v.toObject();
            GameServer g;
            g.id = o.value("id").toString();
            g.name = o.value("name").toString();
            g.node = o.value("node").toString();
            g.address = o.value("address").toString();
            g.state = o.value("state").toString();
            g.cpuPercent = o.value("cpuPercent").toDouble();
            g.memoryBytes = static_cast<qint64>(o.value("memoryBytes").toDouble());
            g.memoryLimitMb = static_cast<qint64>(o.value("memoryLimitMb").toDouble());
            const QJsonObject players = o.value("players").toObject();
            g.playersOnline = players.value("online").toInt();
            g.playersMax = players.value("max").toInt();
            next.append(g);
        }

        beginResetModel();
        m_servers = next;
        endResetModel();
        emit changed();
    });
}

}  // namespace Jarton
