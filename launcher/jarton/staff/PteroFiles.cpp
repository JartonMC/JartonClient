// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/PteroFiles.h"

#include <algorithm>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>

#include "jarton/staff/StaffAuth.h"

namespace Jarton {

PteroFiles::PteroFiles(StaffAuth* auth, QObject* parent) : QAbstractListModel(parent), m_auth(auth) {}

int PteroFiles::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant PteroFiles::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size()) {
        return {};
    }
    const PteroFileEntry& e = m_entries.at(index.row());
    switch (role) {
        case NameRole: return e.name;
        case IsFileRole: return e.isFile;
        case SizeRole: return QVariant::fromValue(e.size);
        case MimeRole: return e.mimetype;
        case ModifiedRole: return e.modifiedAt;
        default: return {};
    }
}

QHash<int, QByteArray> PteroFiles::roleNames() const
{
    return { { NameRole, "name" }, { IsFileRole, "isFile" }, { SizeRole, "size" },
             { MimeRole, "mimetype" }, { ModifiedRole, "modifiedAt" } };
}

QString PteroFiles::joinPath(const QString& name) const
{
    QString base = m_cwd.endsWith('/') ? m_cwd : m_cwd + '/';
    return base + name;
}

void PteroFiles::start(const QString& serverId)
{
    m_serverId = serverId;
    closeFile();
    list(QStringLiteral("/"));
}

void PteroFiles::list(const QString& dir)
{
    if (!m_auth || m_serverId.isEmpty() || m_loading) {
        return;
    }
    m_loading = true;
    m_error.clear();
    m_cwd = dir.endsWith('/') ? dir : dir + '/';
    emit changed();

    QUrl url(m_auth->baseUrl() + "/servers/" + m_serverId + "/files");
    QUrlQuery q;
    q.addQueryItem("dir", m_cwd);
    url.setQuery(q);

    QNetworkRequest req{ url };
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_auth->network()->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_loading = false;
        if (reply->error() != QNetworkReply::NoError) {
            m_error = tr("Couldn't load files.");
            emit changed();
            return;
        }
        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).object().value("files").toArray();
        QVector<PteroFileEntry> next;
        next.reserve(arr.size());
        for (const auto& v : arr) {
            const QJsonObject o = v.toObject();
            PteroFileEntry e;
            e.name = o.value("name").toString();
            e.isFile = o.value("isFile").toBool();
            e.size = static_cast<qlonglong>(o.value("size").toDouble());
            e.mimetype = o.value("mimetype").toString();
            e.modifiedAt = o.value("modifiedAt").toString();
            next.append(e);
        }
        // directories first, then alphabetical — the natural file-manager order
        std::sort(next.begin(), next.end(), [](const PteroFileEntry& a, const PteroFileEntry& b) {
            if (a.isFile != b.isFile) return !a.isFile;
            return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
        });
        beginResetModel();
        m_entries = next;
        endResetModel();
        emit changed();
    });
}

void PteroFiles::enter(const QString& name)
{
    list(joinPath(name));
}

void PteroFiles::up()
{
    if (m_cwd == QStringLiteral("/") || m_cwd.isEmpty()) {
        return;
    }
    QString p = m_cwd;
    if (p.endsWith('/')) {
        p.chop(1);
    }
    const int slash = p.lastIndexOf('/');
    list(slash <= 0 ? QStringLiteral("/") : p.left(slash + 1));
}

void PteroFiles::refresh()
{
    list(m_cwd);
}

void PteroFiles::openFile(const QString& name)
{
    if (!m_auth || m_serverId.isEmpty()) {
        return;
    }
    const QString path = joinPath(name);
    m_openPath = path;
    m_content.clear();
    m_editorError.clear();
    m_editorLoading = true;
    emit editorChanged();

    QUrl url(m_auth->baseUrl() + "/servers/" + m_serverId + "/files/contents");
    QUrlQuery q;
    q.addQueryItem("file", path);
    url.setQuery(q);

    QNetworkRequest req{ url };
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_auth->network()->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_editorLoading = false;
        if (reply->error() != QNetworkReply::NoError) {
            m_editorError = tr("Couldn't open this file.");
            emit editorChanged();
            return;
        }
        m_content = QJsonDocument::fromJson(reply->readAll()).object().value("content").toString();
        emit editorChanged();
    });
}

void PteroFiles::save(const QString& content)
{
    if (!m_auth || m_serverId.isEmpty() || m_openPath.isEmpty() || m_saving) {
        return;
    }
    m_saving = true;
    m_editorError.clear();
    emit editorChanged();

    QJsonObject body;
    body.insert("file", m_openPath);
    body.insert("content", content);

    QNetworkRequest req{ QUrl(m_auth->baseUrl() + "/servers/" + m_serverId + "/files/write") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);

    QNetworkReply* reply = m_auth->network()->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, content]() {
        reply->deleteLater();
        m_saving = false;
        if (reply->error() != QNetworkReply::NoError) {
            m_editorError = tr("Couldn't save — check your access.");
        } else {
            m_content = content;
        }
        emit editorChanged();
    });
}

void PteroFiles::closeFile()
{
    m_openPath.clear();
    m_content.clear();
    m_editorError.clear();
    emit editorChanged();
}

// fire a files action (delete/rename/folder), then re-list cwd so the view reflects it
void PteroFiles::postAction(const QString& path, const QJsonObject& body)
{
    if (!m_auth || m_serverId.isEmpty()) {
        return;
    }
    QNetworkRequest req{ QUrl(m_auth->baseUrl() + "/servers/" + m_serverId + path) };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(20000);
    QNetworkReply* reply = m_auth->network()->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        refresh();
    });
}

void PteroFiles::deleteEntry(const QString& name)
{
    QJsonObject body;
    body.insert("root", m_cwd);
    body.insert("files", QJsonArray{ name });
    postAction(QStringLiteral("/files/delete"), body);
}

void PteroFiles::renameEntry(const QString& from, const QString& to)
{
    if (to.trimmed().isEmpty()) {
        return;
    }
    QJsonObject body;
    body.insert("root", m_cwd);
    body.insert("from", from);
    body.insert("to", to);
    postAction(QStringLiteral("/files/rename"), body);
}

void PteroFiles::newFolder(const QString& name)
{
    if (name.trimmed().isEmpty()) {
        return;
    }
    QJsonObject body;
    body.insert("root", m_cwd);
    body.insert("name", name);
    postAction(QStringLiteral("/files/folder"), body);
}

}  // namespace Jarton
