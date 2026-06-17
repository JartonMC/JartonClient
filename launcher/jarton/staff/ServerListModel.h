// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>

namespace Jarton {

class ProctorClient;

struct GameServer {
    QString id;
    QString name;
    QString node;
    QString address;
    QString state;
    double cpuPercent = 0.0;
    qint64 memoryBytes = 0;
    qint64 memoryLimitMb = 0;
    int playersOnline = 0;
    int playersMax = 0;
};

// The Pterodactyl server list — GET /servers via the shared ProctorClient session.
// 409 (no panel key connected) is surfaced as panelKeyMissing so the view can prompt
// for the key instead of showing an empty/error list.
class ServerListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(bool panelKeyMissing READ panelKeyMissing NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)

   public:
    enum Roles : uint16_t {
        IdRole = Qt::UserRole + 1,
        NameRole,
        NodeRole,
        AddressRole,
        StateRole,
        CpuRole,
        MemBytesRole,
        MemLimitMbRole,
        PlayersOnlineRole,
        PlayersMaxRole,
    };

    explicit ServerListModel(ProctorClient* proctor, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }
    bool panelKeyMissing() const { return m_panelKeyMissing; }
    QString error() const { return m_error; }

    Q_INVOKABLE void refresh();

   signals:
    void changed();

   private:
    ProctorClient* m_proctor = nullptr;
    QVector<GameServer> m_servers;
    bool m_loading = false;
    bool m_panelKeyMissing = false;
    QString m_error;
};

}  // namespace Jarton
