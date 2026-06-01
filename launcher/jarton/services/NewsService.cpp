// SPDX-License-Identifier: GPL-3.0-only
#include "NewsService.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QVariantMap>

Q_LOGGING_CATEGORY(jartonNews, "jarton.news")

namespace Jarton {

namespace {
constexpr int g_refreshIntervalMs = 5 * 60 * 1000;
constexpr int g_requestTimeoutMs = 10 * 1000;
// Switch to jarton.me/launcher/announcements.json once Cloudflare Pages is
// wired. Same file either way.
const char* const g_defaultEndpoint =
    "https://raw.githubusercontent.com/JartonMC/jarton-launcher-cdn/main/launcher/announcements.json";
}  // namespace

NewsService::NewsService(QObject* parent)
    : QAbstractListModel(parent),
      m_nam(new QNetworkAccessManager(this)),
      m_timer(new QTimer(this)),
      m_endpoint(QString::fromLatin1(g_defaultEndpoint))
{
    m_timer->setInterval(g_refreshIntervalMs);
    connect(m_timer, &QTimer::timeout, this, &NewsService::refreshNow);
    QTimer::singleShot(0, this, &NewsService::refreshNow);
    m_timer->start();
}

NewsService::~NewsService() = default;

int NewsService::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return static_cast<int>(m_entries.size());
}

QString NewsService::latestTitle() const
{
    return m_entries.isEmpty() ? QString{} : m_entries.first().title;
}

QVariantList NewsService::entriesAsList() const
{
    QVariantList out;
    out.reserve(m_entries.size());
    for (const auto& e : m_entries) {
        QVariantMap m;
        m["newsId"] = e.id;
        m["title"] = e.title;
        m["body"] = e.body;
        m["posted"] = e.posted;
        m["imageUrl"] = e.imageUrl;
        m["url"] = e.url;
        out.append(m);
    }
    return out;
}

QVariant NewsService::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size()) {
        return {};
    }
    const auto& e = m_entries.at(index.row());
    switch (role) {
        case IdRole:
            return e.id;
        case TitleRole:
        case Qt::DisplayRole:
            return e.title;
        case BodyRole:
            return e.body;
        case PostedRole:
            return e.posted;
        case ImageUrlRole:
            return e.imageUrl;
        case UrlRole:
            return e.url;
        default:
            return {};
    }
}

QHash<int, QByteArray> NewsService::roleNames() const
{
    return {
        { IdRole, "newsId" },
        { TitleRole, "title" },
        { BodyRole, "body" },
        { PostedRole, "posted" },
        { ImageUrlRole, "imageUrl" },
        { UrlRole, "url" },
    };
}

QVariantMap NewsService::entry(int index) const
{
    QVariantMap out;
    if (index < 0 || index >= m_entries.size()) {
        return out;
    }
    const auto& e = m_entries.at(index);
    out["newsId"] = e.id;
    out["title"] = e.title;
    out["body"] = e.body;
    out["posted"] = e.posted;
    out["imageUrl"] = e.imageUrl;
    out["url"] = e.url;
    return out;
}

void NewsService::setEndpointUrl(const QString& url)
{
    if (m_endpoint == url) {
        return;
    }
    m_endpoint = url;
    refreshNow();
}

void NewsService::refreshNow()
{
    if (m_inFlight != nullptr) {
        return;
    }
    QNetworkRequest req{ QUrl(m_endpoint) };
    req.setRawHeader("User-Agent", "JartonClient/1.0");
    req.setTransferTimeout(g_requestTimeoutMs);
    m_inFlight = m_nam->get(req);
    connect(m_inFlight, &QNetworkReply::finished, this, &NewsService::onReplyFinished);
}

void NewsService::onReplyFinished()
{
    QNetworkReply* reply = m_inFlight;
    m_inFlight = nullptr;
    if (reply == nullptr) {
        return;
    }
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(jartonNews) << "fetch failed:" << reply->errorString()
                              << "(code" << reply->error() << ") url=" << m_endpoint;
        return;  // keep last-known
    }
    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        qCWarning(jartonNews) << "response is not a JSON object; url=" << m_endpoint;
        return;
    }
    const QJsonArray arr = doc.object().value("entries").toArray();

    QVector<AnnouncementEntry> next;
    next.reserve(arr.size());
    for (const auto& v : arr) {
        const QJsonObject obj = v.toObject();
        AnnouncementEntry e;
        e.id = obj.value("id").toString();
        e.title = obj.value("title").toString();
        e.body = obj.value("body").toString();
        e.imageUrl = obj.value("image_url").toString();
        e.url = obj.value("url").toString();
        e.posted = QDateTime::fromString(obj.value("posted").toString(), Qt::ISODate);
        if (!e.title.isEmpty()) {
            next.append(e);
        }
    }
    // Newest first, in case the source isn't ordered.
    std::sort(next.begin(), next.end(),
              [](const AnnouncementEntry& a, const AnnouncementEntry& b) { return a.posted > b.posted; });

    beginResetModel();
    m_entries = next;
    endResetModel();
    if (m_selectedIndex >= m_entries.size()) {
        m_selectedIndex = 0;
    }
    emit changed();
    emit selectedChanged();
}

void NewsService::setSelectedIndex(int i)
{
    if (i < 0) {
        i = 0;
    }
    if (i >= m_entries.size()) {
        i = m_entries.isEmpty() ? 0 : m_entries.size() - 1;
    }
    if (m_selectedIndex == i) {
        return;
    }
    m_selectedIndex = i;
    emit selectedChanged();
}

QString NewsService::selectedTitle() const
{
    if (m_selectedIndex < 0 || m_selectedIndex >= m_entries.size()) {
        return {};
    }
    return m_entries.at(m_selectedIndex).title;
}

QString NewsService::selectedBody() const
{
    if (m_selectedIndex < 0 || m_selectedIndex >= m_entries.size()) {
        return {};
    }
    return m_entries.at(m_selectedIndex).body;
}

QString NewsService::selectedImageUrl() const
{
    if (m_selectedIndex < 0 || m_selectedIndex >= m_entries.size()) {
        return {};
    }
    return m_entries.at(m_selectedIndex).imageUrl;
}

QString NewsService::selectedUrl() const
{
    if (m_selectedIndex < 0 || m_selectedIndex >= m_entries.size()) {
        return {};
    }
    return m_entries.at(m_selectedIndex).url;
}

QDateTime NewsService::selectedPosted() const
{
    if (m_selectedIndex < 0 || m_selectedIndex >= m_entries.size()) {
        return {};
    }
    return m_entries.at(m_selectedIndex).posted;
}

}  // namespace Jarton
