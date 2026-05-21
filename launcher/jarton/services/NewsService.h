// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>

#include "JartonManifest.h"

namespace Jarton {

class JartonManifestService;

class NewsService : public QAbstractListModel {
    Q_OBJECT

   public:
    enum Roles : uint16_t { IdRole = Qt::UserRole + 1, TitleRole, BodyMdRole, PublishedRole, UrlRole };

    explicit NewsService(JartonManifestService* manifest, QObject* parent = nullptr);
    ~NewsService() override;

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

   private slots:
    void onManifestChanged(bool stale);

   private:
    QVector<ManifestNewsItem> m_items;
};

}  // namespace Jarton
