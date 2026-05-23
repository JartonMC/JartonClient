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
    Q_PROPERTY(QVariantList entries READ entriesAsList NOTIFY changed)
    Q_PROPERTY(int selectedIndex READ selectedIndex WRITE setSelectedIndex NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedTitle READ selectedTitle NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedBody READ selectedBody NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedImageUrl READ selectedImageUrl NOTIFY selectedChanged)
    Q_PROPERTY(QString selectedUrl READ selectedUrl NOTIFY selectedChanged)
    Q_PROPERTY(QDateTime selectedPosted READ selectedPosted NOTIFY selectedChanged)

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
    QVariantList entriesAsList() const;

    int selectedIndex() const { return m_selectedIndex; }
    void setSelectedIndex(int i);
    QString selectedTitle() const;
    QString selectedBody() const;
    QString selectedImageUrl() const;
    QString selectedUrl() const;
    QDateTime selectedPosted() const;

    void setEndpointUrl(const QString& url);
    Q_INVOKABLE void refreshNow();
    Q_INVOKABLE QVariantMap entry(int index) const;

   signals:
    void changed();
    void selectedChanged();

   private slots:
    void onReplyFinished();

   private:
    QNetworkAccessManager* m_nam = nullptr;
    QNetworkReply* m_inFlight = nullptr;
    QTimer* m_timer = nullptr;
    QString m_endpoint;
    QVector<AnnouncementEntry> m_entries;
    int m_selectedIndex = 0;
};

}  // namespace Jarton
