// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QTimer;

namespace Jarton {

class ProctorClient;

// Polls the proctor notification inbox (GET /proctor/notifications) while a
// staff session is signed in and surfaces new rows as native desktop banners.
// The broker fans rows out per staffer already filtered through their
// notify_* toggles, so everything that shows up here is meant for this
// account — no client-side filtering.
//
// The last-seen row id is persisted next to the other staff session files so
// a relaunch doesn't replay the whole inbox; the cursor is tagged with the
// account name and re-baselines silently when a different staffer signs in.
class StaffNotifier : public QObject {
    Q_OBJECT

   public:
    StaffNotifier(ProctorClient* proctor, QString cursorPath, QObject* parent = nullptr);

   private:
    void poll();
    void handleFeed(const QByteArray& payload);
    void loadCursor();
    void saveCursor() const;
    void notify(const QString& title, const QString& body) const;

    ProctorClient* m_proctor = nullptr;
    QTimer* m_timer = nullptr;
    QString m_cursorPath;
    QString m_cursorOwner;   // displayName the stored cursor belongs to
    qint64 m_lastSeen = -1;  // -1 = baseline pending: swallow the backlog once
    bool m_inflight = false;
};

}  // namespace Jarton
