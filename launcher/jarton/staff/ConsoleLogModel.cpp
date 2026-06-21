// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/ConsoleLogModel.h"

namespace Jarton {

int ConsoleLogModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_lines.size();
}

QVariant ConsoleLogModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_lines.size()) {
        return {};
    }
    if (role == LineRole) {
        return m_lines.at(index.row());
    }
    return {};
}

QHash<int, QByteArray> ConsoleLogModel::roleNames() const
{
    return { { LineRole, "line" } };
}

void ConsoleLogModel::append(const QString& html)
{
    const int row = m_lines.size();
    beginInsertRows(QModelIndex{}, row, row);
    m_lines.append(html);
    endInsertRows();

    const int overflow = m_lines.size() - kMaxLines;
    if (overflow > 0) {
        beginRemoveRows(QModelIndex{}, 0, overflow - 1);
        m_lines.remove(0, overflow);
        endRemoveRows();
    }
}

void ConsoleLogModel::clear()
{
    if (m_lines.isEmpty()) {
        return;
    }
    beginResetModel();
    m_lines.clear();
    endResetModel();
}

}  // namespace Jarton
