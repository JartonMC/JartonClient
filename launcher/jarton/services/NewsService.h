// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QVector>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

namespace Jarton {

struct AnnouncementEntry {
    QString id;
    QDateTime posted;
    QString title;
    QString body;       // Markdown
    QString imageUrl;   // optional
    QString url;        // optional click-through
};

// Fetches /launcher/announcements.json on a 5-minute cadence and exposes the
// entries as a QML-friendly model. Source is CDN-hosted for now; eventual
// migration target is a Discord-bot endpoint that mirrors the announcements
// channel verbatim (markdown, images, embeds).
class NewsService : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY changed)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(QString latestTitle READ latestTitle NOTIFY changed)

   public:
    enum Roles : uint16_t {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        BodyRole,
        PostedRole,
        ImageUrlRole,
        UrlRole,
    };

    explicit NewsService(QObject* parent = nullptr);
    ~NewsService() override;

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool ready() const { return !m_entries.isEmpty(); }
    QString latestTitle() const;

    void setEndpointUrl(const QString& url);
    Q_INVOKABLE void refreshNow();
    Q_INVOKABLE QVariantMap entry(int index) const;

   signals:
    void changed();

   private slots:
    void onReplyFinished();

   private:
    QNetworkAccessManager* m_nam = nullptr;
    QNetworkReply* m_inFlight = nullptr;
    QTimer* m_timer = nullptr;
    QString m_endpoint;
    QVector<AnnouncementEntry> m_entries;
};

}  // namespace Jarton
