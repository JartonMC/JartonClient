// SPDX-License-Identifier: GPL-3.0-only
#include "NewsService.h"

#include "JartonManifestService.h"

namespace Jarton {

NewsService::NewsService(JartonManifestService* manifest, QObject* parent) : QAbstractListModel(parent)
{
    if (manifest != nullptr) {
        connect(manifest, &JartonManifestService::manifestChanged, this, &NewsService::onManifestChanged);
        if (manifest->ready()) {
            m_items = manifest->manifest().news;
        }
    }
}

NewsService::~NewsService() = default;

int NewsService::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return static_cast<int>(m_items.size());
}

QVariant NewsService::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const auto& item = m_items.at(index.row());
    switch (role) {
        case IdRole:
            return item.id;
        case TitleRole:
        case Qt::DisplayRole:
            return item.title;
        case BodyMdRole:
            return item.bodyMd;
        case PublishedRole:
            return item.published;
        case UrlRole:
            return item.url;
        default:
            return {};
    }
}

QHash<int, QByteArray> NewsService::roleNames() const
{
    return {
        { IdRole, "newsId" },
        { TitleRole, "title" },
        { BodyMdRole, "bodyMd" },
        { PublishedRole, "published" },
        { UrlRole, "url" },
    };
}

void NewsService::onManifestChanged(bool /*stale*/)
{
    auto* manifest = qobject_cast<JartonManifestService*>(sender());
    if (manifest == nullptr) {
        return;
    }
    beginResetModel();
    m_items = manifest->manifest().news;
    endResetModel();
}

}  // namespace Jarton
