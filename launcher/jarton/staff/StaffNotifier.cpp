// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/StaffNotifier.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

#include "jarton/staff/ProctorClient.h"

#ifdef Q_OS_MACOS
#include "jarton/staff/MacNotifier.h"
#endif

namespace Jarton {

namespace {
constexpr int POLL_MS = 30 * 1000;
// past this many fresh rows in one poll, collapse to a single summary banner
constexpr int BANNER_CAP = 5;
}  // namespace

StaffNotifier::StaffNotifier(ProctorClient* proctor, QString cursorPath, QObject* parent)
    : QObject(parent), m_proctor(proctor), m_cursorPath(std::move(cursorPath))
{
    m_timer = new QTimer(this);
    m_timer->setInterval(POLL_MS);
    connect(m_timer, &QTimer::timeout, this, [this]() { poll(); });

    connect(m_proctor, &ProctorClient::changed, this, [this]() {
        if (m_proctor->connected() && !m_timer->isActive()) {
            loadCursor();
            if (m_cursorOwner != m_proctor->displayName()) {
                m_lastSeen = -1;  // different account: baseline instead of replaying their inbox
            }
#ifdef Q_OS_MACOS
            Mac::requestNotificationPermission();
#endif
            poll();
            m_timer->start();
        } else if (!m_proctor->connected() && m_timer->isActive()) {
            m_timer->stop();
        }
    });
}

void StaffNotifier::poll()
{
    if (m_inflight || !m_proctor->connected()) {
        return;
    }
    m_inflight = true;

    QNetworkRequest req{ QUrl(m_proctor->baseUrl() + "/proctor/notifications?limit=50") };
    req.setRawHeader("Authorization", "Bearer " + m_proctor->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(15000);

    QNetworkReply* reply = m_proctor->network()->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_inflight = false;

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            return;  // transient: next tick retries; sign-out stops the timer anyway
        }
        handleFeed(reply->readAll());
    });
}

void StaffNotifier::handleFeed(const QByteArray& payload)
{
    const QJsonArray rows = QJsonDocument::fromJson(payload).object().value("notifications").toArray();
    if (rows.isEmpty()) {
        return;
    }

    // rows come newest-first
    qint64 maxId = m_lastSeen;
    for (const auto& v : rows) {
        maxId = std::max(maxId, static_cast<qint64>(v.toObject().value("id").toDouble()));
    }

    if (m_lastSeen < 0) {
        // first contact for this account: everything already in the inbox is old news
        m_lastSeen = maxId;
        m_cursorOwner = m_proctor->displayName();
        saveCursor();
        return;
    }
    if (maxId <= m_lastSeen) {
        return;
    }

    QVector<QJsonObject> fresh;
    for (const auto& v : rows) {
        const QJsonObject o = v.toObject();
        if (static_cast<qint64>(o.value("id").toDouble()) > m_lastSeen) {
            fresh.prepend(o);  // flip back to oldest-first so banners read chronologically
        }
    }

    if (fresh.size() > BANNER_CAP) {
        notify(tr("JartonMC staff"), tr("%1 new staff alerts").arg(fresh.size()));
    } else {
        for (const auto& o : fresh) {
            notify(o.value("title").toString(), o.value("body").toString());
        }
    }

    m_lastSeen = maxId;
    m_cursorOwner = m_proctor->displayName();
    saveCursor();
}

void StaffNotifier::notify(const QString& title, const QString& body) const
{
#ifdef Q_OS_MACOS
    Mac::postNotification(title, body);
#else
    Q_UNUSED(title)
    Q_UNUSED(body)
    // Windows delivery (QSystemTrayIcon::showMessage) lands with the Windows staff build
#endif
}

void StaffNotifier::loadCursor()
{
    QFile f(m_cursorPath);
    if (!f.open(QIODevice::ReadOnly)) {
        return;
    }
    // "<displayName>\n<id>"
    const QList<QByteArray> parts = f.readAll().split('\n');
    if (parts.size() >= 2) {
        m_cursorOwner = QString::fromUtf8(parts[0]).trimmed();
        bool ok = false;
        const qint64 id = parts[1].trimmed().toLongLong(&ok);
        m_lastSeen = ok ? id : -1;
    }
}

void StaffNotifier::saveCursor() const
{
    QDir().mkpath(QFileInfo(m_cursorPath).absolutePath());
    QFile f(m_cursorPath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(m_cursorOwner.toUtf8() + '\n' + QByteArray::number(m_lastSeen));
    }
}

}  // namespace Jarton
