// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QAbstractListModel>
#include <QStringList>

namespace Jarton {

// Backing model for the live wings console. A plain QStringList property forced a full
// ListView reset on every appended line (re-realising every RichText delegate); this does
// incremental row inserts and caps the buffer with a front trim, so a chatty server scrolls
// without re-laying-out the whole view.
class ConsoleLogModel : public QAbstractListModel {
    Q_OBJECT
   public:
    enum Roles : uint16_t { LineRole = Qt::UserRole + 1 };

    explicit ConsoleLogModel(QObject* parent = nullptr) : QAbstractListModel(parent) {}

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void append(const QString& html);
    void clear();

   private:
    static constexpr int kMaxLines = 500;
    QStringList m_lines;
};

}  // namespace Jarton
