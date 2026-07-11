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

int ServerListModel::totalOnline() const
{
    int sum = 0;
    for (const auto& s : m_servers) {
        sum += s.playersOnline;
    }
    return sum;
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
        case CpuLimitRole:
            return s.cpuLimitPct;
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
        { CpuLimitRole, "cpuLimit" },
        { MemBytesRole, "memBytes" }, { MemLimitMbRole, "memLimitMb" },
        { PlayersOnlineRole, "playersOnline" }, { PlayersMaxRole, "playersMax" },
    };
}

void ServerListModel::refresh(bool quiet)
{
    if (m_auth == nullptr || m_auth->token().isEmpty() || m_loading || m_quietInflight) {
        return;
    }
    if (quiet) {
        // background poll: no loading state, so the Refresh button never flickers
        m_quietInflight = true;
    } else {
        m_loading = true;
        m_error.clear();
        emit changed();
    }

    QNetworkRequest req{ QUrl(m_auth->baseUrl() + "/servers") };
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_auth->network()->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, quiet]() {
        reply->deleteLater();
        m_loading = false;
        m_quietInflight = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 409) {
            m_panelKeyMissing = true;
            emit changed();
            return;
        }
        if (status == 401 && !m_retrying && m_auth != nullptr) {
            // access token expired mid-session: refresh once, then retry this fetch
            m_retrying = true;
            connect(m_auth, &StaffAuth::tokenRefreshed, this, [this]() { refresh(); }, Qt::SingleShotConnection);
            m_auth->refresh();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            if (quiet) {
                return;  // background poll failures wait for the next tick
            }
            m_error = tr("Couldn't load servers.");
            emit changed();
            return;
        }
        m_retrying = false;

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
            g.cpuLimitPct = o.value("cpuLimitPct").toInt();
            g.memoryBytes = static_cast<qint64>(o.value("memoryBytes").toDouble());
            g.memoryLimitMb = static_cast<qint64>(o.value("memoryLimitMb").toDouble());
            const QJsonObject players = o.value("players").toObject();
            g.playersOnline = players.value("online").toInt();
            g.playersMax = players.value("max").toInt();
            next.append(g);
        }

        // same servers in the same order: update rows in place so the list
        // doesn't reset scroll or re-realise delegates on every poll
        bool sameShape = next.size() == m_servers.size();
        for (int i = 0; sameShape && i < next.size(); ++i) {
            if (next.at(i).id != m_servers.at(i).id) {
                sameShape = false;
            }
        }
        if (sameShape) {
            for (int i = 0; i < next.size(); ++i) {
                const GameServer& a = m_servers.at(i);
                const GameServer& b = next.at(i);
                const bool same = a.state == b.state && a.cpuPercent == b.cpuPercent && a.cpuLimitPct == b.cpuLimitPct &&
                                  a.memoryBytes == b.memoryBytes && a.memoryLimitMb == b.memoryLimitMb &&
                                  a.playersOnline == b.playersOnline && a.playersMax == b.playersMax && a.name == b.name &&
                                  a.node == b.node && a.address == b.address;
                if (!same) {
                    m_servers[i] = b;
                    emit dataChanged(index(i), index(i));
                }
            }
        } else {
            beginResetModel();
            m_servers = next;
            endResetModel();
        }
        emit changed();
    });
}

}  // namespace Jarton
