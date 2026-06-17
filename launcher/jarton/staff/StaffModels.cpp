// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/StaffModels.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSet>
#include <QUrl>

#include "jarton/staff/ProctorClient.h"

namespace Jarton {

namespace {
QNetworkRequest authedGet(ProctorClient* p, const QString& path)
{
    QNetworkRequest req{ QUrl(p->baseUrl() + path) };
    req.setRawHeader("Authorization", "Bearer " + p->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);
    return req;
}
QString norm(const QString& action)
{
    return action.toLower().replace(' ', '-');
}
}  // namespace

// ---- PlayerSearchModel ----

PlayerSearchModel::PlayerSearchModel(ProctorClient* proctor, QObject* parent) : QAbstractListModel(parent), m_proctor(proctor) {}

int PlayerSearchModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant PlayerSearchModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) {
        return {};
    }
    const Row& r = m_rows.at(index.row());
    switch (role) {
        case UuidRole:
            return r.uuid;
        case NameRole:
            return r.name;
        default:
            return {};
    }
}

QHash<int, QByteArray> PlayerSearchModel::roleNames() const
{
    return { { UuidRole, "uuid" }, { NameRole, "name" } };
}

void PlayerSearchModel::search(const QString& query)
{
    const QString q = query.trimmed();
    if (m_proctor == nullptr || m_proctor->token().isEmpty() || q.isEmpty()) {
        beginResetModel();
        m_rows.clear();
        endResetModel();
        emit changed();
        return;
    }
    m_loading = true;
    emit changed();

    QNetworkReply* reply = m_proctor->network()->get(
        authedGet(m_proctor, "/proctor/players/search?q=" + QString::fromUtf8(QUrl::toPercentEncoding(q))));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_loading = false;
        QVector<Row> next;
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).object().value("players").toArray();
            for (const auto& v : arr) {
                const QJsonObject o = v.toObject();
                next.append({ o.value("uuid").toString(), o.value("name").toString() });
            }
        }
        beginResetModel();
        m_rows = next;
        endResetModel();
        emit changed();
    });
}

// ---- PlayerHistoryModel ----

PlayerHistoryModel::PlayerHistoryModel(ProctorClient* proctor, QObject* parent) : QAbstractListModel(parent), m_proctor(proctor) {}

int PlayerHistoryModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant PlayerHistoryModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) {
        return {};
    }
    const Record& r = m_rows.at(index.row());
    switch (role) {
        case ActionRole:
            return r.action;
        case ReasonRole:
            return r.reason;
        case StaffRole:
            return r.staff;
        case TimestampRole:
            return QVariant::fromValue(r.timestamp);
        case DurationRole:
            return QVariant::fromValue(r.duration);
        case ActiveRole:
            return r.active;
        default:
            return {};
    }
}

QHash<int, QByteArray> PlayerHistoryModel::roleNames() const
{
    return {
        { ActionRole, "action" }, { ReasonRole, "reason" },     { StaffRole, "staffName" },
        { TimestampRole, "ts" },  { DurationRole, "duration" }, { ActiveRole, "active" },
    };
}

void PlayerHistoryModel::recomputeStatus()
{
    // history is most-recent-first; first match per family wins
    static const QSet<QString> banKinds = { "ban", "temp-ban", "ban-ip", "temp-ban-ip" };
    static const QSet<QString> muteKinds = { "mute", "temp-mute" };
    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    auto activeIn = [&](const QSet<QString>& kinds, const QString& removal) -> bool {
        for (const Record& r : m_rows) {
            const QString a = norm(r.action);
            if (a == removal) {
                return false;
            }
            if (kinds.contains(a)) {
                if (r.duration > 0 && r.timestamp + r.duration <= now) {
                    continue;  // expired temp
                }
                return true;
            }
        }
        return false;
    };
    m_banned = activeIn(banKinds, "unban");
    m_muted = activeIn(muteKinds, "unmute");
}

void PlayerHistoryModel::load(const QString& uuid, const QString& name)
{
    m_playerUuid = uuid;
    m_playerName = name;
    if (m_proctor == nullptr || m_proctor->token().isEmpty() || uuid.isEmpty()) {
        return;
    }
    m_loading = true;
    emit changed();

    QNetworkReply* reply = m_proctor->network()->get(authedGet(m_proctor, "/proctor/players/history?uuid=" + uuid));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_loading = false;
        QVector<Record> next;
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).object().value("history").toArray();
            for (const auto& v : arr) {
                const QJsonObject o = v.toObject();
                Record rec;
                rec.action = o.value("action").toString();
                rec.reason = o.value("reason").toString();
                rec.staff = o.value("staffName").toString();
                rec.timestamp = static_cast<qint64>(o.value("timestamp").toDouble());
                rec.duration = static_cast<qint64>(o.value("duration").toDouble());
                rec.active = o.value("active").toBool();
                next.append(rec);
            }
        }
        beginResetModel();
        m_rows = next;
        endResetModel();
        recomputeStatus();
        emit changed();
    });
}

}  // namespace Jarton
