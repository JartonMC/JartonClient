// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>

namespace Jarton {

class StaffAuth;

struct PteroFileEntry {
    QString name;
    bool isFile = true;
    qlonglong size = 0;
    QString mimetype;
    QString modifiedAt;
};

// Directory browser + single-file editor for one server's filesystem, over the broker's
// /servers/:id/files endpoints. The list model is the current directory; the editor
// properties hold one opened file's contents until saved or closed.
class PteroFiles : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString cwd READ cwd NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString openPath READ openPath NOTIFY editorChanged)  // "" when no file open
    Q_PROPERTY(QString content READ content NOTIFY editorChanged)
    Q_PROPERTY(bool editorLoading READ editorLoading NOTIFY editorChanged)
    Q_PROPERTY(bool saving READ saving NOTIFY editorChanged)
    Q_PROPERTY(QString editorError READ editorError NOTIFY editorChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY changed)

   public:
    enum Roles : uint16_t { NameRole = Qt::UserRole + 1, IsFileRole, SizeRole, MimeRole, ModifiedRole };

    explicit PteroFiles(StaffAuth* auth, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString cwd() const { return m_cwd; }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    QString openPath() const { return m_openPath; }
    QString content() const { return m_content; }
    bool editorLoading() const { return m_editorLoading; }
    bool saving() const { return m_saving; }
    QString editorError() const { return m_editorError; }

    Q_INVOKABLE void start(const QString& serverId);  // reset to / for a server
    Q_INVOKABLE void list(const QString& dir);
    Q_INVOKABLE void enter(const QString& name);      // cd into a subdirectory
    Q_INVOKABLE void up();                            // cd to parent
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void openFile(const QString& name);
    Q_INVOKABLE void save(const QString& content);
    Q_INVOKABLE void closeFile();

   signals:
    void changed();
    void editorChanged();

   private:
    QString joinPath(const QString& name) const;

    StaffAuth* m_auth = nullptr;
    QString m_serverId;
    QString m_cwd = QStringLiteral("/");
    QVector<PteroFileEntry> m_entries;
    bool m_loading = false;
    QString m_error;
    QString m_openPath;
    QString m_content;
    bool m_editorLoading = false;
    bool m_saving = false;
    QString m_editorError;
};

}  // namespace Jarton
