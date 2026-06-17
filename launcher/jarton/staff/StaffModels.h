// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>

namespace Jarton {

class ProctorClient;

// Player search over GET /proctor/players/search?q= (anyone who has joined).
class PlayerSearchModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)

   public:
    enum Roles : uint16_t { UuidRole = Qt::UserRole + 1, NameRole };

    explicit PlayerSearchModel(ProctorClient* proctor, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }
    Q_INVOKABLE void search(const QString& query);

   signals:
    void changed();

   private:
    struct Row {
        QString uuid;
        QString name;
    };
    ProctorClient* m_proctor = nullptr;
    QVector<Row> m_rows;
    bool m_loading = false;
};

// One player's punishment history (GET /proctor/players/history?uuid=) plus derived
// banned/muted status, computed the same way as the iOS app (most-recent wins, temp
// punishments expire, an un-action clears the family).
class PlayerHistoryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)
    Q_PROPERTY(QString playerName READ playerName NOTIFY changed)
    Q_PROPERTY(QString playerUuid READ playerUuid NOTIFY changed)
    Q_PROPERTY(bool banned READ banned NOTIFY changed)
    Q_PROPERTY(bool muted READ muted NOTIFY changed)

   public:
    enum Roles : uint16_t { ActionRole = Qt::UserRole + 1, ReasonRole, StaffRole, TimestampRole, DurationRole, ActiveRole };

    explicit PlayerHistoryModel(ProctorClient* proctor, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }
    QString playerName() const { return m_playerName; }
    QString playerUuid() const { return m_playerUuid; }
    bool banned() const { return m_banned; }
    bool muted() const { return m_muted; }

    Q_INVOKABLE void load(const QString& uuid, const QString& name);

   signals:
    void changed();

   private:
    struct Record {
        QString action;
        QString reason;
        QString staff;
        qint64 timestamp = 0;
        qint64 duration = 0;
        bool active = false;
    };
    void recomputeStatus();

    ProctorClient* m_proctor = nullptr;
    QVector<Record> m_rows;
    bool m_loading = false;
    QString m_playerName;
    QString m_playerUuid;
    bool m_banned = false;
    bool m_muted = false;
};

}  // namespace Jarton
